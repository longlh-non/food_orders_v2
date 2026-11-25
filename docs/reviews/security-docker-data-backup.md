---
task: docker-data-backup
status: passed
p0: 0
p1: 0
---

# Security review: docker-data-backup

Reviewer: security-reviewer. No P0, no P1, four P2. Read-only; nothing built or run.

## Findings

1. P2 the backup container could reach `backend:3000` on the compose network, around Caddy's body limit, gate and cross-site guard. **Fixed**: `network_mode: none` on the `backup` service (the script never uses the network; the build still has it for `apt-get`).
2. P2 the cron example runs as root and would create a world-readable log; cron would also build the image (apt-get as root) from files in the checkout. **Fixed (comment)**: the example now starts with `umask 077;`, says to build the image once by hand with `--profile tools build backup`, and to keep the checkout root-owned.
3. P2 floating `debian:bookworm-slim` tag and unpinned apt `sqlite3`. **Deferred**: pin the base by digest at the first real build (owner), as with the backend image.
4. P2 the data mount is read-write. **Accepted**: `backup.sh` only runs `sqlite3 .backup` (a read of the source) and `tar -c`, and `rm`/`mv` act only on the backups folder; read-write is needed for the `-wal`/`-shm` files. No path damaging the live database was found. `.backup` may briefly delay backend writes (the backend waits up to 2 s).

## Checked and clean

Root `.dockerignore` (`*`, then `!deploy/backup.sh`) leaves only the script in the build context, so no layer can hold `backend/data`, pictures, env files or backups; the backend build uses `backend/` as its context. Backups are mode 600 (`umask 077`) in a 700 host folder, outside the repo, the image and any named volume that `down -v` would delete. Non-root (10001), `cap_drop: ALL`, `no-new-privileges`, profile-gated, no ports, no restart. `environment:` holds only non-secret paths and a count. `tar` stores symlinks as links and does not follow them.

## Needs real-environment confirmation

`.backup` through the bind mount while the backend runs; `read_only` plus tmpfs is enough; uid 10001 can write the 700 folders; `apt-get` works in the build.
