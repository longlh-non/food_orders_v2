---
task: backend-order-payment-method
status: passed
p0: 0
p1: 0
---

# Execute review: backend-order-payment-method

Date: 2026-11-19. Reviewer: `code-reviewer` (independent, read-only, first pass). The security review is in `docs/reviews/security-backend-order-payment-method.md`. Its first round failed with one P1, so the card can't be archived until that review passes.

## Candidate

The `CLAUDE.md` contract changes, `backend/lib/orders_api.dart`, `backend/lib/database.dart` (steps 7 and 8), `backend/bin/server.dart`, the new `backend/test/orders_payment_test.dart`, and the older tests adapted (`orders_api_test.dart`, `menu_api_test.dart`, `orders_export_api_test.dart`: status names, schema version, extra columns).

## Gates (first round)

Run by the executor in this session.

| Command | Exit code | Output tail |
|---|---|---|
| `make backend-analyze` | 0 | `No issues found!` |
| `make backend-test` | 0 | `+449: All tests passed!` |
| `make format-check` | 0 | `Formatted 66 files (0 changed)` |
| `make analyze` | 0 | `No issues found!` |
| `make test` | 0 | `+343: All tests passed!` |
| `make boundaries` | 0 | `boundaries: ok` |

## Findings

P0: none. P1: none.

**What the reviewer confirmed:**

- `CLAUDE.md` matches the code: status codes, fixed messages, the status list, `paymentMethod` rules, and the step 7 and 8 bullets.
- The schema steps are new and run in transactions.
- The validation order is right (a 400 wins over the transfer 503).
- The total is computed correctly.
- The server clock is injected and the deadline is in UTC.
- The reply and the stream use the stored row.
- The adapted older tests still test what they did before.

P2 (the first four are fixed in the same batch as the security P1, see "Fix round 1"):

1. `orders_api.dart` PATCH: `payment_due_at` is cleared on every PATCH, not only on cancel. Any PATCH on an expiry-cancelled order would wipe the "cancelled by expiry" marker that staff "switch to cash" (PAY13, next card) depends on. **Fix:** clear it only when the target is `cancelled` and the order was `awaiting_payment`.
2. `CLAUDE.md`: "a browser tab opened before this change still posts `pending`" is misleading. Until the shared-model card lands, the current customer app sends `pending` and the restaurant app sends `accepted`, so both get 400. **Fix:** reword it to say so, and to say that the backend and the apps must be deployed together.
3. `orders_api.dart:108`: `paymentDueAt` has 6 fractional digits with the real clock and 3 in the tests. **Fix:** truncate it to milliseconds.
4. `orders_payment_test.dart:476-480`: the CSV comparison is built with the same function it tests. **Fix:** add one literal expected line.
5. When transfer is disabled, a transfer POST with an existing id answers 503 before 409. This is harmless. Deferred, not fixed.

**Other follow-ups noted:**

- The `CLAUDE.md` "Notifications" section still describes `pending` and Accept. That goes to `restaurant-orders-show-payment-method` and `docs-payment-and-reports`.
- The CSV totals (`orders_export.dart:161-187`) count every status except `cancelled`, so `awaiting_payment` counts as revenue. The new reports are delivered-only (`backend-report-data`). The CSV is unchanged by decision RPT5. Written down here only.

## Unverified (owner acceptance)

- The real `orders.db` upgrade from version 6 to 8.
- Behaviour behind Caddy or nginx.

## Fix round 1 and Re-review 1

Fixed in one batch:
- the security P1 (a `bank_transfer` order can't leave `cancelled` by PATCH, which answers 409);
- P2-1 (`payment_due_at` is cleared only when an `awaiting_payment` order is cancelled);
- P2-2 (`CLAUDE.md` now says both current apps send `pending`/`accepted` and get 400, so the backend and the apps are deployed together);
- P2-3 (`paymentDueAt` is cut to whole milliseconds);
- P2-4 (a literal CSV line in the export test).

Tests were added for each.

The re-review confirmed every fix and said none of them blocks the next card (its payment routes and expiry sweep don't go through PATCH). **Verdict: passed (P0 0, P1 0).** One new P2 was deferred to `backend-order-payment-transitions`, which edits the same table row: the `CLAUDE.md` API table PATCH 409 cell doesn't list "a `cancelled` `bank_transfer` order whose target isn't `cancelled`". The order rules already do.

| Command (final candidate) | Exit code | Output tail |
|---|---|---|
| `make check` | 0 | format-check `0 changed`, analyze clean, `boundaries: ok`, Flutter `+343: All tests passed!`, backend `+453: All tests passed!` (orchestrator, this session) |

Card moved to `docs/tasks/done/`.
