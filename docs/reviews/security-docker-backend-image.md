---
task: docker-backend-image
status: passed
p0: 0
p1: 0
---

# Security review: docker-backend-image

Reviewer: security-reviewer. No P0, no P1, four P2. Read-only; nothing built or run.

## Findings

- P2 port-not-published rule is only a comment (`EXPOSE 3000` with `BIND_ADDRESS=0.0.0.0`; `-P`, `-p 3000:3000` or host networking would skip the proxy and its 64 KB limit; Docker bypasses ufw). **Deferred** to `docker-compose-stack` (enforce) and `docker-deploy-runbook` (warn).
- P2 floating and unverified base images, no digest. **Deferred**: pin at the first real build (owner).
- P2 `.dockerignore` root-anchored and secrets not listed. **Fixed**: recursive patterns, `.env*`, `*.pem`, `*.key`.
- P2 credentials visible via `docker inspect` if compose uses `environment:`. **Deferred** to `docker-compose-stack`: `env_file` outside the repo, mode 600.

## Checked and clean

No ARG/ENV for secrets; run stage copies only `/out/bundle`; non-root uid 10001 with nologin; `/data` owned by it; WORKDIR outside `/data`; SQLite download hash-checked by the package and only in the build stage; `--enforce-lockfile`; healthcheck uses loopback and a public read-only route.

## Needs confirmation in a real environment

Tag exists; `libsqlite3.so` runs on bookworm-slim; `docker image history` shows no secrets; the image's `/app` holds only the bundle; a wrong-owner bind mount fails clearly.

## Gates

`make backend-analyze` 0, `make backend-test` 0 (nothing in Dart changed).
