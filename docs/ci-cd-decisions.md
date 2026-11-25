# CI/CD decisions

The owner's decisions for the CI/CD pipeline. On 2026-11-13 the owner accepted every recommendation ("all recommended"). The cards that carry them out:

- `docs/tasks/ci-dependabot-and-triggers.md`
- `docs/tasks/ci-build-artifacts.md`
- `docs/tasks/cd-server-deploy-script.md`
- `docs/tasks/cd-github-deploy-workflow.md`

This file is the record. The cards say how each decision is built. When a decision changes, add a dated line here; don't rewrite history.

## What already existed (before these cards)

`.github/workflows/ci.yml` runs `make check` with:
- actions pinned to commit SHAs;
- `permissions: contents: read`;
- `persist-credentials: false`;
- a pinned, cached Flutter;
- concurrency cancel;
- a 20-minute timeout.

The GitHub remote is `origin` → `github.com/longlh-non/food_orders` (checked 2026-11-13). At that date it held only the initial commit; later work was not yet committed or pushed, so it had never run through GitHub CI.

## Decided (2026-11-13)

### CI

| # | Decision | Why |
|---|---|---|
| D1 | CI runs on pushes to `main` and on pull requests, not on every push to every branch. | Before, a push to a PR branch ran the same checks twice. |
| D2 | Dependabot checks weekly, for GitHub Actions and for the Dart packages in `/` and `/backend`, with at most 3 open pull requests. A `sqlite3` update always gets a human look. | Keeps the pinned versions current without flooding. `sqlite3`'s build hook downloads a precompiled SQLite, so a bump changes what gets downloaded. |
| D3 | The Flutter version in `ci.yml` (`flutter-version`) is updated by hand. | Dependabot doesn't manage it, and a Flutter upgrade should be a deliberate change. |
| D4 | CI builds both web apps and the backend on pull requests and on `main`, after `make check` passes. | A broken build is caught before merging, not at deploy time. |
| D6 | Built files (artifacts) are kept for 7 days. | Long enough to download and test, short enough not to pile up. |

### CD (deployment)

| # | Decision | Why |
|---|---|---|
| D7 | On the server, each release goes in its own folder under `releases/`, and a `current` link points at the live one. | Switching or rolling back is changing one link. |
| D8 | After a deploy, the health check loads `http://127.0.0.1:3000/menu` on the server. If it fails, the script switches back to the previous release automatically. | There's no `/health` route. Adding one would be a separate, contract-first card. |
| D9 | Deploys happen when the owner pushes a version tag (`v1.0`, `v1.1`, ...), not on every push to `main`. | Deploying is a deliberate act. |
| D10 | The deploy job uses a GitHub Environment called `production`, with the owner as required reviewer, so each deploy waits for the owner's approval. | A tag alone can't push to the server. Owner to check: required reviewers on a **private** repo depend on the GitHub plan. |
| D11 | Only the owner holds the deploy secrets (SSH key, server address), stored as `production` environment secrets in GitHub. | Nothing secret in the repo, and other workflows can't read them. |
| D12 | Deploy uses plain `ssh` and `rsync` with a pinned server host key, no third-party deploy action. | Fewer outside dependencies; a man-in-the-middle can't pose as the server. |
| D13 | Server-only values never enter CI: `STAFF_ID`, `STAFF_PASSWORD`, `ORDERS_DB`, `IMAGES_DIR` and the access-gate password hash live on the server only. | CI can't leak what it never sees. |

**Database note (D7/D8):** a rollback restores the previous program, not the database. If a new schema step already ran, restore the dated backup the deploy script takes before every deploy, by hand (see `CLAUDE.md` → "Storage").

### Hosting (from the deploy cards)

| # | Decision | Why |
|---|---|---|
| HOST3 | The public demo is gated by one shared username and password (Caddy `basic_auth`) on both sites (option A in `deploy-demo-access-gate`). | The app has no real login. It isn't per-customer auth; the password is shared and only travels over HTTPS. |
| HOST5 | Backups: yes. `deploy/backup.sh` backs up the database and the images folder, with a restore rehearsal in the runbook. | The server holds the only copy of orders and photos. |

