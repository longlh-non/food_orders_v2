---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra, quality-gate]
blockedBy: [deploy-production-config, ci-dependabot-and-triggers]
securityReview: required
---

# CI: build both web apps and the backend, upload as artifacts

**Docs note (2026-11-19):** when this card lands, update `docs/runbook-local.md` sections 7 'CI today' and 8 'Deploy (CD) status'.

## Why

`make check` proves the code analyzes and tests, not that it builds for release. A release build can break on its own (web compile, `dart compile exe`, the sqlite3 build hook). Building in CI catches that before a deploy, and gives CD (later cards) one tested set of files to ship.

## Sources

`.github/workflows/ci.yml`, `deploy/build.sh` (from `deploy-production-config`: it already builds `build/customer` and `build/restaurant`; CI must CALL it, not copy its commands), `CLAUDE.md` "Verification", `docs/tasks/deploy-production-config.md` (P2-3: the sqlite3 hook downloads from github.com; fine on a GitHub runner).

## Open decisions (owner), with recommendation

- D4 When to build: recommend a second job `build` in `ci.yml` that runs only after `check` passes (`needs: check`), on PRs to main and on pushes to main. Cost is a few extra minutes per run. Alternative: build only on tags (cheaper, but breakage is found late).
- D5 Backend binary and CPU architecture (**depends on HOST1**): GitHub's default runner is x86_64, Oracle Ampere is ARM, Google e2-micro is x86_64. Recommend: if the host is x86_64, compile on `ubuntu-latest`; if ARM, either use GitHub's ARM runner (`ubuntu-24.04-arm`) or keep the existing plan of compiling on the VM and ship only the web builds from CI. Until HOST1 is answered, this card builds the two web apps and runs `dart compile exe` only as a compile check (artifact not uploaded for the backend).
- D6 Artifact retention: recommend `retention-days: 7` (web builds are rebuilt per run; keeps storage small). Artifacts are NOT secret-free by default: they contain no credentials by design, and a step checks that.

## Goal

- New `build` job as per D4, using the same pinned Flutter step as `check`. Runs `deploy/build.sh`, then `actions/upload-artifact` (pinned by SHA) for `build/customer` and `build/restaurant` as two separate artifacts.
- Backend: `dart compile exe backend/bin/server.dart -o build/food-orders-backend` per D5.
- Job `permissions: contents: read` only. No secrets used.

## Non-goals

Any deploy, SSH, secrets, Docker, publishing releases, changing `deploy/build.sh` behaviour (only call it).

## Tests written with the change

None new. The job is the test. Optional local check: run `deploy/build.sh` and `make check`.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Workflow calls `deploy/build.sh` rather than duplicating it | `code-reviewer` (review) |
| Actions pinned by SHA, minimal permissions, no secrets referenced | `security-reviewer` (review) |
| Customer and restaurant builds are separate artifacts | `code-reviewer` (review) + owner on GitHub |
| `make check` green | `make check` exit 0 (gate) |
| Build job passes on GitHub and artifacts download and contain `index.html` | owner pushes and checks, "unverified" until done |

## Environment limits

Agents cannot run Actions. Flutter web builds are slow, not a local gate; owner runs `deploy/build.sh` once locally.

## Decided by the owner (2026-11-13)

Every recommendation was accepted ("all recommended"): D1–D4 and D6–D13, HOST3 = A (shared Caddy `basic_auth`) and HOST5 = backups yes. The record, with reasons, is `docs/ci-cd-decisions.md`. Treat those as settled.

Still open: HOST1 (provider), D5 (which follows from HOST1) and HOST2 (domain). The GitHub remote exists (`origin` → `github.com/longlh-non/food_orders`, checked 2026-11-13). Edits to `.github/**` or `deploy/**` still need the owner's explicit approval when this card runs.
