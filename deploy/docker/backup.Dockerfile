# Backup image (DOCKER9): runs deploy/backup.sh, unchanged, next to the data.
# The backend image has no sqlite3 or tar tool on purpose, so the backup gets
# its own tiny image. Build context MUST be the repo root (it copies
# deploy/backup.sh); the compose `backup` service sets that.
#   docker build -f deploy/docker/backup.Dockerfile -t food-orders-backup .
#
# Alternative (not used): install sqlite3 on the host and run deploy/backup.sh
# there against the bind-mounted host folders. No image at all, but the Docker
# path would then depend on host packages.
#
# The root .dockerignore allows only deploy/backup.sh into this build, so
# backend/data (customer names) is never sent to the Docker daemon.

# Same base as the backend run stage (same UNVERIFIED notes apply: floating
# tag, no digest; pin at the first real build).
FROM debian:bookworm-slim

# sqlite3 CLI for `.backup`. tar, ls, date and bash are already in
# bookworm-slim (coreutils, tar and bash are Essential/required packages).
RUN apt-get update \
 && apt-get install -y --no-install-recommends sqlite3 \
 && rm -rf /var/lib/apt/lists/*

# Same uid as the backend (10001), so files read and written match the host
# folder owner. No login shell, no home directory.
RUN useradd --uid 10001 --user-group --no-create-home --shell /usr/sbin/nologin app

# `COPY --chmod` needs BuildKit (default in Docker Engine 23+ and Compose v2).
COPY --chmod=755 deploy/backup.sh /usr/local/bin/backup.sh

# No secrets and no paths baked in: ORDERS_DB, IMAGES_DIR, BACKUP_DIR and KEEP
# come from the compose service. Backups are never written into an image layer.
USER 10001:10001
ENTRYPOINT ["/usr/local/bin/backup.sh"]
