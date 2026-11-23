---
task: ci-dependabot-and-triggers
status: passed
p0: 0
p1: 0
---

# Security review: ci-dependabot-and-triggers

## Scope

`.github/workflows/ci.yml` (trigger change + one comment), new `.github/dependabot.yml`, `docs/runbook-local.md` (docs only).

## Findings

None. P0: 0, P1: 0, P2: 0.

## Checks performed

1. **Trigger change** — `on.push` scoped to `branches: [main]`; `on.pull_request` untouched and still plain `pull_request` (never `pull_request_target`), so a fork PR still never gets repo secrets or write access. `permissions: contents: read` unchanged. Restricting `push` to `main` narrows triggerable runs; no new attack surface.
2. **`dependabot.yml`** — no token/credential/`registries:`/`target-branch` fields; no auto-merge field exists in the schema and none was added; `open-pull-requests-limit: 3` on all three ecosystems.
3. **SHA pins** — `actions/checkout` and `subosito/flutter-action` pins unchanged, byte-identical; no tag/branch reference introduced anywhere.
4. **Baseline controls intact** — `permissions: contents: read`, `persist-credentials: false`, `concurrency`/`cancel-in-progress: true` all present and unchanged.
5. **`sqlite3` human-look requirement** — implemented as a documentation-only control (comment in `dependabot.yml:66-68` + `docs/runbook-local.md` note, both cross-referencing `docs/ci-cd-decisions.md` D2). Dependabot's schema has no auto-merge field to misconfigure, so a documented process control is the correct and complete implementation.
6. No secrets committed; no widening of the fork-PR trust boundary.

## Unverified (owner, on GitHub)

A PR-branch push triggers exactly one run; Dependabot opens its weekly PRs; a Dependabot PR touching `backend/pubspec.yaml`'s `sqlite3` entry actually gets a human look in practice (process control, not technical — can't be verified from this sandbox).

## Verdict

**Passed**, P0: 0, P1: 0, P2: 0. Safe from a security standpoint: no secrets, no weakened pins or permissions, no widened trust boundary, and the one accepted risk (sqlite3 bumps) is correctly documented rather than left to Dependabot's default (auto-merge-less) behavior.
