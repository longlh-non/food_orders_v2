---
task: deploy-runbook
status: passed
p0: 0
p1: 0
---

# Security review: deploy-runbook

## Scope

`docs/deploy.md`, `deploy/food-orders-backend.service`, `deploy/Caddyfile`, `deploy/backup.sh` (the doc tells the owner how to expose the app to the internet). Read-only reviews; the reviewers ran nothing.

## Round 1: P0 0, P1 1, P2 9

**P1-1: the shared gate can be bypassed by any web page, and the doc understated it.** A logged-in viewer's browser attaches the cached Basic credentials to a hostile page's no-cors simple POST (`Content-Type: text/plain`, no preflight) to `/api/orders` or `/api/orders/{id}/switch-to-cash`; the backend has no content-type check. Impact: fake orders with a body-controlled price, unpaid transfer orders switched to cash, 10,000-order cap filled (permanent 503). Fix recommended: reject `Sec-Fetch-Site: cross-site` on `/api/*` in the Caddyfile and state the risk in section 11.

P2: HSTS wording; brute-force/CPU cost understated (bcrypt cost 14) and `fail2ban` optional; the gate `Authorization` header forwarded to the backend; root `tar -xzf` on an archive the service user can write; SSH hardening asserted not verified; install sources not authenticated in the doc; unit comment `backend.env` mode window; no framing headers (`X-Frame-Options`/`frame-ancestors`) and optional unit hardening; copy-paste hazards (`rsync --delete` of an empty build, `bundle.prev` overwrite, umask and file readability, uptime pinger and the 401).

## Fix round and Re-review 1: P0 0, P1 0, P2 4

The P1 is closed for every current browser (the 403 precedes the proxy; unauthenticated probes still get 401 because `basicauth` runs first; preflights fail; the apps' own `fetch`/`EventSource`/`<img>`/service-worker traffic is `same-origin`). No change weakened HTTPS, the 64 KB body cap or nosniff. Remaining P2s: (1) the `fail2ban` advice would ban legitimate users unless the filter counts only 401s that carried an `Authorization` header — doc text fixed afterwards; (2) a pasted `rsync --delete` block continued after a failed `ls` — doc fixed by `&&` chaining; (3) residual gap for clients sending no `Sec-Fetch-Site` (Safari below 16.4) and same-site attackers — now stated plainly in the doc; follow-up options recorded in `execute-deploy-runbook.md`; (4) wording of the `rm -f` sentence — fixed.

## Checked and clean

ufw order (`limit 22`, allow 80/443, `show added`, then `enable`), port 3000 never opened, loopback-only backend; `/opt/food-orders` root-owned so the service user cannot replace its binary; `ProtectSystem=strict`, `ReadWritePaths` limited to `/var/lib/food-orders`; secrets files created with `install -m 600` before editing and never on a command line; `caddy hash-password` and `curl -u` prompt; no `auto_https off`; `backup.sh` `umask 077`, temp-then-rename; restore as the service user with `--no-same-owner`; honest weak-points list (no rate limit, no HSTS yet, stale `index.html`, unauthenticated customer routes, unencrypted same-disk backups).

## Needs a real environment

Real browsers sending `Sec-Fetch-Site` as expected through the Flutter service worker and SSE reconnect; a cross-site POST test from a hosted hostile page in Chrome, Firefox and Safari; a `fail2ban` filter that separates 401s with and without `Authorization`; the unit's hardening against the built bundle; Oracle `iptables` with `ufw`.

## Verdict

**Passed**, P0: 0, P1: 0 (round-1 P1 fixed and re-reviewed).
