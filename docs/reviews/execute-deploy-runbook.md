---
task: deploy-runbook
status: passed
p0: 0
p1: 0
---

# Review: deploy-runbook

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | no Dart touched |
| `caddy validate --config deploy/Caddyfile --adapter caddyfile` (throwaway env hash) | 0 | "Valid configuration", re-run by the orchestrator after the fix round |
| `systemd-analyze verify` on a scratchpad copy of `deploy/food-orders-backend.service` with a dummy executable at the `ExecStart` path | 0 | implementer, before and after the fix round |
| Local functional test of the fixed Caddyfile (temp copy, `auto_https off`, high ports, python upstream) | — | implementer: no creds 401; creds 200; creds + `Sec-Fetch-Site: cross-site` POST 403 and never reached the upstream; same-origin and same-site 200; upstream saw no `Authorization`, `X-Staff-Id` still passed. Not re-run by the orchestrator |
| `make check` | 2 | stops at `analyze`: the 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); no Dart changed |

## Changed paths

New `docs/deploy.md` (~550 lines); `deploy/food-orders-backend.service` (build with `dart build cli`, `ExecStart=/opt/food-orders/bundle/bin/server`, `WorkingDirectory=/opt/food-orders/bundle`, comments); `deploy/Caddyfile` (security fix, see below); `docs/runbook-local.md` (section 8, line 6, links both ways); `CLAUDE.md` (exactly one added line pointing to `docs/deploy.md`). Owner approved each of these for this task (the Caddyfile fix after the security P1). Nothing run on a server; no sudo.

## Round 1 — code review: P0 0, P1 0, P2 9; security review: P0 0, **P1 1**, P2 9

**P1 (security): the demo gate could be bypassed by any web page.** A logged-in viewer's browser caches the Basic credentials; a hostile page could send a no-cors simple POST (`text/plain`) to `/api/orders`, `/api/orders/{id}/switch-to-cash` and so on with them attached, and the backend has no `Content-Type` check — fake orders, unpaid transfer orders to cash, filling the 10,000-order cap. The runbook also understated it.

## Fix round 1

- `deploy/Caddyfile`, both site blocks: inside `handle_path /api/*` before the proxy, `@xsite header Sec-Fetch-Site cross-site` → `respond @xsite 403`; `header_up -Authorization` (the backend never needs the gate credentials; `X-Staff-*` still pass); `X-Frame-Options DENY` and `Content-Security-Policy "frame-ancestors 'none'"` on the site.
- `docs/deploy.md`: cross-site risk and fix stated (sections 5.7, 11); HSTS wording corrected; brute-force cost and `fail2ban`/rate limit made a recommended step (5.9); `chmod -R go+rX /opt/food-orders`; web rsync `--chmod=D755,F644` with an `index.html` guard; new bundle verified before stopping the service; non-recursive `chmod 700`; explicit VM-lost commands; restore as the service user (`tar --no-same-owner`); `cd /` before `sudo -u`/`runuser`; `backup.sh` install moved into 5.8; SSH `sshd -T` check and `ufw limit 22/tcp`; install-source warnings; `ss -ltnp | grep 3000` check; uptime-pinger note.
- `docs/runbook-local.md` line 6 and `deploy/food-orders-backend.service` comments corrected.

## Re-review 1

Code review: P0 0, P1 0, P2 3. Security review: P0 0, **P1 0** (the cross-site P1 is closed for every current browser: Chrome, Firefox, Safari 16.4+), P2 4. Fixed after the re-review (doc text only): rollback pointer (9.3 → 9.5); `&&`-chained the `rsync --delete` blocks in 5.4 and 7.1 so a failed `ls`/`test` stops them; "three `rm -f` lines" wording; the old-browser limit now stated plainly (an iPhone stuck below Safari 16.4 is NOT protected; do not share the URL with such devices); `fail2ban` filter caveats (count only 401s that carried an `Authorization` header, high `maxretry`, whitelist your addresses, Caddy needs a `log` directive).

## Deferred P2 follow-ups

1. Section 8 has no check for the cross-site guard: add `curl -sI -u demo -H 'Sec-Fetch-Site: cross-site' https://<host>/api/menu` (expect 403) and the same without the header (expect 200).
2. `sudo -u food-orders sqlite3` at `docs/deploy.md` ~310/321 lacks `cd /` (probably fine with an absolute path).
3. Residual security gap: clients that send no `Sec-Fetch-Site` and same-site attackers (a takeover of any subdomain under the same registrable domain) are not blocked. Options: refuse any `Sec-Fetch-Site` that is not `same-origin` (check how Caddy 2.6.2 combines `header` lines in one matcher), and/or require `Content-Type: application/json` on POST/PATCH (the body-less customer routes `switch-to-cash` and `renew-payment` would need an exemption or the client sending the header) — better, add the `Content-Type` check in the backend.
4. `rsync -a` of `backend/` without `--delete` leaves deleted source files on the VM until cleaned (minor).
5. Optional extra systemd hardening (`RestrictAddressFamilies`, `SystemCallFilter`, `ProtectProc`, `MemoryDenyWriteExecute`: Dart AOT may need an exception); no HSTS yet in the Caddyfile; `@nocache` misses `/` and deep links; manifest fetch may 401 behind the gate.
6. `CLAUDE.md` still says "a compiled binary must set it" for `IMAGES_DIR`: now a built bundle; wording only.

## Unverified (owner acceptance)

Every command in `docs/deploy.md` on a real VM; the bundle running under the unit's hardening (and the `.so` lookup next to the binary); `dart build cli -o` with an existing output folder; Oracle `iptables`/`ufw`; Dart on ARM; `caddy validate`/`basicauth` on whatever Caddy `apt` installs; real-browser behaviour behind the gate (login prompt, SSE and `fetch` credential reuse, service worker, `Sec-Fetch-Site` values, the cross-site POST test from a hostile page in Chrome/Firefox/Safari); `fail2ban`; cron backup; reboot survival; port 3000 closed from outside. Provider facts are second-hand (dated 2026-11-09); HOST1 and HOST2 are still open.

## Verdict

**Passed**, P0: 0, P1: 0 (the one P1 found in round 1 was fixed and re-reviewed).