### Docker alternative (owner decisions, 2026-11-25)

Docker is an optional second way to run the server. The step-by-step guide is `docs/deploy.md` section 11a. **Nothing was run by an agent: files written, not run.**

| # | Decision | Why |
|---|---|---|
| DOCKER1 | Docker is an **alternative** to the systemd path, not a replacement. The `cd-*` cards stay valid. | The systemd path is already documented and reviewed. |
| DOCKER2 | Base images `dart:3.14.0` (build stage) and `debian:bookworm-slim` (run stage). Approved, **not digest-pinned yet**. | Same Dart version as development. Pin the digests after the first working build, and check the Dart image's Debian release against `bookworm`. |
| DOCKER3 | The Dockerfile is `backend/Dockerfile`. | The build context is the backend folder, so the customer-data folder stays out. |
| DOCKER4 | Caddy runs from the stock `caddy` image, with read-only mounts of the two web builds. No custom image. | Nothing to build or keep up to date. |
| DOCKER5 | Caddy pinned to `2.6.2`, which keeps `basicauth`. A November 2022 release: **accepted risk**, revisit by 2027-03-01, then move to a current 2.x and rename `basicauth` to `basic_auth` in **both** Caddyfiles together. | The Caddyfiles were checked on 2.6.2. |
| DOCKER6 | Data lives in host-folder bind mounts (`/var/lib/food-orders/data`, `/var/lib/food-orders/backups`), owned by uid 10001. | Survives `docker compose down`; plain files to back up and copy. |
| DOCKER7 | The backend image is built on the server from the rsync'ed source. | No registry, no extra account; the CPU architecture matches by construction. |
| DOCKER8 | Installing Docker Engine is the owner's job, from Docker's official apt repository. | Agents never use `sudo`. |
| DOCKER9 | Backups run in a small `backup` container (profile `tools`) that runs `deploy/backup.sh` unchanged. | The backend image has no `sqlite3`. |
| DOCKER10 | The backup is scheduled by the host's cron, on request of the owner. | Simple and visible. |

Carried-over cautions (from the Docker reviews): never publish port 3000 (no `-P`, no `-p 3000:3000`, no host networking), and Docker bypasses `ufw`; never `docker compose down -v` (deletes `caddy_data`); run the backup before every backend update (schema step 8 cannot be undone); restore is by hand; the `docker` group is root-equivalent and `env_file` values show in `docker inspect`. **Open:** digest pinning, the Caddy upgrade date above, and whether the hardening options work with the Dart bundle (all unverified).

HOST1 (provider) and HOST2 (domain) stay open.

## Still open (blocks cards 3 and 4)

These had no single recommendation, so "all recommended" doesn't settle them:

- **HOST1, provider:** Oracle Cloud Always Free or Google Cloud e2-micro (both described in `deploy-runbook`). It decides **D5**.
- **D5, CPU architecture of the backend program:** GitHub's normal runners and Google e2-micro are x86_64, but Oracle Ampere is ARM.
  - Recommendation once HOST1 is known: x86_64 → compile on `ubuntu-latest`; ARM → compile on the `ubuntu-24.04-arm` runner, or on the server.
  - Until then, `ci-build-artifacts` only checks that the backend compiles.
- **HOST2, domain:** the owner's own domain name for `customer.` and `restaurant.`.
- **Optional:** `actionlint` to check workflow files locally. It would be a new tool, so not adopted unless the owner asks.

## Verification

Agents can't run GitHub Actions or reach the server. For every card:
- the agent runs `make check` where relevant;
- `code-reviewer` and `security-reviewer` review the change;
- anything on GitHub or the server stays **unverified** until the owner pushes, sees the run pass, and rehearses a deploy and a rollback.
