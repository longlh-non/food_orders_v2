# Backend image: build with the Dart SDK, run on a plain Debian.
# Build it from the backend folder:  docker build -t food-orders-backend backend/
#
# The first build needs network access: the sqlite3 package's build hook
# downloads a precompiled SQLite (and checks its SHA-256) while the bundle is
# built. A later build reuses the cached layers.

# --- Build stage -------------------------------------------------------------
# Pinned to the Dart version used locally (3.14.0; backend needs ^3.13.0).
# UNVERIFIED: that this exact tag exists on Docker Hub (not looked up), and
# no digest is pinned. Fix the tag at the first real `docker build`.
FROM dart:3.14.0 AS build
WORKDIR /src

# Dependencies first, so they stay cached while only the source changes.
# --enforce-lockfile: build exactly what pubspec.lock says, never upgrade.
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get --enforce-lockfile

COPY . .
# `dart build cli`, NOT `dart compile exe`: the sqlite3 package has a build
# hook and `dart compile exe` refuses it. The result is a bundle
# (bin/server + lib/libsqlite3.so + lib/libdartaotserver.so).
RUN dart build cli -t bin/server.dart -o /out

# --- Run stage ---------------------------------------------------------------
# UNVERIFIED: the bundle's native libraries running on bookworm-slim (glibc);
# build on the same CPU architecture that will run it. At the first real
# build, check which Debian release the dart image is built on: if it is newer
# than bookworm the bundle may fail with "GLIBC_x.y not found", and this stage
# must then use the matching Debian (or the same dart image).
FROM debian:bookworm-slim

# Fixed non-root user (uid 10001), no login shell and no home directory.
# /data is created and owned by it, so a fresh volume mounted there is
# writable; a bind mount must be owned by uid 10001 on the host.
RUN useradd --uid 10001 --user-group --no-create-home --shell /usr/sbin/nologin app \
 && mkdir /data \
 && chown app:app /data

# Copy the WHOLE bundle: `server` loads the .so files in lib/ next to it, so
# copying only bin/server would start and then crash.
COPY --from=build /out/bundle/ /app/

# No secrets here, on purpose: STAFF_*, SHOP_* and BANK_* are never set in
# this file (not even empty) and never passed as build args. They are given
# when the container runs, so they never end up in an image layer.
ENV ORDERS_DB=/data/orders.db \
    IMAGES_DIR=/data/images

# The server listens on loopback by default, which another container (the
# proxy) cannot reach. Inside the container it must listen on all interfaces.
# This is safe ONLY because port 3000 is never published to the host: do not
# add `ports:` / `-p 3000:3000` for this container. Only the proxy container,
# on the private Docker network, may reach it (the proxy enforces the 64 KB
# request limit that the backend relies on).
ENV BIND_ADDRESS=0.0.0.0

# Orders, menu and pictures live here and must outlive the container.
# `backend/data/` holds customer names: it is excluded in .dockerignore.
VOLUME /data
EXPOSE 3000

# WORKDIR is outside /data, so the app never treats its own folder as data.
WORKDIR /app
USER 10001:10001

# No /health route exists, so ask for GET /menu. bash's /dev/tcp is already in
# the image, which avoids installing curl or wget just for this; the check
# passes only when the status line says 200.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["bash", "-c", "exec 3<>/dev/tcp/127.0.0.1/3000 && printf 'GET /menu HTTP/1.0\\r\\nHost: localhost\\r\\n\\r\\n' >&3 && read -r line <&3 && [[ $line == *' 200 '* ]]"]

# The server shuts down cleanly on SIGINT only (bin/server.dart), while
# `docker stop` sends SIGTERM by default, which a PID 1 without a handler
# ignores (then SIGKILL after 10 s). Ask Docker to send SIGINT instead.
STOPSIGNAL SIGINT

CMD ["/app/bin/server"]
