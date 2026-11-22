---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-calls-report-failure]
---

# Cart page: wait for the server and show failure

## Why

Today `CartPage._placeOrder` tracks the order id, calls `OrderRepository.instance.placeOrder(order)` without awaiting it, clears the cart and the name, shows "Order placed, <name>!" and pops. So even when the server rejects the order (400, backend down), the customer sees success and loses the cart. Found 2026-11-12 (see `shared-order-calls-report-failure` for the cause).

## Sources

`lib/customer/pages/cart_page.dart` (`_placeOrder`, the `FilledButton`), `lib/customer/state/my_orders.dart`, `lib/customer/state/cart.dart`, `test/cart_page_test.dart`, the seam and `OrderRequestException` from `shared-order-calls-report-failure`.

## Goal

`_placeOrder` becomes async:

1. Validation as today (empty name shows the SnackBar and returns; empty cart returns).
2. Set a `_sending` flag with `setState`. While true the "Place Order" button is disabled (`onPressed: null`) and shows a small progress indicator instead of the label. This is also the double-tap protection; no extra id or lock.
3. `await OrderRepository.instance.placeOrder(order)` inside `try`, catching `OrderRequestException` only.
4. On success: `MyOrders.instance.track(order.id)`, `cart.clear()`, clear the name, show 'Order placed, <name>!', pop. Check `mounted` after the await before using `context`.
5. On failure: keep the cart and the name, do not track the id, show the fixed SnackBar 'Couldn't place your order. Try again.' (never the exception text), clear `_sending`, stay on the page. Check `mounted`.
6. The order is built once per tap. A retry builds a new order with a new id (the failed one never reached the server, or was rejected).

Decision recorded: track the id **after** success. Tracking first would put a never-created order in the "Your orders" banner and could fire status SnackBars for it. The tiny gap between the server answering and `track` is harmless: `MyOrders` only reads ids when SSE events arrive, and the repository merge already happened, so the first event is for an already-merged order. If the executor finds that the banner misses the very first status change in a test, say so in the review; do not move `track` back before the call without asking.

## Non-goals

No retry button inside the SnackBar, no offline queue, no error details, no change to the restaurant app, no translation (the translate cards handle it, see below), no change to `Cart` or `MyOrders` APIs.

## Tests written with the change

In `test/cart_page_test.dart`, using the seam and a `MockClient`:
- Success (200 with the order echoed): the cart is empty afterwards, the id is tracked, the success SnackBar shows, the page pops.
- Failure with 400, with 500, and with a thrown `ClientException`: the cart and the typed name are still there, the id is not tracked, the failure SnackBar shows, the page is still on screen, the button is enabled again.
- While the request is pending (use a `Completer`): the button is disabled and shows progress; a second tap sends nothing (the mock counts one request).
- Reset the singletons (`Cart`, `MyOrders`, the repository seam) in `tearDown`.
- Existing tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Success and failure paths behave as above | `make test` (widget tests) |
| No `context` use after an await without `mounted` check | `code-reviewer` (review) |
| Only `lib/customer/` touched; no import of restaurant | `make boundaries` |
| `make check` green | `make check` exit 0 (gate) |
| With the backend stopped, placing an order shows the error and keeps the cart | owner acceptance at `http://customer.local` - "unverified" until done |
| With the backend running (restarted after the toppings change), the order appears live on `http://restaurant.local` | owner acceptance - "unverified" until done |

## Environment limits

The owner must restart the backend first (`cd backend && dart run bin/server.dart`); the old process rejects items that carry `id` or `toppings`. Agents cannot drive the browser.

## Interaction with other cards

This card is meant to run before `vi-translate-customer-ui`, so it writes the new text in English. The translate card has a note to translate 'Couldn't place your order. Try again.' and the sending state. If the translate card is already done when this one starts, write the new text in Vietnamese directly and have the owner approve the wording. `comments-customer` documents `cart_page.dart`; running it later avoids a redo.

## Executor note (2026-11-13): failure shown inline, not as a SnackBar

The failure message "Couldn't place your order. Try again." is shown as red text under the total, not as a SnackBar. The retry widget test found that the SnackBar covers the "Place Order" button, so the customer couldn't tap it again for about 4 seconds. The text clears when the next try starts. The wording is unchanged, and the success SnackBar is unchanged.
