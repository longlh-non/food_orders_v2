---
description: Fix findings from an existing review report, rerun affected gates, and re-review. Only when the owner asks (or inside /execute-tasks).
argument-hint: "<docs/reviews/<report>.md>"
---

Fix the unresolved findings in `$ARGUMENTS`.

1. The report must be in `docs/reviews/` and belong to an **active** task (card still in `docs/tasks/`) or a free scope. If its task is archived, stop — open a new card instead.
2. Read the report, the card, and the referenced code. Fix all P0/P1 in one batch; fix P2 only if trivial and in scope, otherwise list them as follow-ups.
3. Stay inside the card's scope. If a fix needs a scope or acceptance-criteria change, stop and ask the owner.
4. Rerun only the gates the fix affects and record command + exit code.
5. Re-review with the reviewer(s) whose findings were fixed, or whose inputs the fix changed. Run `security-reviewer` again if any file it reviewed changed.
6. Append a "Re-review N" section to the same report with what changed, which gates/reviewers reran and why, and update `status`, `p0`, `p1` in the frontmatter.
7. At most three rounds, then stop and ask the owner.

No commit, no push.
