---
task: deploy-production-config
status: passed
p0: 0
p1: 0
---

# Security review: deploy-production-config

## Scope

Four new files: `deploy/Caddyfile`, `deploy/food-orders-backend.service`, `deploy/build.sh`, `deploy/backup.sh`. This is a textbook network-exposure trigger (first production deploy config for a previously local-only app) per CLAUDE.md's Safety policy.

## Findings (round 1)

**P0: 0, P1: 0, P2: 2** — both advisory/defense-in-depth, neither required by the card's own checklist:
1. `deploy/backup.sh`'s `.backup '$db_backup'` quoting relies on sqlite3's own dot-command parsing rather than the shell's, for an operator-supplied (not attacker-reachable) path.
2. Optional further systemd sandboxing beyond what the card required (`RestrictAddressFamilies`, `RestrictNamespaces`, `ProtectHostname`, etc.) — a suggestion for the owner's own later `systemd-analyze security` pass, not a gap.

## Checks performed (all confirmed clean)

1. **No secrets committed** — `STAFF_ID`/`STAFF_PASSWORD` referenced only via `EnvironmentFile=/etc/food-orders/backend.env` (a path, never created with content by this diff); install comment uses literal placeholder text, no plausible-looking real value.
2. **Backend network exposure (the key check)** — `backend/bin/server.dart` confirmed to default to `InternetAddress.loopbackIPv4`, overridden only by a non-empty `BIND_ADDRESS`; the systemd unit deliberately omits `BIND_ADDRESS`, with an explicit comment warning future editors not to add `BIND_ADDRESS=0.0.0.0`. Backend stays loopback-only in production.
3. **Automatic HTTPS stays on** — no `auto_https off` anywhere; confirmed via `caddy validate` (automatic HTTP→HTTPS redirect logged).
4. **Request body limit carried over** — `request_body { max_size 64KB }` present in both `/api/*` blocks, matching `dev/Caddyfile`.
5. **systemd hardening** — dedicated non-root user, `NoNewPrivileges`, `ProtectSystem=strict`, `ReadWritePaths` scoped to only the data directory, `PrivateTmp`, `UMask=0077` (satisfies the carried-in P2-1 note), `ReadOnlyPaths` on the images folder correctly ordered as a more-specific child override of the writable parent. No directive missing, none too permissive.
6. **No real infrastructure details** — hostnames are the reserved `example.com` domain; paths are generic (`/var/lib/food-orders`, `/etc/food-orders`, `/opt/food-orders`).
7. **Shell script safety** — no command injection, no unsafe `rm -rf`, no `eval`, no remote code execution; numeric input validated before use in arithmetic; `rm -f --` guards against filenames starting with `-`.
8. **No weakening of an accepted-risk boundary** — auth/demo-gate correctly deferred to the separate `deploy-demo-access-gate` card; no half-implemented auth; no comment overclaims a security property not actually provided.

## Fix round (applied after the parallel code-reviewer pass surfaced a related P1)

Although this security review itself found no P0/P1, the parallel code-reviewer pass found a real P1 in `backup.sh` (retention pruning could retain a mismatched db/images pair after a partial failure — see `docs/reviews/execute-deploy-production-config.md`). The fix (atomic rename via `.tmp` + trap cleanup) also closes this security review's own P2 #1 concern as a side effect: the upfront quote-rejection check added during the fix means a `BACKUP_DIR`/`ORDERS_DB` containing `'` now fails fast with a clear error instead of relying on sqlite3's quoting. Also fixed: `umask 077` added to `backup.sh` (backup files now inherit the same `600` restriction the live `orders.db` gets via the systemd unit's `UMask=0077`, closing the "backups re-open the P2-1 customer-names-readable gap" concern raised independently by the code-reviewer).

## Verdict

**Passed**, P0: 0, P1: 0. This is a well-constructed, conservative production deploy config that correctly carries forward every protection CLAUDE.md documents (loopback-only backend, 64KB body cap, same-origin `/api` proxy, automatic HTTPS) and adds appropriate systemd sandboxing, with no secrets committed and no real infrastructure details leaked. The two P2 advisories raised here were addressed as a byproduct of the code-reviewer's P1 fix round.
