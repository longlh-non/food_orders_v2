---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-shop-settings]
securityReview: required
---

# Backend: a payment method on every order (`cash` / `bank_transfer`), status list without `pending` and `accepted`, schema steps 7 and 8

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.** Contract-first: it changes the `CLAUDE.md` API table and order rules (needs the owner's explicit approval for this card), then the backend. The shared model and `OrderApiClient` follow in `shared-order-payment-model-and-client` (invariant 3: table, backend, client).

## Owner decisions (verbatim)

> Add payment method to each order. Customer picks Tiền mặt/Chuyển khoản. ... After finishing the order: if the user transferred { order_status = preparing; payment_type = bank_transfer } else { order_status = preparing; payment_type = cash }. When printing: if payment_type == bank_transfer put into "Chuyển khoản" column; if payment_type == cash put into "Tiền mặt" column.

- **PAY2, decided (owner, 2026-11-19):** "Get rid of 'pending' status, go straight to 'preparing' after finish the order." A cash order is created `preparing`; a transfer order is created `awaiting_payment` and becomes `preparing` when staff confirm. The status list becomes `awaiting_payment, preparing, ready, delivered, cancelled`.
- **PAY9, confirmed (owner, 2026-11-19):** the client still sends `status`, and the server **checks the method and status combination** (below). The server sets the payment deadline itself.
- **PAY6, decided (owner, 2026-11-19):** "Old orders with no paymeny method count as cash." Read back as `cash` and reported as cash. The column stays NULL in the database, so nothing is rewritten.
- **PAY11, decided (owner, 2026-11-19):** "yes migrate pending to preparing". A schema step turns stored `pending` orders into `preparing`. The step can't be undone, so the owner makes a dated backup first. Side effect to expect: an old `pending` order nobody ever touched now shows in the kitchen as "preparing", and the owner moves it to delivered or cancelled by hand.
- **PAY12, decided (owner, 2026-11-19):** "remove accepted". `accepted` is removed everywhere (backend list, `OrderStatus`, `CLAUDE.md`, apps); stored `accepted` rows migrate to `preparing` in the same step as `pending`.

## Sources

`backend/lib/orders_api.dart` (`_orderProblem`, `_orderFromRow`, POST and PATCH routes, `orderStatuses`), `backend/lib/database.dart` (steps, `PRAGMA user_version`), `backend/lib/shop_settings.dart` (`transferEnabled`), `backend/test/orders_api_test.dart` (many tests post `pending`; they are updated), `CLAUDE.md` -> "Backend" (API table, Order rules, Storage).

## Goal (contract)

Order JSON gains two fields. Update the `CLAUDE.md` table, "Order rules" and the status list (also in `lib/shared/models/order.dart`, done by the next card) **first**:

- `paymentMethod`: `"cash"` or `"bank_transfer"`.
  - POST: **optional**. Absent means `cash`.
  - GET, SSE and the POST/PATCH replies: **always present**; a stored NULL is read back as `"cash"` (PAY6).
- `paymentDueAt`: ISO-8601 UTC string (`2026-11-19T08:05:00.000Z`) or `null`. **Never accepted on POST** (an unknown field is a 400 as today). The server sets it for a new `bank_transfer` order to its own clock plus `paymentWindow` (a constant, 5 minutes), and keeps `null` for cash. Meaning later: a `cancelled` order that still has `paymentDueAt` was **cancelled by the 5-minute expiry** (see "PATCH" for why a staff cancel never leaves it set).
- Statuses: `orderStatuses` becomes `awaiting_payment, preparing, ready, delivered, cancelled` (and the sentence in `CLAUDE.md` "kept in sync by hand with `OrderStatus`" is updated).

### POST rules (added to the existing ones; PAY9)

- `paymentMethod`, if present, must be exactly `cash` or `bank_transfer`; anything else is 400.
- **`cash` (or no method) requires status `preparing`.** `bank_transfer` requires status `awaiting_payment`. Any other combination is 400.
- `bank_transfer` also requires: the order total (sum of `quantity x (price + toppings)`) is greater than 0, and `ShopSettings.transferEnabled`. A disabled bank setup answers **503** "Bank transfer is not set up", the total check answers 400.
- Consequence to note in `CLAUDE.md`: a customer browser tab opened before this change still posts `pending`; it gets a 400 and the customer sees the usual "couldn't place your order" until they reload the page.
- The reply and the SSE event are the **stored** order (with `paymentMethod` and `paymentDueAt`), not a plain echo.

### PATCH `/orders/{id}` (status only, as today)

- An order that is `awaiting_payment` can only be PATCHed to `cancelled`; any other target is **409** "Use the payment routes". Payment goes through the routes of the next card, so a status button can't skip the payment step.
- That staff `cancelled` **clears `paymentDueAt`** (sets it to null), so only an expiry cancel keeps it. This is what lets the next card allow "switch to cash" on expired orders only (owner, PAY13) and not on orders staff cancelled on purpose.
- PATCHing **to** `awaiting_payment` is 409 (that status exists only through POST).
- Nothing else about PATCH changes.

### Storage

- Schema **step 7** (a new step, never edit a shipped one): `ALTER TABLE orders ADD COLUMN payment_method TEXT CHECK (payment_method IS NULL OR payment_method IN ('cash','bank_transfer'))` and `ALTER TABLE orders ADD COLUMN payment_due_at TEXT`. Existing rows get NULL in both.
- Schema **step 8** (PAY11, PAY12): `UPDATE orders SET status = 'preparing' WHERE status IN ('pending', 'accepted')`, in its own transaction like every step.
- Add "Step 7" and "Step 8" bullets to the backup list in `CLAUDE.md` (stop the backend and make a dated backup first; step 8 cannot be undone).
- `_orderFromRow` returns the two new keys. The `GET /orders/export` CSV must stay **byte-identical** apart from the migrated status words (its row builder ignores the new keys).

## Non-goals

Switching to cash, confirming payment, expiry (card `backend-order-payment-transitions`); the QR (card `backend-payment-qr-endpoint`); any Flutter code; the reports.

## Tests written with the change

In `backend/test/orders_api_test.dart` (or a new `orders_payment_test.dart`); existing tests that post `pending` or `accepted` are changed to `preparing`:
- POST `cash` + `preparing` and POST with no method + `preparing` -> 200, reply has `paymentMethod: "cash"`, `paymentDueAt: null`.
- POST `bank_transfer` + `awaiting_payment` -> 200, `paymentDueAt` equals the injected server clock + 5 minutes (inject a `now` function, as `StaffGate` does).
- POST with `paymentDueAt` in the body -> 400. `paymentMethod: "card"`, `5`, `null` -> 400.
- `cash` + `awaiting_payment`; `bank_transfer` + `preparing`; any order with `pending` or `accepted`; `bank_transfer` with total 0 -> 400. `bank_transfer` with bank settings disabled -> 503 and nothing stored.
- GET `/orders` and the SSE event carry both fields; an order stored by the old code (insert without the columns) reads back `cash` / `null`.
- Migration: a database at version 6 with `pending`, `accepted`, `preparing`, `delivered` and `cancelled` orders upgrades to 8, keeps every row, turns only the first two into `preparing`; a fresh database reaches 8.
- PATCH: `awaiting_payment` -> `cancelled` is 200 and the reply has `paymentDueAt: null`; `awaiting_payment` -> `preparing` is 409; `preparing` -> `awaiting_payment` is 409; `preparing` -> `ready` -> `delivered` as before.
- The CSV export of a mixed set equals the previous output (golden string built in the test).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour and status codes as listed | `make backend-test` (gate) |
| Backend clean; no new dependency | `make backend-analyze` (gate) |
| New field and status validated before use; no request data echoed in errors; a client can't set `paymentDueAt`; PATCH can't skip payment | `security-reviewer` (review; POST/JSON parsing trigger) |
| `CLAUDE.md` table, Order rules, status list and Step 7 / 8 bullets match the code | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| After a backup, the real backend starts, upgrades to step 8, and old orders still show | owner acceptance - "unverified" until done |

## Environment limits

Run against in-memory databases only. The owner upgrades his real `orders.db` after a dated backup.
