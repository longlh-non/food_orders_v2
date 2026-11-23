---
task: deploy-production-config
status: passed
p0: 0
p1: 0
---

# Review: deploy-production-config

## Gates (round 1)

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | (no Dart touched) |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 586 tests |
| `make test` | 0 | 540 tests |
| `make analyze` / `make check` | 2 | pre-existing, repo-wide, unrelated `material_ui` SDK issue tracked against every card in this batch; none of `deploy/`'s files are Dart |

Extra verification beyond what the card expected (tools turned out to be available locally, used for real confidence, not a substitute for the owner's real deploy):
- `caddy validate --config deploy/Caddyfile --adapter caddyfile` → "Valid configuration," automatic HTTPS confirmed on.
- `caddy adapt --pretty` inspected: `/api/*` subroute precedes the `file_server` fallback; `encode gzip`'s matcher excludes `/api/*`; **confirmed by the orchestrator** (route-chain walk of the compiled JSON — none of the nested routes in the site block are `terminal`, so the unconditional `headers` route composes around and does reach the `/api/*` reverse-proxy subroute's response, resolving a round-1 reviewer question — see below).
- `systemd-analyze verify deploy/food-orders-backend.service` → clean (0 warnings with a dummy executable at the `ExecStart` path; the one real error is the expected missing binary on this dev machine).
- `deploy/build.sh` run for real: both `flutter build web --release --output build/customer` and `--output build/restaurant` succeeded.
- `deploy/backup.sh` run for real against a throwaway db+images folder (never `backend/data/orders.db`): valid backup + archive, correct `KEEP=3` retention pruning across 5 runs.

## Changed paths

New: `deploy/Caddyfile`, `deploy/food-orders-backend.service`, `deploy/build.sh`, `deploy/backup.sh`.

## Review round 1 (code-reviewer + security-reviewer, parallel) — findings

Both reviewers independently confirmed: the backend already defaults to loopback-only binding (`backend/bin/server.dart`) and the systemd unit correctly omits `BIND_ADDRESS`; no `auto_https off`; the `request_body { max_size 64KB }` limit is carried over into both `/api/*` blocks; systemd hardening (`NoNewPrivileges`, `ProtectSystem=strict`, `ReadWritePaths` scoped to the data dir only, `ReadOnlyPaths` on the images folder, `PrivateTmp`, `UMask=0077`) is present and correctly scoped, including the RW-parent/RO-child subdirectory ordering; the self-identified `ReadOnlyPaths` vs. `Directory.createSync()` operational trap is correctly resolved (documented pre-create step; `createSync` on an existing directory is a no-op); no secrets, no real hostnames/paths (`*.example.com`, generic `/var/lib/food-orders/...` etc.); `lib/shared/api/order_api_client.dart` correctly untouched; non-goals respected (no sudo/systemctl/apt actually run, no `.github/**`/`dev/**`/auth/CORS/Docker/CDN changes).

**Code review: P0: 0, P1: 1, P2: 4.**
**Security review: P0: 0, P1: 0, P2: 2.**

### P1 (code-reviewer): `deploy/backup.sh` retention pruning didn't guard the "matching pair" invariant across partial failures

`prune()` counted the `orders-*.db` and `images-*.tar.gz` globs independently. If `sqlite3 .backup` succeeded but the following `tar` failed for any reason other than "images dir missing" (disk full, permission error), `set -e` aborted before pruning — leaving an orphan db backup with no images counterpart, which the *next* run's `prune()` would count and retain as if it were a complete round. This contradicted the script's own stated "matching pair" guarantee.

### P2s (both reviewers, overlapping)

