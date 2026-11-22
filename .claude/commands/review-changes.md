---
description: Read-only review of the current diff or a named scope. Writes a report; never changes implementation.
argument-hint: "[task card path | scope-name] [git range]"
---

Review the current changes read-only. The calling workflow may run non-destructive gates (`make analyze`, `make test`, …) and hand the raw output to the reviewer. The `code-reviewer` agent itself only reads files, the diff, and that output.

## Scope

- **Task mode:** an active card in `docs/tasks/`. Write `docs/reviews/execute-<slug>.md`. If the card is already in `docs/tasks/done/`, stop — archived reports are history.
- **Free scope:** a lowercase kebab-case name that doesn't collide with any task slug or existing report. Write `docs/reviews/<scope>.md`.
- Use the git range the caller gives; otherwise the working tree vs `HEAD`. Don't guess a baseline.

## Severity

- **P0** — security hole, data loss, crash, broken build, broken API contract. Blocks.
- **P1** — likely regression, boundary violation, leaked listener/subscription, missing required behaviour or test. Blocks.
- **P2** — maintainability or low-risk improvement. May be deferred.

Every finding has a `file:line`, the impact, the evidence, and a concrete fix.

If an older finding has since been fixed and the task is still active, append a "Re-review" section to the same report. Never implement fixes here — wait for `/fix-review-findings <report>`.

Report the path, findings by severity, gates that ran, and remaining risk.
