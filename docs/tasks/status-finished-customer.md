---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [status-finished-shared, status-finished-backend]
---

# Customer: "ended" means `finished` or `cancelled` (banner, snackbar, payment page)

Planned 2026-11-26, small revision the same day (a cash order can now sit in `awaiting_payment` when staff move it there). Decisions SF2, SF8, SF9, SF16 in `status-finished-contract`.

## Sources

`lib/customer/pages/menu_page.dart` (the banner filter near line 151 and its doc comment at line 24, the status-change snackbar, which row opens the payment page), `lib/customer/pages/payment_qr_page.dart` (the `switch` near lines 360-370 that lists `preparing`, `ready`, `delivered`), `lib/customer/state/my_orders.dart`, `test/menu_page_test.dart`, `test/payment_qr_page_test.dart`, `test/customer_l10n_test.dart`.

## Goal

- Banner: an order is listed while it is not `finished` and not `cancelled` (plus the existing expired-transfer renew window rule, unchanged). Doc comment updated.
- Status snackbar: names the new state with `OrderStatus.localized` ("Đã phục vụ"); nothing else changes.
- Payment page: the "payment received / cash order" branch covers `preparing` and `finished` (no `ready`, no `delivered`).
- A customer never needs a "ready" state: an order goes `preparing` -> `finished` and the customer sees "Đã phục vụ" in the snackbar.
- **A cash order that staff moved to `awaiting_payment`** (SF16, recommendation A: the method stays `cash`): the banner lists it with the plain localized status label and it opens **no** payment page (only a transfer order does). No crash, no QR fetch, no switch-to-cash offer.

## Non-goals

The static payment page (qr-static), removing old enum values (cleanup card), any restaurant or backend file.

## Tests written with the change

- banner: a `finished` order disappears from the list; a `preparing` one stays; `cancelled` as before; a cash `awaiting_payment` order is listed and tapping it opens nothing.
- the snackbar text for `preparing` -> `finished` is the localized "Đã phục vụ" in `vi` and `en`.
- payment page: a `bank_transfer` order that becomes `preparing` shows the received view, and when it becomes `finished` it still shows it (no crash, no QR).
- existing expired / renew tests pass unchanged.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates | `make analyze`, `make format-check`, `make boundaries` (gates) |
| A stale customer tab that still sees `finished` does not crash (unknown statuses are skipped) | existing parser test plus `code-reviewer` (review) |
| The banner and snackbar read right on a real phone | owner acceptance, "unverified" until done |
