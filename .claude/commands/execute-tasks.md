---
description: Execute existing task cards end to end — implement, run gates, independent review, fix, archive.
argument-hint: "<docs/tasks/<slug>.md>..."
---

Execute the task cards in `$ARGUMENTS`. A card is only done when implementation, gates, review, fixes, and re-review are all complete.

## Pre-checks

1. Each path must be a regular `.md` file directly inside `docs/tasks/` (not `done/`, not a symlink, no `..`), with a lowercase kebab-case name. Reject anything else before reading it.
2. Read every card in full before editing anything.
3. Order by `blockedBy`, then by filename. Stop if a blocker isn't in `docs/tasks/done/` or the card is missing `executor`, `scopes`, `workKinds`, or `blockedBy`.
4. `executor` must be `task-executor`; anything else is an invalid card — stop.
5. Check `git status`, protect unrelated changes, and keep the diff inside the card's scope.

## Per-card loop

1. Implement the card and its tests together (follow the `task-executor` agent's rules).
2. Format only the Dart files you touched: `dart format <paths>`. Don't run `make format` on the whole repo — it would pull unrelated files into the diff.
3. Run the gates the change touches (`make analyze`, `make test`, `make backend-analyze`, `make backend-test`, `make boundaries`, `make format-check`). Record each command and its exit code. Never record a gate you didn't run.
4. **Freeze the candidate.** Don't edit code, tests, or the card until the first-round reviews are back.
5. Launch `code-reviewer` with the card, the diff, and the raw gate output. If the card says `securityReview: required` — or the diff actually crosses a trigger in `CLAUDE.md` → "Safety policy" (then add the field to the card first) — also launch `security-reviewer` on the same candidate. Run them in parallel where possible; neither sees the other's conclusions.
6. Write `docs/reviews/execute-<slug>.md` (and `docs/reviews/security-<slug>.md` when applicable) with frontmatter `task`, `status`, `p0`, `p1`, a "Gates" table (command, exit code), and the findings.
7. If there are P0/P1 findings, fix them in one batch (same rules as `/fix-review-findings`), rerun only the affected gates and reviewers, and append a "Re-review N" section to the same report. At most three fix rounds; then stop and ask the owner.
8. Before archiving, run `make check` once on the final candidate and record it.
9. When reviews are `passed` with `p0: 0`, `p1: 0`: move the card to `docs/tasks/done/` and update any references. Reviews stay where they are.

P2 findings may be deferred only if written down as a follow-up (new card or note in the report).

## Hard rules

- No commit, no push, no `--no-verify`, no `sudo`.
- No hand-editing `pubspec.lock`; use `dart pub` / `flutter pub`.
- No claimed verification without a command run in this session.
- Never rewrite archived cards or reviews.
- Browser/proxy/phone behaviour not checked by the owner is reported as **unverified**.

## Report

Cards completed, changed paths, review report paths, gate results, deferred findings, unverified items, and final `git status --short`.
