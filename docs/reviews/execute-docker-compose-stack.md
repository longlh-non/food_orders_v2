---
task: docker-compose-stack
status: passed
p0: 0
p1: 0
---

# Review: docker-compose-stack

Files: `deploy/docker/compose.yaml`, `deploy/docker/backend.env.example` (new); `.gitignore` (one line: `deploy/docker/*.env`). Owner approvals for this task: edits under `deploy/**` (those files), DOCKER6 host-folder bind mounts, DOCKER7 build on the server. Caddyfile, `caddy.env.example`, `backend/Dockerfile`, `dev/`, `.github/`, `Makefile`, `CLAUDE.md` untouched.

## Gates and checks

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run after fixes |
| `make boundaries` | 0 | re-run after fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos, no Dart changed |
| `docker compose -f <temp copy> config` | 0 | run after fixes on a temp copy with fake env files and local paths (the real file points at `/etc/food-orders/*.env`, which does not exist here); no container was built or started |

## Findings (code-reviewer): P0 0, P1 0, P2 8

Fixed:
- `STAFF_PASSWORD` placeholder was a valid-looking password; now `CHANGE-ME` (under 12 characters), so a forgotten edit leaves the staff routes off (403).
- Bind mounts now use the long syntax with `create_host_path: false` (a missing host folder is an error, not an empty root-owned one; the web roots are `read_only`). Validated by `docker compose config`.
- `backend.env.example` now says to avoid `$` and ` #` in values.
- Comment about `docker inspect` reworded (see security P2 1).

Accepted / for the runbook card (`docker-deploy-runbook`):
- `caddy:2.6.2` is a Nov-2022 release (owner chose it, DOCKER5, to match the validated config). Record it as an accepted risk with a date to revisit, and plan a later bump to a current 2.x with `basicauth` renamed to `basic_auth` in both Caddyfiles together.
- File ownership: the systemd path creates `backend.env` as `food-orders:food-orders`; Docker reads it as root. Say which wins if the file is shared.
- `chmod 700` on the data folder owned by uid 10001: explain `sudo cp` / `sudo -u '#10001'` for pictures and `sqlite3`.
- Warn never to run `docker compose down -v` (deletes `caddy_data`, brings back CA rate limits).
- Mention the healthcheck request in the backend log every 30 s.
- `stop_signal: SIGINT` duplicates the image's `STOPSIGNAL`: kept on purpose.

## Unverified (owner acceptance)

`docker compose up -d`; whether `read_only` and `cap_drop: ALL` work for the Dart bundle and for Caddy 2.6.2; memory limits; uid 10001 can write the bind mount; Compose reads the single-quoted `$` hash literally; `curl http://SERVER_IP:3000` fails from outside and Docker's iptables rules beside `ufw`; certificates and data survive `down`/`up` and a reboot; HTTPS 401/200 and the live stream.
