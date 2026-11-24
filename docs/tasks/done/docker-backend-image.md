---
executor: task-executor
scopes: [backend, dev-infra]
workKinds: [infra]
blockedBy: []
securityReview: required
---

# Docker step 1: a Dockerfile that builds and runs the backend

## Why

The owner wants an option to run the server in Docker. The backend is the hard part: it must be built with `dart build cli` (the `sqlite3` package has a build hook, so `dart compile exe` refuses it), and the result is a **bundle** (`bin/server` plus `lib/libsqlite3.so` and `lib/libdartaotserver.so`) that must stay together. Everything else in the Docker plan (compose, backups) sits on this image.

## Sources

`CLAUDE.md` "Backend" (Storage, Size limits, BIND_ADDRESS, Staff ID and password, Shop and bank settings), `docs/deploy.md` 5.4 (the existing bundle build), `backend/bin/server.dart` (reads `ORDERS_DB`, `IMAGES_DIR`, `BIND_ADDRESS`, `STAFF_*`, `SHOP_*`, `BANK_*`; port 3000 is fixed), `backend/pubspec.yaml` (SDK `^3.13.0`), `deploy/food-orders-backend.service` (the hardening the container should match in spirit).

## Open decisions (owner), with recommendation

- DOCKER1 Is Docker the production path, or only an alternative to the systemd path in `docs/deploy.md`? Recommend: an **alternative**, nothing in the systemd path changes (see "How this relates to cd-* cards" in `docker-compose-stack`).
- DOCKER2 Base images. Recommend the official `dart` image (build stage) and a plain `debian:bookworm-slim` (run stage), both **pinned to an exact tag** (a digest if the executor can read one). A base image is a new dependency, so the owner approves the two names. Alternative: one stage only (bigger image, simpler).
- DOCKER3 Where the files live. Recommend `backend/Dockerfile` and `backend/.dockerignore` (the usual place; context = `backend/`). Alternative: `deploy/docker/`.

## Goal

`backend/Dockerfile` (multi-stage) and `backend/.dockerignore`:

1. **Build stage:** copy `pubspec.yaml` + `pubspec.lock`, `dart pub get --enforce-lockfile` (never `pub upgrade`), copy the source, `dart build cli -t bin/server.dart -o /out`. The first build downloads a precompiled SQLite, so the build needs network access (say so in a comment).
2. **Run stage:** copy `/out/bundle/` only (the whole bundle, not just `server`), run as a **fixed non-root user** (uid 10001, no shell login), `WORKDIR` outside the data folder.
3. **Environment inside the image:** `ORDERS_DB=/data/orders.db`, `IMAGES_DIR=/data/images`, `VOLUME /data`, `EXPOSE 3000`. `STAFF_*`, `SHOP_*`, `BANK_*` are **never** set in the Dockerfile, not even empty; they arrive at run time.
4. **`BIND_ADDRESS` inside a container:** the backend's default is loopback, which in a container is unreachable from Caddy (a different container). So the image sets `BIND_ADDRESS=0.0.0.0` **inside the container only**. This is safe only because the container's port 3000 is never published to the host: that rule is enforced in `docker-compose-stack` (no `ports:` on the backend) and written as a comment in the Dockerfile. Do not change `server.dart`; the existing env var is enough.
5. **`.dockerignore`:** at least `data/`, `.dart_tool/`, `build/`, `*.db`, `*.db-*`, `.git`. `backend/data/` holds customer names and must never enter an image layer.
6. A `HEALTHCHECK` that calls `GET /menu` on `127.0.0.1:3000` inside the container (no `/health` route exists; adding one is a contract change and out of scope). The run image should not gain a tool just for this (no curl install); the executor picks the smallest working way (for example bash's `/dev/tcp`) and says why. If no clean way exists, leave the health check to compose and say so.

## Non-goals

Compose, Caddy, backups (later cards); a registry or CI image build (`.github/**`); changing any file under `backend/lib` or `backend/bin`; a `/health` route; image upload; the systemd path; secrets of any kind in the image or the build args.

## Tests written with the change

None runnable by agents: no agent can run `docker build` or `docker run`. `make backend-analyze` and `make backend-test` must stay green (nothing in Dart changes). Optional dry reading: `code-reviewer` checks the Dockerfile line by line against the list above.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Built with `dart build cli`, never `dart compile exe`; whole bundle copied | `code-reviewer` (review) |
| No `STAFF_*`/`SHOP_*`/`BANK_*` value, `ARG` or `ENV` for them in the file; `.dockerignore` excludes `data/` | `security-reviewer` (review) |
| Runs as non-root; `BIND_ADDRESS=0.0.0.0` is set and the port-not-published rule is explained in a comment | `security-reviewer` (review) |
| Base image tags pinned, owner approved the names | `security-reviewer` + owner approval |
| `make backend-analyze` and `make backend-test` exit 0 | gate |
| `docker build -t food-orders-backend backend/` succeeds; `docker run` with a data folder answers `GET /menu`; orders survive a container restart | **owner acceptance, "unverified" until done** |

## Environment limits

Agents cannot run Docker or `sudo`. Whether the build hook downloads SQLite inside the build stage, whether `libsqlite3.so` runs on `bookworm-slim`, and whether ARM vs x86 matters (build on the machine that will run it, as in the systemd path) are all unverified. The executor must say "unverified", never "passed".

Approvals: no `deploy/**`, `.github/**`, `Makefile` or `CLAUDE.md` edit in this card (files live under `backend/`). New base images need the owner's approval (DOCKER2).
