---
task: docker-caddy-config
status: passed
p0: 0
p1: 0
---

# Review: docker-caddy-config

Files (new): `deploy/docker/Caddyfile`, `deploy/docker/caddy.env.example`. `deploy/Caddyfile`, `dev/**`, `.github/**`, `Makefile`, `CLAUDE.md` untouched. Owner approvals for this task: edits under `deploy/docker/`; DOCKER4 stock `caddy` image plus read-only mounts (`/srv/customer`, `/srv/restaurant`); DOCKER5 pin Caddy 2.6.2 (keeps `basicauth`).

## Gates and checks

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make check` | 2 | stops at `make analyze`: 30 known infos, no Dart changed |
| `caddy validate` (2.6.2, fake env values) | 0 | "Valid configuration"; run by me and by the executor |
| `caddy adapt` with `CUSTOMER_HOST`/`RESTAURANT_HOST` unset | 0 | hosts fall back to `localhost` and `restaurant.localhost` |
| `caddy adapt` with both set to empty strings | 1 | Caddy refuses to load (`unrecognized global option: basicauth`): fails closed |

## Findings (code-reviewer): P0 0, P1 0, P2 2

- Accepted: default restaurant host is `restaurant.localhost` (the card suggested `localhost-restaurant`); browsers resolve `*.localhost` to loopback and Caddy uses its internal CA, so no public certificate can be requested.
- Accepted: three explanatory comments from `deploy/Caddyfile` are shortened and point back to it; the header says to keep the two files in sync by hand.

Side-by-side: both site blocks match `deploy/Caddyfile` apart from comments and the three allowed differences (env-driven hosts, `backend:3000`, `/srv` roots).

## Unverified (owner acceptance)

Real certificates; gate login in a browser; the live SSE stream through Docker; `caddy:2.6.2` image and `/data` volume (compose card); how compose reads the `$` in the hash.
