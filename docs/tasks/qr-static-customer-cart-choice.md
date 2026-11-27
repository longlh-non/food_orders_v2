---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [qr-static-customer-payment-page]
---

# Customer cart: switch the transfer choice to the owner's QR image (old transfer suspended)

Planned 2026-11-26, revised for the owner's image-QR design change (2026-11-26): the transfer choice is enabled by **`staticQrImage` being present** in `GET /payment-info`, not by `transferEnabled` or the `BANK_*` settings. Decisions QS5, QS12 in `qr-static-api-contract`. Runs **last of the customer cards** so the choice is only switched on once the page it leads to exists. It reads `PaymentInfo.staticQrImage` from `qr-static-shared-model-client` (already done before the payment page).

## Sources

`lib/customer/pages/cart_page.dart` (`_method`, `_transferEnabled`, `_paymentChoice`, the place-order function around lines 95-130 that sets status and method and hands over to `payment_qr_page.dart`), `lib/customer/api/payment_client.dart`, `test/cart_page_test.dart`.

## Goal

- `_paymentChoice` shows **two** `RadioListTile`s: cash and **"Chuyển khoản"**, which is now `bank_transfer_static`. The old `bank_transfer` choice is **not offered** (QS12: suspended, not deleted). Keep it behind one clearly named constant or small function in `cart_page.dart` (e.g. `_offerAmountQrTransfer = false`) so turning it back on is a one-line change (the backend blocks the old method too, QS14, so re-enabling needs both constants); do not delete the old page, routes or tests.
- **The new choice is enabled when the info has a non-empty `staticQrImage`** (rename the flag to something like `_staticQrReady`). When it is absent or the info fetch fails, the choice shows the existing "not enabled" subtitle and is disabled (`_method` falls back to cash as today). The **old** transfer choice, when the suspension constant brings it back, keeps its own `transferEnabled` flag unchanged.
- Placing a static order posts `paymentMethod: bank_transfer_static`, status `awaiting_payment`, then replaces the cart with the static payment page (`qr-static-customer-payment-page`).
- The failed-place message stays the existing one (a 503 "Static QR transfer is not set up" from a stale cart uses it too).

## Non-goals

The payment page, the download, anything restaurant-side, the backend.

## Tests written with the change (`cart_page_test.dart`, fake `PaymentClient`)

- enabled (`staticQrImage` set, `transferEnabled` false): two choices (cash, "Chuyển khoản"); picking transfer and ordering posts the right method and status (via the repository's test hook) and opens the static page.
- not enabled (`staticQrImage` absent, also with `transferEnabled` true): the transfer choice disabled with the subtitle; a cash order still works.
- the choice returns to cash when the info loses the image or the fetch fails.
- with the suspension switch on, the old choice is back and still follows `transferEnabled` (a test for the constant, so the old widget path stays covered).
- no overflow at 360 px and text scale 2.0 with two choices (existing overflow-test pattern).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Existing cash and transfer orders unchanged | existing tests stay green; `code-reviewer` (review) |
| Two choices readable on a real phone | owner acceptance, "unverified" until done |
