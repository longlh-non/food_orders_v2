---
task: backend-order-payment-method
status: passed
p0: 0
p1: 0
---

# Security review: backend-order-payment-method

Date: 2026-11-19. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review.

## Scope

The `CLAUDE.md` API table and order rules, `backend/lib/orders_api.dart`, `backend/lib/database.dart` (schema steps 7 and 8), `backend/bin/server.dart` (passes `ShopSettings` to `OrdersApi`), and the tests (`backend/test/orders_payment_test.dart` new, older tests adapted).

## Gates (first round)

Run by the executor in this session on the candidate as reviewed.

| Command | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` |
| `make backend-test` | 0 | `+449: All tests passed!` |
| `make format-check` | 0 | `Formatted 66 files (0 changed)` |
| `make analyze` | 0 | `No issues found!` |
| `make test` | 0 | `+343: All tests passed!` |
| `make boundaries` | 0 | `boundaries: ok` |

## Findings

### P1: the "can't skip payment" guard is bypassed through `cancelled`

`backend/lib/orders_api.dart:189-198`. The guard only checks orders whose current status is `awaiting_payment`. With no login (an accepted risk), anyone on the wifi can:

1. POST a `bank_transfer` order (it is created `awaiting_payment`);
2. PATCH it to `cancelled` (allowed);
3. PATCH it to `preparing`, `ready` or `delivered` (allowed, because the current status is now `cancelled`).

The unpaid order then reaches the kitchen. An order cancelled by the 5-minute expiry can be brought back the same way, although the owner decided that only staff "switch to cash" may bring it back (PAY5, PAY13).

**Fix:** refuse a PATCH that moves a `bank_transfer` order out of `cancelled` (409 "Use the payment routes"). Add a test for the three steps above, and correct the `CLAUDE.md` PATCH wording.

### P2

- **Backups are documentation only.** A restart on the new code runs the irreversible step 8 right away. Consider a startup log line before a destructive step runs. Deferred: written down as a follow-up for `docs-payment-and-reports`, so the runbook says "back up before starting this version".
- **`payment_due_at` is cleared on every PATCH, not only on cancel.** It is fixed in the same batch (see the code review, finding 1).

## Checked and clean (summary)

- **No races:** there is no `await` between the lookup, the guard and the UPDATE; SQLite is synchronous and the server runs in a single isolate.
- **POST parsing:** `paymentMethod` must be exactly `cash` or `bank_transfer`; `null`, a number or another letter case is 400. A client can't set `paymentDueAt`, because extra keys are refused.
- **Method and status:** only `cash` with `preparing` and `bank_transfer` with `awaiting_payment` can be created.
- **No leaks:** the 503 message is fixed and holds no bank values, and no request data is echoed back.
- **SQL:** all queries use placeholders, and the step 7 CHECK is valid.
- **Size:** the total is computed after validation, on at most 50 lines with 10 toppings each.
- **SSE:** the stream only gains the two new fields, neither of them sensitive.
- **Migration:** each step runs in its own transaction with rollback.

## Unverified (owner acceptance)

Run step 8 against a copy of the real `orders.db`: the row count stays the same, and old `pending` orders show as `preparing`.

## Re-review 1

First round: failed with 1 P1. Fix round 1 refuses a PATCH that moves a `bank_transfer` order out of `cancelled` (409 "Use the payment routes"), and clears `payment_due_at` only when cancelling an `awaiting_payment` order.

The re-review traced every sequence, and an unpaid transfer order can't reach `preparing`, `ready` or `delivered` through PATCH. That includes `awaiting_payment` → `cancelled` → `cancelled` → `preparing`, a direct `delivered`, and an expiry-cancelled row. No race (nothing is awaited between the lookup and the UPDATE). PATCH can't change `payment_method`. **P1 closed. Verdict: passed (P0 0, P1 0).**

Remaining by design: `cash` + `preparing` can be POSTed without payment (no login; the accepted risk until MENU-DB3). A paid transfer order that staff cancel by mistake can't be moved back by PATCH. That is fail-closed, and it is handed to `backend-order-payment-transitions`.

| Command (after fix round 1) | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` (executor) |
| `make backend-test` | 0 | `+453: All tests passed!` (executor) |
| `make format-check` | 0 | `0 changed` (executor) |
| `make analyze` | 0 | `No issues found!` (executor) |
| `make test` | 0 | `+343: All tests passed!` (executor) |
| `make boundaries` | 0 | `boundaries: ok` (executor) |
| `make check` | 0 | all gates green, backend +453, Flutter +343 (orchestrator, this session, final candidate) |
