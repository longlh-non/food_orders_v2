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
