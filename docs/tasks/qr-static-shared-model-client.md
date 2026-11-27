---
executor: task-executor
scopes: [shared, customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-backend-schema-and-create, qr-static-l10n-strings, status-finished-shared-cleanup]
securityReview: required
---

# Flutter data layer: `PaymentMethod.bank_transfer_static`, `OrderStatus.paid` and `staticQrImage`

Planned 2026-11-26, revised: it waits for `status-finished-shared-cleanup` so the list of exhaustive `OrderStatus` switches is final (no `ready` / `delivered` left). Revised again for the owner's image-QR design change (2026-11-26): `PaymentInfo` carries `staticQrImage` (a picture file name), not a QR payload. Security review is required: it parses new JSON from the server.

## Sources

`lib/shared/models/order.dart` (`PaymentMethod`, `OrderStatus`, `Order.expiredUnpaid`, `_readPaymentMethod`, the Vietnamese label extensions), `lib/shared/localized_labels.dart`, `lib/customer/api/payment_client.dart` (`fetchInfo`, `PaymentInfo`), `lib/shared/api/order_api_client.dart` (`imageUrlFor`) and `order_repository.dart` (switchToCash, confirmPayment, the staff-header `updateStatus` from `status-finished-shared`), tests under `test/` for the model and the client.

## Goal

- `enum PaymentMethod { cash, bank_transfer, bank_transfer_static }`; `Order.fromJson` accepts the new name; `toJson` sends it. Add `isTransfer`-style helpers **only if** two or more call sites need them (invariant 6); `expiredUnpaid` and `renewableUntil` stay `bank_transfer` only (a static order has no deadline).
- **`OrderStatus.paid`** (QS13): add it (JSON name `paid`; keep the backend list and this enum in sync by hand) to the enum, `OrderStatus.localized` (key `statusPaid` from the l10n card) and every exhaustive `switch` on `OrderStatus` in `lib/` (the executor lists them; the restaurant and customer cards decide how each screen shows it). The enum is then `awaiting_payment, preparing, paid, finished, cancelled`.
- Fix every exhaustive `switch` on `PaymentMethod`: `PaymentMethodLabel.label` and `PaymentMethod.localized(l10n)`.
- `PaymentInfo` gains **`String? staticQrImage`** (the picture file name; present only when the server has the static QR set up; absent or JSON `null` is null; a non-string value, or a string that does not match the picture-name rule `^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$`, is a `FormatException` or null: pick one and test it, preferring null so the page shows its info-failure state instead of crashing; the client must never put an unchecked string into a URL). It is independent of `transferEnabled`: `PaymentInfo` must parse a reply that has `transferEnabled: false` and a `staticQrImage`. The bank fields stay for the old transfer. `PaymentClient` is the customer's own file; nothing moves into `shared/`. The image URL is built by the callers with `OrderApiClient.imageUrlFor`, not here.
- `OrderRepository`/`OrderApiClient`: no new routes; the existing `switchToCash` and `confirmPayment` already hit the routes the backend widened. Confirm they don't pre-check the method locally; if they do, widen the check.

## Non-goals

Screens (next cards). A new state class. Any QR drawing or download code.

## Tests written with the change

- model: parse and serialise `bank_transfer_static`; an unknown method still throws; a static order has `paymentDueAt` null, `expiredUnpaid` false, `renewableUntil` null even when `cancelled`.
- status: JSON round trip of `paid`; an unknown status is still skipped.
- labels: all three methods and `paid` have a localized label in `vi` and `en`.
- `PaymentClient.fetchInfo`: image present with `transferEnabled` false -> name kept; image present with the old fields; image absent (older server or not set up) -> null; JSON `null` -> null; a number, a list, a name with `/`, `..`, spaces, capitals or a bad extension -> handled safely as decided above; old-transfer-only reply unchanged.
- repository: a live update changing a static order from `awaiting_payment` to `paid` is merged and notifies once.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, no import-boundary break | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Parsing is strict and never trusts the field type or lets a bad name reach a URL | `security-reviewer` (review) |
| Backend and app agree on the method, status and `staticQrImage` names | `code-reviewer` compares with `orders_api.dart` (review) |
