---
task: status-finished-backend
status: passed
p0: 0
p1: 0
---

# Review: status-finished-backend

Changed (all under `backend/`): `lib/database.dart` (schema step 9), `lib/orders_api.dart` (status list, the `PATCH /orders/{id}` handler), `lib/orders_report.dart` (`deliveredOrders` renamed `finishedOrders`), comment-only edits in `report_summary.dart`, `report_detail.dart` and `orders_export.dart`, `lib/mock_orders.dart` and `bin/seed_mock_orders.dart` (the seed tool writes `finished`), nine existing tests updated, and two new test files (`test/orders_status_patch_test.dart`, `test/status_finished_migration_test.dart`). No Flutter code, no `CLAUDE.md`, no other card, and not `docs/deploy.md` (the owner's separate uncommitted edit). `paid` and `bank_transfer_static` are not added (qr-static cards). Owner answers applied: a cash order held in `awaiting_payment` stays cash; staff cancelling an order cancelled by the payment expiry is a real cancel that clears its deadline (option A).

## Gates

| Command | Exit | Note |
|---|---|---|
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | 753 tests |
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make analyze` | 2 | exactly 30 infos, the pre-existing baseline; no Flutter code changed |
| `make test` | 0 | 774 tests |
| `make check` | 2 | stops at `make analyze` on the baseline above (confirmed: `make: *** [Makefile:30: analyze] Error 1`); the later gates were run separately (rows above). Not claimed as passed. |

All gates were re-run by the main session after the executor finished; nothing changed afterwards.

## code-reviewer: P0 0, P1 0, P2 0

Step 9 is a new block that leaves steps 1-8 alone: one transaction, the two UPDATEs (`delivered` -> `finished`, `ready` -> `preparing`), version 9, rollback on error, idempotent; the migration tests include a real mid-step failure (a trigger refuses the second UPDATE) that leaves version 8 and every row unchanged. The status list is `awaiting_payment, preparing, finished, cancelled`; `ready` and `delivered` (and the old `pending`/`accepted`) answer 400 on POST and PATCH. PATCH runs the staff check first, before the body and the lookup (a test shows 401 before invalid JSON, an unknown status and an unknown id); same-status is a 200 no-op except `cancelled -> cancelled` with a deadline (a guarded `UPDATE ... WHERE status='cancelled'` that clears it); a cancelled order is final with the two fixed 409 texts; a transfer order cannot go to `awaiting_payment`, a cash order can and stays cash; every other move is one guarded `UPDATE ... WHERE id=? AND status=<read status>` that clears `payment_due_at`, never writes the method, and publishes only on a change. The sweep, lazy expiry and payment routes are unchanged and already need a transfer method, so a cash `awaiting_payment` order is never touched and answers 409 on all five payment routes. Reports count `finished` only, the CSV writes the raw status, `grep -rn "delivered\|'ready'" backend/lib backend/bin` leaves only the step-9 SQL and history comments. The main session also scanned the removed lines of the existing tests: the removed expectations are the version 8 -> 9, `delivered` -> `finished` and moved-to-new-rules ones; the `pending`/`accepted`/`ready`/`delivered` 400 checks are kept in the rewritten tests; no `skip:` added.

## Security review: see `security-status-finished-backend.md`.

## Deferred (written down)

- **P2, optional hardening (security review):** `PATCH` does not run the lazy expiry check first, so for up to about 15 seconds an overdue but not yet swept transfer order can be moved by staff to `preparing` or `finished` (the PATCH clears its deadline), and `awaiting_payment -> awaiting_payment` replies with the stale status. Allowed by the card ("the owner's unpaid-transfer moves") and only by staff behind the gate. If wanted later: call `_expireIfOverdue(id)` before the lookup at the start of the handler. Not part of this card.
- The restaurant card must handle 401/403/429 on the status-change path and clear stored credentials on 401 (note in `status-finished-restaurant` and `staff-login-restaurant`).

## Unverified (owner acceptance)

Step 9 on a copy of the owner's real `orders.db` after a dated backup. Nothing was checked against a running app or browser. **Do not deploy this card alone** (SF9): the apps still send `ready`/`delivered` and the restaurant page sends no proof on `PATCH`; an old restaurant page gets 401 and old apps get 400 (fails closed), and repeated empty-header retries count toward the 5-in-60-seconds lock.
