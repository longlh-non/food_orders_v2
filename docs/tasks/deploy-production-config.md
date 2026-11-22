---
executor: task-executor
scopes: [dev-infra, backend]
workKinds: [infra, quality-gate]
blockedBy: [backend-orders-sqlite-storage, backend-request-body-limit, backend-menu-image-file-serving]
securityReview: required
---

# Production deploy config in the repo (Caddy, systemd, build script)

## Why

Owner asked to find free hosting. Chosen shape (pending HOST1-HOST2 answers, see `deploy-runbook`): one always-free VM running the same Caddy layout as local dev. Caddy serves both static Flutter builds and proxies `/api/*` to the backend, so the apps stay same-origin: no CORS, no change to `OrderApiClient` (`_baseUrl = '/api'`). This card writes the config files only. It creates no server and runs nothing.

It is blocked by the SQLite card (data must live in a file on the VM disk, `ORDERS_DB`), by the body-limit card (on the public internet, unbounded request bodies are a real memory-exhaustion risk, not just a wifi risk), and (added 2026-11-10) by `backend-menu-image-file-serving`, so the unit and backup script know about the images folder.

## Sources

`dev/Caddyfile`, `dev/nginx.conf` (SSE: buffering off, long read timeout), `backend/bin/server.dart` (binds `0.0.0.0:3000`), `lib/shared/api/order_api_client.dart`, `CLAUDE.md` "Reverse proxy", "Backend", "Safety policy".

## Goal

A new top-level `deploy/` folder (not `dev/`, which stays local-only):

1. `deploy/Caddyfile` - two site blocks using real hostnames from placeholders (`customer.example.com`, `restaurant.example.com`; the owner replaces after HOST2). Each block: `handle_path /api/*` -> `reverse_proxy localhost:3000` (with `flush_interval -1` so SSE is never buffered); everything else `root` + `file_server` + `try_files {path} /index.html`, `encode gzip`. Automatic HTTPS stays ON (do not copy `auto_https off`). Cache: `index.html` and `flutter_service_worker.js` no-cache, other assets cacheable. Basic security headers (`X-Content-Type-Options`, `Referrer-Policy`). Menu pictures need **no** separate Caddy block: they are served by the backend at `/api/images/<file>`, so the existing `/api/*` proxy covers them. Do not add the `Cache-Control` rule for static assets to the `/api/*` block (the backend sets its own picture cache header).
2. `deploy/food-orders-backend.service` - systemd unit: dedicated non-root user, `WorkingDirectory`, `Environment=ORDERS_DB=/var/lib/food-orders/orders.db`, **`Environment=IMAGES_DIR=/var/lib/food-orders/images`** (a compiled binary must set it, like `ORDERS_DB`), `STAFF_ID` and `STAFF_PASSWORD` from an `EnvironmentFile` that lives only on the server (mode 600, never in the repo or the unit file itself; without them the export and menu edits answer 403), `Restart=on-failure`, hardening options (`NoNewPrivileges`, `ProtectSystem=strict`, `ReadWritePaths` for the data dir, `PrivateTmp`). The backend only reads pictures, so the images folder may be `ReadOnlyPaths`; the owner copies photos with `rsync` as a different user. Runs a compiled binary (`dart compile exe`, built on the VM so the CPU architecture matches - Oracle Ampere is ARM) rather than `dart run`.
3. `deploy/build.sh` - builds both web apps with `flutter build web --release -t lib/customer/main.dart --output build/customer` and the same for restaurant. The executor verifies the `--output` flag against the installed Flutter and records it. Exits non-zero on failure. No network upload in the script; copying to the server is a documented manual `rsync` step the owner runs (the runbook adds the same `rsync` for the owner's photos folder to `/var/lib/food-orders/images/`).
4. `deploy/backup.sh` - uses `sqlite3 <db> ".backup <file>"` (safe while the server runs), keeps the last N copies, and **also copies the images folder** (plain files, e.g. `rsync -a` or `tar`) so the database and its pictures stay a matching pair. Optional; only wired up if HOST5 says yes.
5. Backend binding: the backend currently listens on `0.0.0.0:3000`. Only Caddy should reach it. Preferred fix is a small backend change (bind to loopback, overridable by an env var such as `BIND_ADDRESS`, default unchanged so local dev and the Caddy setup keep working), with a test if practical. If the owner prefers not to touch the backend, the runbook must instead require the VM firewall to block 3000 and verify it from outside. Executor asks which before starting.

## Non-goals

Creating cloud accounts, DNS, running `sudo`/`systemctl`/`apt`, CI deploy automation (`.github/**`), auth (see `deploy-demo-access-gate`), CORS, a client change, Docker, CDN split (Cloudflare Pages), changes to `dev/**`.

## Approvals needed before start

Owner approves creating `deploy/` (new files outside the usual code folders, network-exposure config) and any edit to `Makefile`/`tool/**` if a gate for deploy files is wanted (not required by this card).

## Tests written with the change

- Backend test for the bind-address helper if item 5 is done in code.
- `caddy validate` is not available to agents (no Caddy run without owner); the owner runs `caddy validate --config deploy/Caddyfile` as acceptance.
- `shellcheck`-style review of the two scripts by `code-reviewer` (no new tool installed).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Existing gates still pass (`make check`) | `make check` exit 0 (gate) |
| `deploy/build.sh` produces `build/customer` and `build/restaurant` | owner runs it; "unverified" until then (Flutter build is slow, not a gate) |
| Caddyfile valid, SSE not buffered, same-origin `/api` strip identical to dev | `caddy validate` by owner + `security-reviewer` + `code-reviewer` (review) |
| HTTPS automatic, no `auto_https off`, no secrets in files | `security-reviewer` (review) |
| systemd unit non-root, minimal write access, `IMAGES_DIR` set | `security-reviewer` (review) |
| Backend not reachable on :3000 from outside | owner acceptance on the real server (from phone/other network: connection refused) |
| Hostnames/paths are placeholders, no credentials committed | `code-reviewer` (review) |
| A photo copied to the VM images folder shows in the customer app over HTTPS; backup contains the database and the images | owner acceptance on the real server, "unverified" until done |

## Environment limits

Agents cannot start a server, resolve DNS, or test Let's Encrypt. Everything marked owner acceptance stays "unverified" until the runbook is followed.

## Added by later reviews (2026-11-09)

From `docs/reviews/security-backend-orders-sqlite-storage.md`:
- **P2-1, data at rest:** the database (customer names) was created with mode `0644` in a `0755` directory, so any local user can read it. In the systemd unit, set `UMask=0077`, or create the data directory as `0700` and the file as `0600`.
- **P2-3, build hook:** the `sqlite3` package downloads a precompiled SQLite from `github.com/simolus3/sqlite3.dart/releases` (tag `sqlite3-3.9.1`) on first build, and verifies it with a SHA-256 hash shipped in the package. The VM build needs outbound access to github.com, or the build fails. On any `sqlite3` version bump, review the hook changes.
- From the code review: a compiled binary **must** set `ORDERS_DB`. The default path only holds for `dart run`.

## Decided by the owner (2026-11-13)

HOST3 = A and HOST5 = yes, recorded in `docs/ci-cd-decisions.md`. HOST1 and HOST2 are still open.

## Added by `backend-request-body-limit` (2026-11-17)

The production Caddyfile must carry the same body limit as `dev/Caddyfile`. Inside each `handle_path /api/*` block, add:

```
request_body {
	max_size 64KB
}
```

The backend must also listen on loopback only (HOST6), because the limit only protects traffic through the proxy.
