---
task: ci-dependabot-and-triggers
status: passed
p0: 0
p1: 0
---

# Review: ci-dependabot-and-triggers

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `python3 -c "import yaml; yaml.safe_load(...)"` on both `.github/workflows/ci.yml` and `.github/dependabot.yml` | 0 | valid YAML |
| `make format-check` | 0 | (no Dart touched) |
| `make boundaries` | 0 | |
| `make analyze` / `make check` | 2 | pre-existing, repo-wide, unrelated — same `material_ui` SDK deprecation tracked against every card in this batch. An earlier run of this gate was contaminated by a concurrently-running, then-incomplete sibling task (`backend-report-summary-xlsx`) and showed spurious `backend/` errors; re-run after that task finished and confirmed clean (only the 19 pre-existing findings, none in this card's files). |
| `actionlint` | not run | explicitly told not to install it, per the card |

## Changed paths

`.github/workflows/ci.yml` (D1: `on.push` scoped to `branches: [main]`; `on.pull_request` unchanged; one new comment above `flutter-version` for D3 — nothing else touched), `.github/dependabot.yml` (new, D2: three update entries — `github-actions` at `/`, `pub` at `/`, `pub` at `backend/` — weekly, `open-pull-requests-limit: 3` each), `docs/runbook-local.md` (section 7 "CI today" updated per the card's own docs note).

## Review (code-reviewer + security-reviewer, parallel, independent)

Both confirmed: `permissions: contents: read`, `persist-credentials: false`, concurrency/cancel, timeout, and both SHA-pinned actions are byte-identical to before — the diff touches only the two intended hunks. `dependabot.yml` has no token/secret/auto-merge/grouping and both target directories are real. The `sqlite3`-needs-human-look requirement (D2's known risk) is correctly implemented as a documented process control (comment in `dependabot.yml` + runbook note, cross-referencing `docs/ci-cd-decisions.md` D2) — there's no technical auto-merge field to disable, so documentation is the correct and sufficient control here. The `pull_request` trigger (not `pull_request_target`) and `contents: read` mean this change doesn't widen the fork-PR trust boundary.

**Code review: P0: 0, P1: 0, P2: 1** (runbook wording read as self-contradictory next to its own "unverified" caveat two lines later — fixed directly, see below).
**Security review: P0: 0, P1: 0, P2: 0.**

## Fix

`docs/runbook-local.md`: reworded "now triggers exactly one run" → "is now designed to trigger exactly one run," so it reads as a design-intent statement rather than a claim that contradicts the adjacent "Unverified until the owner pushes" note. One-line docs fix, no re-review needed.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `ci.yml` still has SHA pins, `contents: read`, concurrency, `make check` | Met — both reviewers confirmed byte-identical outside the two intended hunks |
| `dependabot.yml` has no token/secret, grouping/limits as chosen | Met |
| `make check` green locally | Not met end-to-end — halts at the pre-existing, unrelated `analyze` failure; format-check and boundaries (the steps before it) are green |
| A push to a PR branch starts exactly one run; Dependabot PRs appear | **Unverified** — owner on GitHub, as the card and runbook both say |

## Verdict

**Passed**, P0: 0, P1: 0 across both required reviews. The one P2 (docs wording) was fixed directly. GitHub-side behavior remains unverified by design (agents can't run GitHub Actions or see Dependabot).
