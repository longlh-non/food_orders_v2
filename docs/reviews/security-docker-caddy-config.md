---
task: docker-caddy-config
status: passed
p0: 0
p1: 0
---

# Security review: docker-caddy-config

Reviewer: security-reviewer. No P0, no P1, three P2 (defence in depth). Read-only.

## Findings

1. P2 empty host variables. I tested it: with both set to empty strings Caddy 2.6.2 refuses to load (exit 1), so it fails closed; unset falls back to the local defaults. **Deferred** to `docker-compose-stack`: use `${CUSTOMER_HOST:?}` style required variables, and test empty, unset and valid values.
2. P2 the guard refuses only `Sec-Fetch-Site: cross-site`, so a page on a sibling subdomain (`same-site`) passes. Same as `deploy/Caddyfile`, not a regression. **Deferred**: document the "no other untrusted site under the same parent domain" assumption in `docker-deploy-runbook`, or tighten later in both files together.
3. P2 quotes and `$` in the env file. Fails closed (401 or load error), cannot open the gate. **Deferred** to `docker-compose-stack`: pass the file with `env_file:` (not `${...}` interpolation) and test it.

## Checked and clean

Gate covers `/api/*`, the SSE stream and static files on both sites; unset credentials fail closed; cross-site guard, 64 KB limit, `header_up -Authorization`, `flush_interval -1` present on both sites; gzip not applied to `/api/*`; no real hostname, password, hash or key committed (grep for bcrypt patterns found none); example file has fake values and a name not starting with `.env`; the only upstream is `backend:3000`.

## For the next cards

Compose must not publish port 3000, must persist Caddy's `/data`, and must pin `caddy:2.6.2`.
