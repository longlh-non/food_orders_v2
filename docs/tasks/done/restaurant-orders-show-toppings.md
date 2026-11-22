---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-and-menu-models-toppings]
---

# Restaurant orders page: show the toppings on each order line

Runs after `vi-translate-shared-and-restaurant-ui` because both edit `lib/restaurant/pages/orders_page.dart`; there is no new English text (topping names are data).

## Why

The kitchen must see "1x Burger, + Bacon, + Extra cheese", otherwise the customer's choice is lost.

## Sources

`lib/restaurant/pages/orders_page.dart` (items rendered with `${item.quantity}x ${item.name}` and `item.subtotal`), `lib/shared/models/order.dart`.

## Goal

Under each item line, one smaller line listing its toppings (`+ name` each, comma or wrap), only when the item has any. The line subtotal shown already includes toppings (it uses `OrderItem.subtotal`). Everything else (chime, badge, SnackBar, status buttons) unchanged. Must not overflow at 360 px width with 4 toppings.

## Non-goals

Toppings on printed/other views, any backend or shared change, restaurant menu editing.

## Tests written with the change

Widget test in `test/`: pump `OrdersPage` with an order whose item has two toppings and one without; toppings text is found for the first and absent for the second; subtotal shows price plus toppings times quantity; long topping list at 360 px does not overflow; existing orders-page tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Toppings and correct subtotal shown, nothing for plain items | `make test` (widget test) |
| Restaurant imports nothing from customer | `make boundaries` (gate) |
| `make check` green | `make check` exit 0 (gate) |
| Place an order with toppings on `customer.local`, see it live on `restaurant.local` with its toppings; an old order without toppings still renders | owner acceptance in the real environment - "unverified" until done |
| Readable on the tablet/phone staff will use | owner acceptance on the device - optional |

## Environment limits

Agents cannot run the two-app flow in a browser; the owner does.

## Order change (owner, 2026-11-11): toppings before translation

The owner chose to let the toppings work go ahead of the Vietnamese translation, so VI1–VI3 no longer block it. Write any new user-facing text **in English**, the same as the rest of the app today. `vi-translate-shared-and-restaurant-ui` now comes *after* this card and translates that text.

## Decided 2026-11-11: currency is VND (CUR1 / VI3)

The owner chose **VNĐ** for the whole app. The display change is card `currency-vnd-display` (prices shown as `10.000 VNĐ`, whole numbers). VI3 is no longer an open question.

## Added by `currency-vnd-display` review (2026-11-11)

- **Layout (P2):** in `orders_page.dart` (around line 168), the order-line `Row` shows `Text('${item.quantity}× ${item.name}')` with no `Expanded` or `Flexible`, then a `Spacer` and `formatVnd(item.subtotal)`. A long name plus a long VND price (`1.250.000 VNĐ`) could overflow on a narrow screen. This card reworks that row for toppings anyway: wrap the name in `Expanded` with `overflow: TextOverflow.ellipsis`, and add a 360 px test.
- **Test seam (P2):** the restaurant page reads `OrderRepository.instance`, which tests can't fill without a network call, so no widget test proves the restaurant shows `… VNĐ`. This card needs to show toppings on orders, so it needs a seam anyway. Recommended: let `OrdersPage` take an optional repository, the same pattern as `MenuPage(state:)`. Then add the missing test: the subtotal and total show `VNĐ`, never `$`.

## Executor notes (2026-11-12)

- **Wrap, not ellipsis:** the item name and toppings wrap instead of being cut with "…", on purpose. This overrides the layout note above because the kitchen needs the whole text. The price stays on the right.
- **Test seam:** the tests use the existing `@visibleForTesting OrderRepository.setOrdersForTest` (from `customer-menu-category-tabs`) instead of a new `OrdersPage(repository:)` parameter, so this card doesn't change `lib/shared/`.
- **Text scale:** the 360 px fit test runs at text scale 1.0 and 1.3. Scale 2.0 is a follow-up in `docs/reviews/execute-restaurant-orders-show-toppings.md`.