1. Backup files inherited the caller's default umask (typically `022`), re-opening the P2-1 "customer names shouldn't be world-readable" concern on every backup copy, despite the live `orders.db` being hardened via the systemd unit's `UMask=0077`.
2. The install comment's `chmod 700 /var/lib/food-orders` wasn't recursive, so the `images` subdirectory (created by `mkdir -p` with the installer's ambient umask) could stay more permissive than the parent.
3. Fragile quoting: `sqlite3 "$orders_db" ".backup '$db_backup'"` relies on sqlite3's own dot-command quoting for a path built from operator-supplied `BACKUP_DIR`; a stray `'` in that env var would misparse the command.
4. (Security reviewer, optional) further systemd sandboxing beyond what the card required (`RestrictAddressFamilies`, `RestrictNamespaces`, etc.) — not a gap against the card's own checklist, offered as a suggestion for the owner's later `systemd-analyze security` pass.
5. (Security reviewer) unconfirmed whether the security headers reach the proxied `/api/*` responses — resolved during the fix round, see below (not a defect; impact was low regardless since the backend already sets its own `nosniff` header).

## Fix (round 1 → round 2)

1. **P1 fix** (`deploy/backup.sh`): each round now writes to `.tmp` names first and only `mv`s both into their final, glob-matched names once *both* the db backup and the images archive succeed. A `trap ... EXIT` cleans up any leftover `.tmp` file on an early exit. Verified by hand: a simulated `tar` failure (stubbed binary, `exit 1`) after a successful `sqlite3 .backup` left **zero** orphaned files in the backup directory — only the prior, fully-successful round remained. Five subsequent successful rounds with `KEEP=3` still correctly pruned to exactly 3 matching `.db`/`.tar.gz` pairs.
2. **P2 fix** (umask): added `umask 077` near the top of `backup.sh`. Verified: both output files are now created `600`.
3. **P2 fix** (recursive chmod): `deploy/food-orders-backend.service`'s install comment now reads `sudo chmod -R 700 /var/lib/food-orders`.
4. **P2 fix** (quoting): added an upfront validation that `BACKUP_DIR`/`ORDERS_DB` don't contain a `'`, failing fast with a clear error instead of relying on sqlite3's quoting to never see one. (Operator-supplied paths, not attacker input, so a validation error is sufficient — no escaping engineering needed.)
5. **Header-scoping question resolved, no fix needed**: walked the compiled `caddy adapt --pretty` route list for one site block — none of the nested routes (`headers`, `rewrite`, `encode`, the `/api/*` subroute, `file_server`) are marked `terminal`, so Caddy's middleware composition means the unconditional `headers` route (index 2, `match: None`) wraps around and does apply to the `/api/*` reverse-proxy's response too. Confirmed, not a gap.
6. Optional extra systemd hardening (P2 #4) deferred as a follow-up for the owner's own post-install `systemd-analyze security` pass — not required by the card's own checklist.

## Gates (round 2, after fix)

| Command | Exit code | Notes |
|---|---|---|
| `systemd-analyze verify` (dummy executable swapped in) | 0 | re-run after the install-comment edit, still clean |
| `caddy validate --config deploy/Caddyfile --adapter caddyfile` | 0 | unaffected (Caddyfile itself wasn't touched in the fix round), re-confirmed |
| `backup.sh` manual test: success round, simulated partial failure, 5-round retention | — | all behave correctly (see above); no `make` gate applies to shell scripts |

No Dart files were touched by either the implementation or the fix, so `make format-check`/`boundaries`/`backend-analyze`/`backend-test`/`test` results from round 1 still hold unchanged.

## Final `make check` (before archiving)

Run once on the final candidate: `make check` → **exit 2**, halting at `analyze` with the same 19 pre-existing, repo-wide `material_ui` findings (`format-check` and `boundaries`, the steps before it, both passed). This is the same unrelated environment issue tracked against every card in this batch; nothing in this card's own files is Dart.

## Re-review

Both fixes are small, mechanically verified changes (atomic rename + trap; one `umask` line; one validation check; one comment edit), each tested for real against the exact failure mode the reviewer described. No second reviewer pass was spun up; re-reviewed directly by the orchestrator against the original findings. No new findings.

## Acceptance criteria

| Criterion | Status |
|---|---|
| Existing gates still pass (`make check`) | format-check/boundaries/backend-analyze/backend-test/test all green; `make check`/`make analyze` blocked by the pre-existing, unrelated SDK issue |
| `deploy/build.sh` produces `build/customer` and `build/restaurant` | Met — run for real this session |
| Caddyfile valid, SSE not buffered, same-origin `/api` strip identical to dev | Met — `caddy validate` + both reviews + orchestrator's route-chain walk |
| HTTPS automatic, no `auto_https off`, no secrets in files | Met |
| systemd unit non-root, minimal write access, `IMAGES_DIR` set | Met |
| Backend not reachable on :3000 from outside | Design confirmed (loopback default, unit doesn't override); **unverified** on a real server |
| Hostnames/paths are placeholders, no credentials committed | Met |
| A photo copied to the VM images folder shows in the customer app over HTTPS; backup contains the database and the images | **Unverified** — owner acceptance on the real server |

## Verdict

**Passed**, P0: 0, P1: 0 across both required reviews (one P1 found and fixed in round 1, four P2s found and fixed or resolved alongside it). Real-server acceptance (DNS, TLS, firewall, systemd hardening under the actual compiled binary) remains unverified by design — no sandbox access to a server.
