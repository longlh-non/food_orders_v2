---
task: docs-menu-add-contract
status: passed
p0: 0
p1: 0
---

# Review: docs-menu-add-contract

Owner approved the `CLAUDE.md` edit for this task and accepted ADD1 to ADD9 as recommended (answers to the pre-run questions, 2026-11-24). Only `CLAUDE.md` changed; the part from `# Engineering contract` down was diffed against HEAD by the orchestrator and is byte-identical.

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make check` | 2 | stops at `make analyze` (28 baseline `deprecated_member_use` infos, unchanged: docs-only card touches no Dart) |

## Findings (code-reviewer): P0 0, P1 0, P2 3 — all fixed

1. `GET /menu` row said POST is a live write with no marker; added "`POST` is not live until `backend-menu-staff-add-endpoint` lands".
2. The staff-routes list named `POST /menu` as live with no marker; added the same marker.
3. The curl example reused "Xôi gà" from the sqlite3 example (would 409 if both were run); changed to "Xôi lá cẩm".

The table row was checked against the backend card (body, limits, check order, id slug rule, 201/400/401/403/429/409/413/503, 300 cap) and against `menu_api.dart`'s PATCH conventions: consistent.

## Follow-up for `backend-menu-staff-add-endpoint`

`CLAUDE.md` now has **five** mentions of `backend-menu-staff-add-endpoint` (the `GET /menu` row, the `POST /menu` row, the "Editing the menu" intro, the curl bullet, the staff-routes list). All must be reworded when the route lands. That card currently says "Do not edit `CLAUDE.md` here", so removing these markers needs either its own approval at run time or a small follow-up docs card. Find them with `grep backend-menu-staff-add-endpoint CLAUDE.md`.

## Unverified

Owner acceptance of the recorded limits and the 201 status (accepted in chat, not re-read in the file).

## Verdict

**Passed**, P0: 0, P1: 0.
