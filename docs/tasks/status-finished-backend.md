---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [status-finished-contract, staff-login-contract]
securityReview: required
---

# Backend: schema step 9 (`delivered` -> `finished`), staff-set status on PATCH, reports, CSV and seed tool

Planned 2026-11-26, revised for staff-set status, "cancelled is final", the owner's change that **a cash order may go to `awaiting_payment` (staff only)**, and the staff session. Decisions SF3, SF4, SF6, SF7, SF13, SF15, SF16, SF17 in `status-finished-contract`. Security review is required: it moves PATCH behind the staff check, rewrites the payment guards and runs an irreversible data migration.

**Before this card runs the owner answers** the two open items of SF16 (a cash `awaiting_payment` order: method stays `cash` = A, recommended; cash -> `paid`: refused, recommended). The tests below assume the recommendations.

## Sources

`backend/lib/database.dart` (steps 7 and 8 show the pattern; `orders.status` has no CHECK), `backend/lib/orders_api.dart` (`orderStatuses` near line 731, `statusAwaitingPayment`, the PATCH handler near line 427, `_gate.check(req)` as the staff routes use it near line 474, `_isLiveAwaiting` / `_expireIfOverdue` (confirm they need a transfer method **and** a deadline, so a cash `awaiting_payment` order is never touched), the export branch near line 313, comments at 243), `staff_gate.dart`, `orders_report.dart` (`deliveredOrders`, line ~72), `report_summary.dart`, `report_detail.dart`, `orders_export.dart` (writes the raw status), `mock_orders.dart` (line ~161), `bin/seed_mock_orders.dart`, and the tests that mention the old statuses: `orders_api_test`, `orders_export_api_test`, `orders_export_test`, `orders_payment_test`, `orders_payment_transitions_test`, `orders_report_test`, `report_detail_test`, `report_summary_test`, `mock_orders_test`, `seed_mock_orders_test` (the executor greps `delivered|ready` and `PATCH` in `backend/` and lists every hit; every existing PATCH test needs staff proof now, and any test that moves a cancelled cash order on must change).

## Goal

1. **Schema step 9** (never edit steps 1-8): in one transaction `UPDATE orders SET status = 'finished' WHERE status = 'delivered'` and `UPDATE ... SET status = 'preparing' WHERE status = 'ready'` (SF3). No rebuild. Update the step list in the doc comment above `migrate`.
2. **Status list:** `orderStatuses` = `awaiting_payment, preparing, finished, cancelled`; add `statusFinished`; update the "keep in sync" comment. `ready` / `delivered` give 400 on `POST` and `PATCH`.
3. **PATCH becomes a staff route** (SF13): `_gate.check(req)` first, **before** the body is read and before the lookup; 401 / 403 / 429 as the other staff routes. **Use the one existing staff check and nothing else**: today it accepts the password headers; `staff-login-backend` later makes the same call accept a staff session, so this card needs no session code and no change when that lands. Then the rules (SF6/SF16):
   - unknown status 400; unknown id 404; same status 200 and nothing changes;
   - **a `cancelled` order PATCHed to any other status is 409 for every kind**: transfer methods "Use the payment routes", cash "A cancelled order can't be changed". Checked before anything else about the target;
   - target `awaiting_payment`: **`cash` -> allowed** (owner; method stays `cash`, `paymentDueAt` stays null); old `bank_transfer` -> 409 "Use the payment routes"; (`bank_transfer_static` is opened by `qr-static-backend-transitions`);
   - the owner's unpaid-transfer moves: an `awaiting_payment` transfer order may go to `preparing`, `finished` and `cancelled` (the `paid` target is added with the status in qr-static); a cash `awaiting_payment` order may go to `preparing`, `finished`, `cancelled`;
   - every other target from every non-cancelled status is allowed for every method;
   - a **changing** PATCH sets `payment_due_at = NULL` in the same `UPDATE` (a no-op keeps it); the method is never touched; the reply and the stream carry the updated order.
   - Fixed error strings, never echoing the request.
