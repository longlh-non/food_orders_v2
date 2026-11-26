---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-customer-payment-page]
---

# Customer cart: switch the transfer choice to the QR without amount (old transfer suspended)

Planned 2026-11-26. Decisions QS5, QS12 in `qr-static-api-contract`. Runs **last of the customer cards** so the choice is only switched on once the page it leads to exists.

## Sources

`lib/customer/pages/cart_page.dart` (`_method`, `_transferEnabled`, `_paymentChoice`, the place-order function around lines 95-130 that sets status and method and hands over to `payment_qr_page.dart`), `test/cart_page_test.dart`.

## Goal

- `_paymentChoice` shows **two** `RadioListTile`s: cash and **"Chuyển khoản"**, which is now `bank_transfer_static`. The old `bank_transfer` choice is **not offered** (QS12: suspended, not deleted). Keep it behind one clearly named constant or small function in `cart_page.dart` (e.g. `_offerAmountQrTransfer = false`) so turning it back on is a one-line change (the backend blocks the old method too, QS14, so re-enabling needs both constants); do not delete the old page, routes or tests. The transfer choice keeps the existing "not enabled" subtitle and disabled state when `_transferEnabled != true` (`_method` falls back to cash as today).
- Placing a static order posts `paymentMethod: bank_transfer_static`, status `awaiting_payment`, then replaces the cart with the static payment page (`qr-static-customer-payment-page`).
- The failed-place message stays the existing one.

## Non-goals

The payment page, the download, anything restaurant-side.

## Tests written with the change (`cart_page_test.dart`, fake `PaymentClient`)

- enabled: two choices (cash, "Chuyển khoản"); picking transfer and ordering posts the right method and status (via the repository's test hook) and opens the static page.
- not enabled: the transfer choice disabled with the subtitle; a cash order still works.
- the choice returns to cash when the info says disabled.
- with the suspension switch on, the old choice is back (a test for the constant, so the old widget path stays covered).
- no overflow at 360 px and text scale 2.0 with two choices (existing overflow-test pattern).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Existing cash and transfer orders unchanged | existing tests stay green; `code-reviewer` (review) |
| Two choices readable on a real phone | owner acceptance, "unverified" until done |
