---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [customer-payment-client, customer-cart-form-scrolls-at-large-text]
---

# Customer: pick Tiền mặt or Chuyển khoản in the cart, and place the order with it

Planned 2026-11-19, updated the same day. PAY2 is decided (see below), so nothing blocks this card except its predecessors. Blocked by `customer-cart-form-scrolls-at-large-text` because both rewrite the bottom of `cart_page.dart`; that card makes the whole body one scrolling list, which this card then adds a control to. This card does everything up to **placing** the order. The QR screen is the next card (`customer-payment-qr-page`); until it lands, a transfer order is placed but nothing shows the code, so the two cards ship together (the owner should not deploy this one alone).

## Owner decisions (verbatim, 2026-11-19)

> Add payment method to each order. Customer picks Tiền mặt/Chuyển khoản.

- **PAY2, decided:** "Get rid of 'pending' status, go straight to 'preparing' after finish the order." The app no longer creates `pending`: a cash order is placed as `preparing`.

## Sources

`lib/customer/pages/cart_page.dart` (`_placeOrder`, the bottom strip; it currently creates `OrderStatus.pending`), `lib/customer/state/my_orders.dart`, `lib/customer/api/payment_client.dart` (from the previous card), `lib/shared/models/order.dart` (`PaymentMethod`, `OrderStatus.awaiting_payment`), `test/cart_page_test.dart`.

## Design (plain words, with the trade-off)

- Two choices above "Place Order", as a `SegmentedButton` or two `RadioListTile`s: **Tiền mặt** and **Chuyển khoản**. Default **Tiền mặt**, so the common case is unchanged and nobody pays by transfer by accident. (Alternative: no default, the customer must pick. One more tap for everyone; rejected.)
- The choice lives in the page's state (`StatefulWidget`, like the name field); no new singleton.
- "Chuyển khoản" is **disabled** (with a short reason, e.g. "Chuyển khoản chưa được bật") when `PaymentClient.fetchInfo()` says `transferEnabled: false` or the call failed. The check runs once when the page opens; a failure never blocks cash.
- Placing the order:
  - **Tiền mặt:** `Order(status: preparing, paymentMethod: cash)`. Everything after is as today: wait for the server, then track the id, clear the cart, snackbar, close.
  - **Chuyển khoản:** `Order(status: awaiting_payment, paymentMethod: bank_transfer)`. After the server accepts it: track the id and clear the cart as for cash, then **open the QR page** for that order (next card) instead of just popping. A 503 (transfer turned off since the page opened) shows the same short failure text as other failures and keeps the cart.
- The failure text, the "enter your name" check, the spinner and the double-tap guard stay as they are.
- New strings are Vietnamese (the owner's own words for this feature); list them in the executor notes for the `vi-translate-customer-ui` card, which must leave them as they are.

## Goal

The control, the two order shapes, the transfer-disabled state, and the hand-over to the QR page (a stub route is fine until the next card lands; the two ship together). Fits at 360 px and text scale 1.0 to 2.0 (the scrolling list from the blocking card).

## Non-goals

The QR page, countdown, switch button, restaurant changes, a saved preference for the method.

## Tests written with the change

In `test/cart_page_test.dart` (fake `PaymentClient` and the repository's test API hook; tests that expected `pending` now expect `preparing`):
- default is Tiền mặt; placing sends `paymentMethod: cash` and status `preparing`; nothing else about the cash path changed (success, failure, retry, name check).
- Choosing Chuyển khoản and placing sends `bank_transfer` + `awaiting_payment`, tracks the id, clears the cart, and navigates to the QR route with that order's id.
- `transferEnabled: false` and a failed info call both disable the transfer choice with the reason, and cash still works.
- A 503 on a transfer order keeps the cart and shows the failure text.
- No overflow at 360 px for text scales 1.0, 1.3, 1.6, 2.0 with the choice shown.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Format, analysis, boundaries | `make format-check`, `make analyze`, `make boundaries` (gates) |
| No new dependency; cash path unchanged except the status; no `pending` left | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| On a phone at `http://customer.local`: both choices work, cash places an order the restaurant sees as being prepared | owner acceptance - "unverified" until done |

## Follow-ups carried in (from `docs/reviews/execute-customer-cart-form-scrolls-at-large-text.md`, P2)

- The failure line is the last item in the cart list, under the button, so at large text a customer may not see it after tapping. Put it above the button, or scroll it into view after a failure (`Scrollable.ensureVisible`). Add a test that finds it without a manual scroll.
- Add a test that a typed name survives scrolling the field off-screen and back.

## Carried in from `docs/reviews/execute-shared-order-payment-model-and-client.md` (P2)

- Add a cart test that checks the posted body: `status` and `paymentMethod` match the choice (`preparing`+`cash`, `awaiting_payment`+`bank_transfer`), and there is no `paymentDueAt`.
