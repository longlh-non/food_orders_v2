---
executor: task-executor
scopes: [backend]
workKinds: [backend, quality-gate]
blockedBy: [qr-static-backend-payload, status-finished-backend]
securityReview: required
---

# Backend: schema step 10, placing a `bank_transfer_static` order, and the QR in `/payment-info`

Planned 2026-11-26, revised: **step 9 belongs to `status-finished-backend`** (SF4), so this card owns **step 10** and starts from a database at version 9. `staff-login-backend` (step 11) and `order-status-audit-log` (step 12) run **after** this card and start from version 10 and 11. Decisions QS1, QS2, QS3, QS14 in `qr-static-api-contract`. Security review is required: it changes `POST /orders` validation and a public route.

## Sources

`backend/lib/database.dart` (step 7 has `CHECK (payment_method IS NULL OR payment_method IN ('cash', 'bank_transfer'))`; SQLite can't change a CHECK, step 4 shows the rebuild pattern; step 9 is the status update from the other card), `backend/lib/orders_api.dart` (`paymentMethods`, `_orderProblem`, the POST handler, `/payment-info`), `backend/lib/shop_settings.dart`, `backend/lib/mock_orders_db.dart`, existing `orders_payment_*_test.dart` and `database_*` tests.

## Goal

1. **Schema step 10** (new numbered step, never edit step 7 or 9): rebuild `orders` (create new table, copy every row and its order, drop, rename) so `payment_method` accepts `'bank_transfer_static'`. Keep every other column, constraint (`status` has none) and the insertion order that "newest inserted first" depends on. Runs in a transaction; rolls back on failure. Update the step list in the code comment only; CLAUDE.md is `qr-static-docs`.
   - Fallback if the rebuild proves risky: stop and ask the owner (the alternative, hiding the method in `payment_due_at IS NULL`, is not recommended).
2. **POST /orders**: `paymentMethods` gains `bank_transfer_static`. It needs status `awaiting_payment` (400 otherwise), a total above 0 (400), and bank settings set (503 "Bank transfer is not set up"). The stored order gets `paymentDueAt: null`. Fixed error strings, never echoing input. Update the message "paymentMethod must be cash, bank_transfer or bank_transfer_static".
3. **GET /payment-info**: when transfer is enabled, add `staticQrPayload` built by `vietQrStaticPayload` from `BANK_BIN` and `BANK_ACCOUNT` (no reference, QS3). `no-store` as today; the disabled reply is unchanged.
4. Replies (`POST`, `GET /orders`, stream) carry the new method name as stored.
5. **Old transfer blocked (QS14):** `POST /orders` with `paymentMethod: bank_transfer` answers **503** "Bank transfer is suspended", decided by one named constant (checked after validation, before any insert). `bank_transfer_static` and `cash` are unaffected.
6. **The status `paid` (QS13)** needs **no** schema work (`orders.status` has no CHECK; confirm in `database.dart`). Add `paid` to `orderStatuses` and the `statusPaid` constant here, with the "keep in sync" comment. `POST /orders` never accepts `paid` (a new order is `preparing` or `awaiting_payment`). The PATCH rules for it are in `qr-static-backend-transitions`; until that card runs, PATCH to `paid` is refused for every method with 409 "That status doesn't fit this payment method".

## Non-goals

The transition routes and PATCH rules for the new method (`qr-static-backend-transitions`), reports, any Flutter code, the session table (step 11) and the audit table (step 12).

## Tests written with the change

- migration: a database at version 9 (run through step 9) with cash, transfer, awaiting, cancelled, finished and legacy NULL-method rows migrates to 10 with all rows, order and values intact; a second open does nothing; the new method can then be inserted and a bad value is still refused. A failure mid-step leaves version 9 and the old table. A database at version 8 migrates 8 -> 9 -> 10 in one open.
- POST: static with `awaiting_payment` -> 200, `paymentMethod` `bank_transfer_static`, `paymentDueAt` null; with `preparing` -> 400; with `paid` -> 400; total 0 -> 400; bank settings off -> 503 and nothing stored; a body with `paymentDueAt` still 400; `cash` unchanged.
- old transfer: `bank_transfer` -> 503 "Bank transfer is suspended" and nothing stored; with the constant flipped through the test seam the old POST works as before.
- `/payment-info`: enabled -> has `staticQrPayload` (contains `010211`, no tag 54, valid CRC) and the old fields; disabled -> `{"transferEnabled": false}` only.
- `mock_orders_db.dart` / seed tool still work after the rebuild.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make backend-test` (gate) |
| Gates | `make backend-analyze`, `make format-check` exit 0 |
| Step 10 never edits shipped steps, keeps all data | `code-reviewer`, `security-reviewer` (reviews) |
| Migration on a copy of the owner's real `orders.db` keeps every order | owner acceptance after a dated backup, "unverified" until done |

## Environment limits

The migration can't be undone: the owner makes a dated backup before the first start with the new steps (CLAUDE.md "Storage").
