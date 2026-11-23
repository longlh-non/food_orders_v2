---
task: ci-build-artifacts
status: passed
p0: 0
p1: 0
---

# Security review: ci-build-artifacts

## Scope

New `build` job in `.github/workflows/ci.yml` and the runbook text. Read-only review.

## Findings: P0 0, P1 0, P2 3

1. `ci.yml:84-98` credentials check is misleading: it greps the literal names `STAFF_PASSWORD`/`STAFF_ID`, which appear nowhere in `lib/` (the apps use the `X-Staff-*` header names), so it can only pass; `assets:` is commented out in `pubspec.yaml` and there are no `fromEnvironment` uses, so a `.env` cannot reach the build today and the `.env*` find is a reasonable tripwire. Fix: reword as a tripwire, not proof (deferred).
2. Supply chain: the sqlite3 build hook runs PR-controlled code and downloads a precompiled SQLite from github.com (hash-checked inside the package). Same class of risk as the existing `check` job (`dart test`); job has `contents: read`, no secrets, `persist-credentials: false`. Keep `pubspec.lock` changes under review.
3. Artifacts are readable by anyone with repo read access and a PR can alter its own artifact; 7-day retention is fine. Note for the CD card: deploy only artifacts from `push` to `main`, never from PR runs.

## Checked and clean

Triggers are `push` to `main` and `pull_request` only (no `pull_request_target`); no secrets referenced; least-privilege permissions; all three actions pinned by full SHA; no `${{ }}` in any `run:`; static `working-directory`; `build.sh` only builds; `needs: check`; only the two web builds are uploaded (backend bundle not); Flutter web release emits no source maps by default.

## Owner-verify

Upstream tag-to-SHA for checkout `fbc6f39…` (v5.1.0), flutter-action `1508160…` (v2.9.1), upload-artifact `cf430e03…` (v7.0.2); `ubuntu-latest` and Flutter `3.47.7` still resolve; fork PRs get no write token; unzip the first artifacts and confirm `index.html` and nothing unexpected.

## Verdict

**Passed**, P0: 0, P1: 0.
