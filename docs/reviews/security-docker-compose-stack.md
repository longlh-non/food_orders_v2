---
task: docker-compose-stack
status: passed
p0: 0
p1: 0
---

# Security review: docker-compose-stack

Reviewer: security-reviewer. No P0, no P1, four P2. No concrete path to the backend that goes around Caddy was found.

## Checked and clean

Backend has no `ports:`, `expose:`, `network_mode` or second network; only Caddy publishes 80 and 443 (no UDP); no Docker socket; Caddy's admin API is not reachable from the backend and not published. No secret in the compose file or the examples; secrets only through `env_file` from `/etc/food-orders/*.env`; no `${...}` interpolation. The `.gitignore` pattern matches real env files and not the `.example` files. Hardening only tightens, and a broken option stops the service (fail closed). Caddyfile and web roots mounted read-only; certificates on a named volume; log rotation 10m x 3.

## Findings

1. P2 comment implied `env_file` values are hidden from `docker inspect`. **Fixed**: reworded; the `docker` group is root-equivalent.
2. P2 `$` in unquoted env values is interpolated. **Fixed**: `backend.env.example` says to avoid `$` and ` #`.
3. P2 `caddy.env.example` still says "the compose card decides" about `$` quoting. **Deferred**: that file is outside this task's approved edits; update it in `docker-deploy-runbook` (or a later approved edit): single quotes keep `$` literal in Compose v2 `env_file`, unverified until `docker compose config` and a login test on the real file.
4. P2 missing bind-mount folders are auto-created root-owned. **Fixed**: `create_host_path: false`.

## Needs real-environment confirmation

Single-quoted hash read literally; Dart bundle and Caddy under `read_only` + `cap_drop`; port 3000 unreachable from outside (check `iptables -S DOCKER` and the cloud firewall); mutable `caddy:2.6.2` tag without digest; never `docker compose down -v`.
