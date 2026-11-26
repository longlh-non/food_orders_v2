---
task: status-finished-contract
status: passed
p0: 0
p1: 0
---

# Review: status-finished-contract

Changed: `CLAUDE.md` (owner-approved for this task only, 2026-11-26) and the card itself (two decision rows recorded as owner decided, wording fixes). Docs only: no code, no other card, and `docs/deploy.md` (the owner's earlier uncommitted edit) was not touched. The contract now describes `finished`, the staff-only `PATCH /orders/{id}`, cancelled-is-final and schema step 9; the code still uses `ready`/`delivered` and an open PATCH until the `status-finished-*` cards ship, and `CLAUDE.md` says so in a "Contract ahead of code" note.

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | re-run by the main session after the last fixes |
| `make boundaries` | 0 | re-run by the main session after the last fixes |
| `make check` | 2 | stops at `make analyze`: 30 known infos (`deprecated_member_use`), no Dart changed; the test and backend gates did not run. Not claimed as passed. |

## Round 1 (code-reviewer): P0 0, P1 1, P2 4

- **P1 fixed:** `CLAUDE.md` never said the code does not match the contract yet. Added the "Contract ahead of code" note at the top of "Backend" and softened the tenses that read as shipped (step 9, deploy order, Notifications).
- **P2 fixed:** stale "no cancel button today" sentence; outdated "asks for the staff ID and password" line; the no-op-200 rule versus the old `bank_transfer` -> `awaiting_payment` 409 (the no-op wins); the dangling "staff login task" reference (now names `staff-login-contract` and the order: staff check, then body, then lookup).

## Round 2 / re-review (code-reviewer): P0 0, P1 0, P2 3, all fixed

- `paid` was mentioned in the Notifications text without "once it exists": fixed.
- The "Contract ahead of code" note was widened to cover every sentence that mentions `finished`, the staff-only PATCH or step 9.
- The card's `paymentDueAt` bullet now carries the `cancelled -> cancelled` exception.

## Security review: see `security-status-finished-contract.md`.

## Deferred (written down)

- Lockout reaches the kitchen: a device on the wifi can block status changes for 60 seconds with five wrong attempts. Open point owned by `staff-login-contract` (how failed session tokens count); stated in `CLAUDE.md` and card SF13.
- `status-finished-backend` must test 409 on all five payment routes for a cash `awaiting_payment` order (written into the card's Tests).

## Unverified (owner acceptance)

That the backend and apps match this contract: nothing is implemented yet, so every rule is "agreed, not built". The owner should reread the new PATCH rules, the cancelled-is-final rule and the `cancelled -> cancelled` expiry cancel (a planner's recommendation the owner may overrule).
