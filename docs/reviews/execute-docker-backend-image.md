---
task: docker-backend-image
status: passed
p0: 0
p1: 0
---

# Review: docker-backend-image

Files: `backend/Dockerfile`, `backend/.dockerignore` (new). Owner decisions: DOCKER2 base images approved (`dart` build, `debian:bookworm-slim` run); DOCKER3 files in `backend/`; DOCKER1 Docker is an alternative to systemd.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make backend-analyze` | 0 | re-run after fixes |
| `make backend-test` | 0 | re-run after fixes |
| `make check` | 2 | stops at `make analyze`: 30 known `deprecated_member_use` infos; no Dart changed |

No `docker` command was run (not allowed by the card).

## Findings (code-reviewer): P0 0, P1 0, P2 5

- Fixed: add `STOPSIGNAL SIGINT` (server handles only SIGINT; `docker stop` sends SIGTERM to PID 1).
- Fixed: `.dockerignore` patterns made recursive (`**/data/`, `**/*.db`, `**/*.db-*`, `**/images/`) and `.env*`, `*.pem`, `*.key` added.
- Fixed (comment): note to check the Debian release of the dart image against bookworm at the first build.
- Accepted: healthcheck logs one request every 30 s (mention in the compose or runbook card).
- Accepted: `useradd` availability on bookworm-slim is part of the unverified build.

## Findings (security-reviewer, `security-docker-backend-image.md`): P0 0, P1 0, P2 4. See that report.

## Deferred follow-ups (P2, written down)

- **Image pinning:** `dart:3.14.0` is taken from the local `dart --version` (tag existence not looked up); `debian:bookworm-slim` is a floating tag; no digests. Pin `image:tag@sha256:...` at the first real `docker build` (owner).
- **`EXPOSE 3000` + `BIND_ADDRESS=0.0.0.0`:** the "never publish port 3000" rule is only a comment here. `docker-compose-stack` must enforce it (no `ports:` on the backend, no `network_mode: host`) and `docker-deploy-runbook` must warn against `docker run -P` / `-p 3000:3000` and say that Docker bypasses ufw.
- **Secrets at run time:** `docker-compose-stack` must use `env_file` from a path outside the repo (mode 600), never `environment:` or `-e` (visible in `docker inspect`).

## Unverified (owner acceptance)

`docker build -t food-orders-backend backend/`; the SQLite download in the build stage; the native libraries on bookworm-slim and CPU architecture; the healthcheck; `docker run` answering `GET /menu`; orders surviving a restart; bind-mounted `/data` owned by uid 10001.
