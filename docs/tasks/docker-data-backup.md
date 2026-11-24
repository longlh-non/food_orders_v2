---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: [docker-compose-stack]
securityReview: required
---

# Docker step 4: backups of the database and pictures when the app runs in Docker

## Why

HOST5 (decided 2026-11-13) says backups: yes, with a restore rehearsal. The existing `deploy/backup.sh` already does the right thing (`sqlite3 .backup`, a matching `images-*.tar.gz`, keeps the last 14, mode 600) and reads `ORDERS_DB`, `IMAGES_DIR`, `BACKUP_DIR`, `KEEP` from the environment. The backend image deliberately has no `sqlite3` or `tar` tool, so the backup needs its own small container that sees the same data folders.

## Sources

`deploy/backup.sh`, `docs/deploy.md` section 9 (schedule, copy off the VM, restore), `CLAUDE.md` "Storage" (dated backup before schema steps, step 8 cannot be undone), `docker-compose-stack`.

## Open decisions (owner), with recommendation

- DOCKER9 Backup container: recommend a tiny image (`debian:bookworm-slim` + `sqlite3`, same pinned base as the backend run stage) that **reuses `deploy/backup.sh` unchanged**, started on demand as a compose service under `profiles: [tools]`, so a plain `docker compose up` never starts it. Alternative: install `sqlite3` on the host and run the script there against the bind-mounted host folders (no image at all, works only because of DOCKER6 = bind mounts). Recommend the container so the Docker path does not depend on host packages; the executor notes the alternative in a comment.
- DOCKER10 Schedule: recommend host `cron` (or a systemd timer) calling `docker compose run --rm backup` daily, as in `docs/deploy.md` 9.2. The cron entry is the owner's to install (agents never touch crontab or `sudo`).

## Goal

- `deploy/docker/backup.Dockerfile` (+ a root `.dockerignore` that allows only what that build copies, e.g. `*`, `!deploy/backup.sh`; it also protects `backend/data/` from any root-context build). Runs as the same uid as the backend (10001), so the files it reads and writes match.
- A `backup` service in `deploy/docker/compose.yaml` (edit of the previous card's file, same approval): `profiles: [tools]`, the same data bind mounts as the backend (the database needs write access to the folder for `.backup` to work with its side files), a separate bind mount for backups on the host (suggested `/var/lib/food-orders/backups`, owner-owned folder for uid 10001), env `ORDERS_DB=/data/orders.db`, `IMAGES_DIR=/data/images`, `BACKUP_DIR=/backups`, `KEEP=14`.
- Backups never go into the repo, an image layer or a named volume that `docker compose down -v` would delete.
- **Before a backend update:** the runbook card documents "run the backup first" (schema step 8 and any future step cannot be undone). No script change in this card; if the executor believes `backup.sh` needs a change, stop and write that as a follow-up instead of editing it.

## Non-goals

Changing `deploy/backup.sh` or the systemd path's backups; off-site copy automation (stays the manual `rsync` pull of `docs/deploy.md` 9.3); encrypting backups (still a known weak point); a restore script (the restore is documented by hand in the runbook card); backing up `/etc/food-orders/*.env`, the Caddy volumes or anything outside the database and pictures.

## Tests written with the change

None runnable by agents. Executor reads `backup.sh` against the container's paths (it errors if the database is missing, refuses a single quote in the paths) and records that the paths in the compose service match what the script expects.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `backup.sh` is reused unchanged, with the three paths set by environment | `code-reviewer` (review) |
| The backup service starts only on request (profile), runs non-root, publishes no port | `security-reviewer` (review) |
| Backups land outside any container filesystem and outside the repo | `code-reviewer` (review) |
| `make check` exit 0 | gate |
| `docker compose run --rm backup` writes a matching `orders-*.db` and `images-*.tar.gz` pair; `sqlite3 -readonly ... "PRAGMA integrity_check"` says `ok`; the cron job produces files the next day; a restore rehearsal works | **owner acceptance, "unverified" until done** |

## Environment limits

Agents cannot run Docker, cron or `sudo`. Whether `.backup` works through the bind mount while the backend is running (file locking across the container boundary) is untested.

Approvals: **explicit owner approval for edits under `deploy/**`** (this task only). A new root `.dockerignore` is not a protected path. No `.github/**`, `Makefile` or `CLAUDE.md` edit.
