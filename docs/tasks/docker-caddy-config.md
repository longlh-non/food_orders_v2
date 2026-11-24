---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: []
securityReview: required
---

# Docker step 2: a Caddyfile for the container that serves both web builds and proxies the backend

## Why

In Docker, Caddy runs in its own container. It cannot reach the backend at `localhost:3000` (that is itself) and it has no `/var/www` folder, so `deploy/Caddyfile` cannot be reused unchanged. The behaviour must stay the same: shared password on everything, `/api/*` proxy with the 64 KB limit, SSE not buffered, cross-site guard, security headers, automatic HTTPS.

## Sources

`deploy/Caddyfile` (the reviewed production config and its comments), `dev/Caddyfile`, `docs/deploy.md` 5.6, 5.7 and 11 (gate, cross-site guard, known risks), `CLAUDE.md` "Size limits".

## Open decisions (owner), with recommendation

- DOCKER4 How the two web builds get into Caddy. Recommend: **the stock `caddy` image plus read-only mounts** of the two build folders (`build/customer`, `build/restaurant` copied to the server with the same `rsync` as `docs/deploy.md` 7.1). No web Dockerfile, no Flutter inside Docker (there is no official Flutter image, a third-party one is a new dependency, and CI pins a different Flutter version than the local one). A web release stays "build on a machine with Flutter, copy the files", and Caddy needs no restart for it. Alternative: bake the builds into a custom Caddy image (immutable and rollback by tag, but a registry or an image transfer becomes necessary; revisit when the cd-* cards are redone for Docker).
- DOCKER5 Caddy image: recommend the official `caddy` image pinned to an exact version. Note `deploy/Caddyfile` was checked on 2.6.2 with the directive `basicauth`; newer Caddy prefers `basic_auth` (old name still a deprecated alias). Executor uses the name that matches the pinned version and says which.
- HOST2 (domain) is still open, so no hostname is committed (below).

## Goal

New `deploy/docker/Caddyfile`. Do **not** edit `deploy/Caddyfile` (the systemd path stays as is; the two files will drift, so the new file's header says "keep in sync by hand with deploy/Caddyfile" and lists what differs).

Differences from `deploy/Caddyfile`, nothing else:

- Site addresses come from environment values, `{$CUSTOMER_HOST:localhost}` and `{$RESTAURANT_HOST:localhost-restaurant}` style (the executor picks defaults that cannot reach the public internet by accident). No real hostname in the repo.
- Upstream is `backend:3000` (compose service name), not `localhost:3000`.
- `root` paths are `/srv/customer` and `/srv/restaurant` (the mount points).
- Keep: gate via `FOOD_ORDERS_AUTH_USER` / `FOOD_ORDERS_AUTH_HASH`, `Sec-Fetch-Site: cross-site` 403, `header_up -Authorization`, `request_body { max_size 64KB }`, `flush_interval -1`, `handle` + `try_files` structure (the old `/api/*` rewrite bug), gzip only for non-`/api/*`, `no-cache` for `index.html` and the service worker, the four security headers. Automatic HTTPS stays on; never `auto_https off`.
- "HTTPS-ready" here means: certificates are requested automatically once DNS points at the VM and ports 80/443 reach Caddy. Certificate storage must persist (a `/data` volume), which is compose's job in the next card; say so in a comment, because losing it causes repeated certificate requests and rate limits.

Also a small `deploy/docker/caddy.env.example` listing **names only** with obviously fake values (`CUSTOMER_HOST=customer.example.com`, `FOOD_ORDERS_AUTH_USER=demo`, `FOOD_ORDERS_AUTH_HASH='$2a$14$REPLACE_ME'`). The real file lives on the server only (suggested `/etc/food-orders/caddy.env`, mode 600). The example's name must not start with `.env`.

## Non-goals

Compose, the backend image, backups, fail2ban or a rate limit (still the P2 follow-up in `docs/deploy.md` 5.9), HSTS (still deferred), changing `deploy/Caddyfile` or `dev/Caddyfile`.

## Tests written with the change

No automated test. If `caddy` is installed on the executor's machine, run `caddy adapt --config deploy/docker/Caddyfile --adapter caddyfile` and `caddy validate` with fake environment values and record the output (this may ask permission; it needs no network or sudo). If it is not installed, say "not run".

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Same gate, cross-site guard, body limit, `flush_interval -1`, headers as `deploy/Caddyfile` (diff read side by side) | `code-reviewer` (review) |
| No real hostname, password, hash or key in the repo; example file has fake values only | `security-reviewer` (review) |
| `/api/*` still behind the gate and answered by `handle_path` before any `try_files` | `code-reviewer` (review) |
| `caddy adapt`/`validate` output recorded, or "not run" stated | executor report |
| `make check` exit 0 | gate |
| Real certificates, gate login, live stream through Docker | **owner acceptance, "unverified" until done** |

## Environment limits

Agents cannot start containers, obtain certificates or open a browser. Gate behaviour in a browser stays unverified exactly as in `docs/deploy.md` 11.

Approvals: **explicit owner approval is needed for edits under `deploy/**`** (new files in `deploy/docker/`), for this task only. No `.github/**`, `Makefile` or `CLAUDE.md` edit.
