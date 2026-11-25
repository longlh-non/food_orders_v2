---
task: docker-data-backup
status: passed
p0: 0
p1: 0
---

# Review: docker-data-backup

Files: `deploy/docker/backup.Dockerfile` (new), root `.dockerignore` (new), `deploy/docker/compose.yaml` (a `backup` service under `profiles: [tools]` and three HOST PREPARATION lines). `deploy/backup.sh` is unchanged. Owner approvals for this task: edits under `deploy/**` (those files and the root `.dockerignore`), DOCKER9 backup container, DOCKER10 host cron (the example line is a comment only; nothing was installed).

## Gates and checks

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run after fixes |
| `make boundaries` | 0 | re-run after fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos, no Dart changed |
| `docker compose config` (temp copy, fake env files, local paths) | 0 | run after fixes; `--profile tools` output shows `network_mode: none` on the backup service. No image was built, no container started. |

## Findings (code-reviewer): P0 0, P1 0, P2 2

- Fixed (comment): `COPY --chmod` needs BuildKit (default in Docker Engine 23+ and Compose v2); noted in the Dockerfile.
- Accepted: `read_only` plus a 16 MB `/tmp` tmpfs is plausible but unverified (marked UNVERIFIED in the file); needs one real run.
- Note: the cron example's log file needs a root-writable path; the owner decides.

`deploy/backup.sh` was read against the container paths: it exits 1 if the database is missing, refuses a single quote in `ORDERS_DB`/`BACKUP_DIR`, and needs bash, tar, ls, date, mv, rm, tail, dirname (all in bookworm-slim) plus `sqlite3` (installed). Its `umask 077` gives 600 files; the backups folder must be owned by uid 10001, mode 700.

## Deferred / for `docker-deploy-runbook`

- Document "run the backup first" before every backend update (schema steps cannot be undone), the restore by hand, and the manual `rsync` pull off the VM.
- One real run is part of owner acceptance (see unverified).

## Unverified (owner acceptance)

`docker compose run --rm backup` writes a matching `orders-*.db` and `images-*.tar.gz` pair; `sqlite3 -readonly <file> "PRAGMA integrity_check"` says `ok`; `.backup` works through the bind mount while the backend runs (locking across containers); `read_only` and tmpfs are enough; uid 10001 can write the 700 folders without `DAC_OVERRIDE`; the image builds (floating `debian:bookworm-slim` tag, apt `sqlite3`); the cron job produces files the next day; a restore rehearsal works.