4. **Reports:** `deliveredOrders` -> `finishedOrders` testing `status == 'finished'`; rename callers and comments. Cells, headings and file names unchanged.
5. **CSV:** no code change expected (raw status); update the doc example and tests.
6. **Seed tool:** `mock_orders.dart` writes `finished` (and its comment); the seed tests follow.

## Non-goals

Any Flutter code. The `paid` status and the `bank_transfer_static` method and their PATCH rules (qr-static). The session (`staff-login-backend`). A payment-route change (the expiry routes may still revive an expired order, SF6). The audit log (`order-status-audit-log`, which hooks into this PATCH handler later).

## Tests written with the change

- migration: a version-8 database with `delivered`, `ready`, `preparing`, `cancelled`, `awaiting_payment` rows (cash, transfer, legacy NULL method) migrates to 9: `delivered` -> `finished`, `ready` -> `preparing`, every other row, its order and its `payment_*` values intact; a second open does nothing; a failure mid-step leaves version 8.
- POST with `ready` / `delivered` -> 400; `preparing` and `awaiting_payment` cases unchanged.
- PATCH gate (password headers, the only proof that exists yet): no headers 401; wrong 401; disabled 403; lock-out 429 with `Retry-After`; the gate answers **before** a bad body or unknown id; a correct call works.
- PATCH moves: `preparing -> finished`; `finished -> preparing`; any non-cancelled status -> `cancelled` (also from `finished`; from `awaiting_payment` the deadline is cleared); **cancelled -> anything else is 409** for cash ("A cancelled order can't be changed"), old transfer and an expiry-cancelled transfer ("Use the payment routes"), and `cancelled -> cancelled` is 200; an `awaiting_payment` old `bank_transfer` -> `preparing`, `finished`, `cancelled` all 200 with `paymentDueAt` null; **cash -> `awaiting_payment` 200, method still `cash`, `paymentDueAt` null**, then -> `preparing`, `finished`, `cancelled` all 200; bank_transfer -> `awaiting_payment` 409 "Use the payment routes"; `ready` / `delivered` 400; the method is unchanged after every move; the stream carries each change.
- cash `awaiting_payment` order (SF16 A): the sweep and a payment-route call on another order leave it alone; `confirm-payment`, `switch-to-cash`, `staff-switch-to-cash`, `renew-payment`, `payment-qr` on it answer 409; it counts in no report.
- sweep and routes (SF17): an overdue order staff moved to `preparing` is not touched by the sweep or by a payment-route call on another order; the payment routes on it answer 409; an order **cancelled by the expiry** can still be renewed / switched to cash by the existing routes (unchanged tests pass, PATCH proof aside).
- reports: a `finished` order counts in both Excel reports; one test shows a month's numbers change when an order is PATCHed into and then out of `finished`; `preparing`, `awaiting_payment`, `cancelled` count nowhere.
- CSV: a finished order's status cell is `finished`; the leading-`=` neutralising is unchanged.
- seed tool: writes `finished` and `cancelled` only; the report tests that use it pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Gates | `make backend-analyze`, `make format-check` exit 0 |
| Step 9 never edits a shipped step and keeps all other data | `code-reviewer`, `security-reviewer` (reviews) |
| PATCH is unreachable without the staff check; a cancelled order can't be changed by PATCH; no route other than PATCH got looser; a cash `awaiting_payment` order can't be reached by any customer route | `security-reviewer` (review) |
| `grep -rn "delivered\|'ready'" backend/lib backend/bin` finds no status use | `code-reviewer` (review) |
| Migration on a copy of the owner's real `orders.db` keeps every order | owner acceptance after a dated backup, "unverified" until done |

## Environment limits

The migration can't be undone: dated backup first (CLAUDE.md "Storage"). The apps still send `ready` / `delivered` and an unproven PATCH until the restaurant and customer cards ship, so do not deploy this card alone (SF9).
