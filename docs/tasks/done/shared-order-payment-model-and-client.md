---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [backend-order-payment-method, backend-order-payment-transitions]
securityReview: required
---

# Shared: `Order` payment fields, the new status list, and the switch/renew/confirm calls

Planned 2026-11-19, updated the same day with the owner's answers. **No open decisions block this card.** Second half of the contract change (invariant 3: table, backend, then the Flutter model and `OrderApiClient`). Run after the two backend payment cards.

## Owner decisions

- **PAY2, decided (owner, 2026-11-19):** "Get rid of 'pending' status, go straight to 'preparing' after finish the order."
- **PAY11, decided:** "yes migrate pending to preparing" (done by schema step 8 in `backend-order-payment-method`). **PAY12, decided:** "remove accepted". Both `pending` and `accepted` leave `OrderStatus`.
- **PAY6, decided:** orders without a payment method are `cash`.
- **PAY13, decided (owner, 2026-11-19):** "also after it was cancelled": `staffSwitchToCash` is valid for an `awaiting_payment` order and for an order cancelled by the 5-minute expiry, with no time limit. `confirmPayment` on a cancelled order is a 409.
- **PAY15, PAY14 and PAY16, decided (owner, 2026-11-19):** "a cancelled bank-transfer order will be asked to user that if they want to switch to cash or not, if yes, switch to cash, else, generate another QR code." Only for expiry-cancelled orders; the customer's switch and the renew both work only within 15 minutes after the expiry (the server decides; a 409 after that). The client just sends the calls and merges the replies.

## Why

Both apps read `Order` from the backend. Until the model knows `paymentMethod`, `paymentDueAt` and the new status list, an order with a status the app doesn't know fails `OrderStatus.values.byName` and is **skipped** by `OrderApiClient._parseOrder` (so deploy the backend card first, then this one, and expect old open tabs to hide transfer orders until reload).

## Sources

`lib/shared/models/order.dart`, `lib/shared/api/order_api_client.dart` (`_orderCall`, `updateStatus`), `lib/shared/api/order_repository.dart`, the backend cards `backend-order-payment-method` and `backend-order-payment-transitions` (the contract), `test/` for the existing order/client/repository tests.

## Goal

1. **Model (`order.dart`).**
   - `enum PaymentMethod { cash, bank_transfer }` with a label extension (`Tiền mặt`, `Chuyển khoản`), the same way `OrderStatusLabel` is kept separate from the enum.
   - `OrderStatus` becomes `awaiting_payment, preparing, ready, delivered, cancelled`: **`pending` and `accepted` are removed**. Update the labels, `OrderRepository.activeOrders`, and every test and widget that names the removed values (`grep` for `OrderStatus.pending` and `accepted`). The customer cart and the restaurant page are properly changed by their own cards, but this card must leave `make analyze` and `make test` green, so the smallest compile fixes there are allowed. The new status's label is in the same language as its neighbours (executor notes list it for the translation cards).
   - Reading an unknown status (a stored `pending` that was not migrated) still makes that one order unreadable and it is skipped, like any malformed order.
   - `Order` gets `paymentMethod` (default `cash`) and `DateTime? paymentDueAt`. `toJson` writes `paymentMethod` and **never** `paymentDueAt` (the server owns it; an unknown field is a 400). `fromJson` reads both; a missing `paymentMethod` is `cash`, a bad value throws `FormatException` (that order is skipped); `paymentDueAt` is parsed as UTC or null. `copyWith` can carry the new fields.
   - Getters used by both apps (one definition each): `bool get expiredUnpaid` = status `cancelled`, method `bank_transfer` and `paymentDueAt != null` (the "cancelled by expiry" mark); `DateTime? get renewableUntil` = `paymentDueAt + 15 minutes` when `expiredUnpaid`, else null (for display only; the server decides).
   - `Order.total` unchanged.
2. **Client (`OrderApiClient`).**
   - `Future<Order> switchToCash(String id)` -> `POST /api/orders/{id}/switch-to-cash` (customer; the server also accepts an expired order within 15 minutes).
   - `Future<Order> renewPayment(String id)` -> `POST /api/orders/{id}/renew-payment` (customer, no body).
   - `Future<Order> staffSwitchToCash(String id, {required Map<String, String> staffHeaders})` -> `POST /api/orders/{id}/staff-switch-to-cash` (staff).
   - `Future<Order> confirmPayment(String id, {required Map<String, String> staffHeaders})` -> `POST /api/orders/{id}/confirm-payment` (staff).
   - All reuse `_orderCall`, so failures are one `OrderRequestException` with the status code (404, 409 for "too late or wrong state", 503 for transfer not set up). The staff headers are passed per call and used only as request headers; the shared code never stores, logs or formats them (the restaurant app owns `StaffCredentials`, which shared code must not import).
   - The id is `Uri.encodeComponent`-ed like `updateStatus`.
3. **Repository (`OrderRepository`).**
   - `switchToCash(id)`, `renewPayment(id)`, `staffSwitchToCash(id, {staffHeaders})` and `confirmPayment(id, {staffHeaders})`: call the client, then merge the returned order (as `updateStatus` does). Cache unchanged on failure. A merge may move an order from `cancelled` back to `preparing` (cash) or to `awaiting_payment` (renewed); nothing in the repository forbids that.
4. Nothing else changes: `placeOrder` already sends `order.toJson()`, which now carries the method.

## Non-goals

Any UI, the QR or payment-info calls (customer-only, card `customer-payment-client`), a staff-credentials type in shared code, status-flow changes in the restaurant app beyond the compile fixes above.

## Tests written with the change

- `Order.fromJson`: old JSON without the new keys -> `cash`, `paymentDueAt` null; with `bank_transfer` and a UTC time; a bad method (`card`, number) throws; `awaiting_payment` parses; `pending` and `accepted` no longer parse; `toJson` has `paymentMethod` and no `paymentDueAt`; round trip.
- `expiredUnpaid`: true only for `cancelled` + `bank_transfer` + a set `paymentDueAt`; false for a cancelled cash order, a cancelled transfer order without `paymentDueAt`, and every other status. `renewableUntil` is `paymentDueAt + 15 min` for an expired order and null otherwise.
- `OrderStatusLabel` and the payment label cover every enum value (a `switch` without `default` keeps this honest).
- Client (`MockClient`): `switchToCash` sends `POST /api/orders/abc/switch-to-cash`, `renewPayment` sends `POST /api/orders/abc/renew-payment`, both parse the reply; 409 -> `OrderRequestException(statusCode: 409)` and 503 -> `statusCode: 503`; `staffSwitchToCash` and `confirmPayment` send exactly the given headers to their paths; an id with `/`, `?`, `%` is encoded; a reply with an unknown status is the usual "invalid order" error; the staff header values never appear in an exception message or `toString`.
- Repository: success merges and notifies (also `cancelled` -> `preparing` cash, and `cancelled` -> `awaiting_payment` for a renewal); failure leaves the cache and does not notify.
- `placeOrder` sends `paymentMethod` in the body and never `paymentDueAt`.
- Existing shared and widget tests still pass (rewritten where they used `pending` or `accepted`).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing, serialising, client calls and repository merges as listed | `make test` (gate) |
| Formatting, analysis, boundaries (shared imports no app code) | `make format-check`, `make analyze`, `make boundaries` (gates) |
| No staff value stored or logged in shared code; unknown/old JSON handled | `security-reviewer`, `code-reviewer` (reviews) |
| No new dependency | `pubspec.yaml` unchanged (review) |
| `make check` green | `make check` exit 0 (gate) |
