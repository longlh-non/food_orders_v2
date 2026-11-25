---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: [docker-backend-image, docker-caddy-config]
securityReview: required
---

# Docker step 3: a compose file that runs the backend and Caddy together

## Why

The backend image and the Caddy config only matter once something wires them: Caddy is the only thing the internet may reach, the backend is reachable only from Caddy, and the data and secrets live outside the images.

## Sources

`docker-backend-image` and `docker-caddy-config` (this folder), `docs/deploy.md` sections 2, 5.3, 5.5, 5.6 (the existing layout and the secret files), `CLAUDE.md` "Size limits" (backend must not be reachable around the proxy) and "Safety policy".

## Open decisions (owner), with recommendation

- DOCKER6 Data: named Docker volume or a host folder? Recommend **host folders (bind mounts)**: `/var/lib/food-orders/orders` style paths chosen in the card, owned by uid 10001 (the image's user; the owner runs the `chown`, agents never use `sudo`). Reason: everything the runbook already teaches (copy a photo into the images folder, run `sqlite3` on the database, `rsync` backups off the VM) keeps working on plain paths. Alternative: named volumes (more "Docker-like", but every such task needs a throwaway container).
- DOCKER7 Where the server builds from. Recommend **build the backend image on the server** from rsync'ed source (`docker compose build`), the same "build where it runs" rule as `docs/deploy.md` 5.4, so no registry and no ARM/x86 mismatch. The web builds are made with `deploy/build.sh` on a machine with Flutter and copied over (DOCKER4). Alternatives (build on the laptop and ship an image, or a registry such as GHCR) belong to the later Docker CD cards.
- DOCKER8 Docker Engine install on the VM is the owner's (official apt repository, signing key checked on the official page, no `curl | sh`). Note for the runbook: Docker's published ports bypass `ufw`; only 80 and 443 may be published.
- HOST1 (provider) and HOST2 (domain) stay open; nothing here depends on them except real certificates.

## How this relates to the existing cd-* cards

`cd-server-deploy-script` and `cd-github-deploy-workflow` are written for the **systemd path** (release folders and a `current` symlink, `systemctl restart`, reload of a host Caddy). They are not built, and this plan does **not** edit or replace them. These Docker cards sit **beside** them:

- If the owner keeps systemd as production (DOCKER1), the Docker cards are an optional second way to run the same app, and the cd-* cards proceed unchanged once HOST1 and HOST2 are decided.
- If the owner chooses Docker as production, the cd-* cards no longer fit (their script and rollback assume systemd). The follow-up would be two **new** cards (a Docker deploy script: backup, `docker compose build`/`up -d`, health check, rollback by previous image; then the GitHub workflow that calls it). They are deliberately **not** written now: the shape depends on DOCKER1, DOCKER7 and HOST1. The planner should be asked again after the owner answers.
- Neither path needs the other, so these cards have no `blockedBy` link to the cd-* cards.

## Goal

New `deploy/docker/compose.yaml` (name `compose.yaml`; Compose v2) with two services:

**backend**
- `build:` the image from `backend/` (DOCKER7); `restart: unless-stopped`.
- **No `ports:` at all.** Only `expose: 3000` or nothing (the compose network already connects the services). A comment states why: the 64 KB limit, the gate and the cross-site guard live in Caddy, and Docker published ports bypass `ufw`.
- Data: bind-mount the host folders to `/data` (database and `images/`), read-write.
- Secrets: `env_file:` pointing at a file outside the repo (suggested `/etc/food-orders/backend.env`, the same file the systemd path uses: `STAFF_ID`, `STAFF_PASSWORD`, optional `SHOP_*` and `BANK_*`). No `environment:` entry with a secret value.
- Hardening, each with a one-line reason and "unverified" where it may break the Dart AOT runtime: `read_only: true` with the data mounts writable, `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`, a memory limit that suits a 1 GB VM, log rotation (`json-file` with `max-size`/`max-file`; Docker's default keeps logs forever and request logs hold order ids).
- `healthcheck` from the image or compose, if the image card found one.

**caddy**
- Official image pinned (DOCKER5); `restart: unless-stopped`; `depends_on` the backend (healthy if a health check exists).
- `ports:` only `80:80` and `443:443` (no UDP/HTTP3, as `docs/deploy.md` 4.2 advises).
- Mounts: `deploy/docker/Caddyfile` read-only to `/etc/caddy/Caddyfile`, the two web build folders read-only to `/srv/customer` and `/srv/restaurant`, and **named volumes** for Caddy's `/data` (certificates; must persist) and `/config`.
- `env_file:` an outside-the-repo file (suggested `/etc/food-orders/caddy.env`: `CUSTOMER_HOST`, `RESTAURANT_HOST`, `FOOD_ORDERS_AUTH_USER`, `FOOD_ORDERS_AUTH_HASH`). The bcrypt hash contains `$`; in `env_file` use single quotes and never put it in `environment:` or the shell, where `$` is interpolated. The executor confirms against the Compose docs and flags it unverified.

Also: the example env files from `docker-caddy-config` plus `deploy/docker/backend.env.example` (names and fake values only), and a `.gitignore` line for any local copy of those files. Do **not** create or read any file named `.env*`; Compose reads a project `.env` automatically for interpolation, so the compose file must not use `${VAR}` interpolation for anything secret.

## Non-goals

Backups (next card), the runbook, a registry, CI (`.github/**`), the Docker CD cards, multi-host or swarm, a second Caddy for the old systemd layout, running both stacks on one VM at once (ports 80/443 clash; the runbook says "pick one"), changing the backend or its API.

## Tests written with the change

None runnable. If the executor's machine has Docker, `docker compose -f deploy/docker/compose.yaml config` is a cheap syntax check, but agents must not assume it exists; state "not run" otherwise.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| The backend service has no `ports:`; only Caddy publishes 80 and 443 | `security-reviewer` (review) |
| No secret value, real hostname or hash in the compose file or any committed file; secrets only through `env_file` to paths outside the repo | `security-reviewer` (review) |
| Certificates and data survive `docker compose down` and `up` (volumes/bind mounts, not container layers) | `code-reviewer` (review), then owner acceptance |
| Image tags pinned; hardening options each justified | `code-reviewer` (review) |
| `make check` exit 0 | gate |
| `docker compose up -d` brings both up; HTTPS answers 401 without the shared password and 200 with it; an order placed on the customer site shows live on the restaurant site; orders survive `docker compose restart` and a VM reboot; `curl http://SERVER_IP:3000` from outside fails | **owner acceptance, "unverified" until done** |

## Environment limits

Agents cannot run Docker, `sudo`, or reach a VM. Whether `read_only` and `cap_drop` break the built bundle, how Docker's iptables rules sit beside `ufw` (and Oracle's default rules), and bind-mount ownership for uid 10001 are all untested.

Approvals: **explicit owner approval for edits under `deploy/**`** (this task only). `.gitignore` is not on the protected list. No `.github/**`, `Makefile` or `CLAUDE.md` edit.
