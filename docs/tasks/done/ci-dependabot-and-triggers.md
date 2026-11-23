---
executor: task-executor
scopes: [dev-infra]
workKinds: [infra]
blockedBy: []
securityReview: required
---

# CI: stop double runs, add Dependabot for actions and pub

**Docs note (2026-11-19):** when this card lands, update `docs/runbook-local.md` section 7 'CI today'.

## Why

`.github/workflows/ci.yml` is already in good shape: actions pinned by SHA, `permissions: contents: read`, `persist-credentials: false`, concurrency cancel, 20 minute timeout, Flutter pinned and cached, `make check`. This card does NOT redo any of that. Two gaps remain:

1. `on: push` (all branches) plus `on: pull_request` runs the same gate twice for every PR branch push.
2. Pinned SHAs and the pubspec versions never get updated, so they go stale silently.

## Approvals needed before start

Owner approves edits to `.github/**` for this task. Owner confirms the GitHub remote exists and the repo has been pushed (agents cannot check `git remote -v`).

## Open decisions (owner), with recommendation

- D1 Trigger: recommend `push` on `main` only plus `pull_request` (no double run). Alternative: leave as is (simple, costs minutes).
- D2 Dependabot: recommend yes, weekly, for `github-actions`, `pub` at `/` and `pub` at `/backend`, `open-pull-requests-limit: 3`. Each update PR runs `make check`, which is the safety net. Alternative: no Dependabot and a calendar reminder. Note: a `sqlite3` package bump changes the build hook that downloads a binary (CLAUDE.md, deploy-production-config P2-3); such a PR needs a human look, never auto-merge.
- D3 Dependabot does not bump `flutter-version` in `ci.yml`; the owner bumps it by hand together with their local Flutter. Write that in a YAML comment.

## Goal

- `ci.yml`: change `on:` per D1. Nothing else changes.
- New `.github/dependabot.yml` per D2.

## Non-goals

New actions, new secrets, build jobs, deploy, auto-merge, dependency-review action (needs the dependency graph feature; revisit only if the repo is public).

## Tests written with the change

None runnable. Optional: `actionlint` on the YAML locally. It is a new tool, so the owner decides; do not install it.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `ci.yml` still has SHA pins, `contents: read`, concurrency, `make check` | `code-reviewer` + `security-reviewer` (review) |
| `dependabot.yml` has no token or secret, grouping/limits as chosen | `security-reviewer` (review) |
| `make check` green locally | `make check` exit 0 (gate) |
| A push to a PR branch starts exactly one run; Dependabot PRs appear | owner on GitHub, "unverified" until done |

## Environment limits

Agents cannot run GitHub Actions or see Dependabot. The GitHub run is "unverified" until the owner pushes.

## Decided by the owner (2026-11-13)

Every recommendation was accepted ("all recommended"): D1–D4 and D6–D13, HOST3 = A (shared Caddy `basic_auth`) and HOST5 = backups yes. The record, with reasons, is `docs/ci-cd-decisions.md`. Treat those as settled.

Still open: HOST1 (provider), D5 (which follows from HOST1) and HOST2 (domain). The GitHub remote exists (`origin` → `github.com/longlh-non/food_orders`, checked 2026-11-13). Edits to `.github/**` or `deploy/**` still need the owner's explicit approval when this card runs.
