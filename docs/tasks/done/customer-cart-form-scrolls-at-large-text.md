---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: []
---

# Cart page: the name, total and button fit at large text sizes

Follow-up from the `customer-cart-place-order-shows-failure` review (2026-11-13).

## Why

`CartPage` lays out the lines in an `Expanded` list, with a bottom strip under it that doesn't scroll: the name field, then "Total" and "Place Order" in a `Row`, then the failure line when an order failed. On a 360 px wide phone at text scale 1.6 and above, the strip is taller than the screen. In the widget test it overflows at the bottom by 45 px at 1.6 and 220 px at 2.0 (the test font draws every letter 1 em wide, so real fonts are a bit kinder). Customers can set large text on their phones, so this needs fixing before real customers.

## Design (plain words, with the trade-off)

Recommended: make the whole body one scrollable list. The cart lines come first, then the name field, total, button and failure text. Nothing can overflow at any text size.

The trade-off: with many lines, the button is no longer pinned to the bottom; the customer scrolls down to it. For a cart of a few items, the difference is small.

The alternative is to keep the strip pinned and let only the strip scroll when it's too tall (`LayoutBuilder` + `ConstrainedBox`). That's more code for little gain. The executor uses the recommended layout unless the owner says otherwise.

## Sources

`lib/customer/pages/cart_page.dart`, `test/cart_page_test.dart` (the fit test currently runs at text scale 1.0 and 1.3 only, with a comment pointing here).

## Goal

1. No overflow at 360 px with text scale 1.0, 1.3, 1.6 and 2.0, with the failure line shown and with three cart lines.
2. The place-order behaviour from `customer-cart-place-order-shows-failure` is unchanged: sending state, success, failure, retry.
3. Extend the existing fit test to 1.6 and 2.0, and remove its pointer comment.

## Non-goals

Any change to how orders are placed, the menu page, or translation.

## Tests written with the change

The fit test runs at 1.0, 1.3, 1.6 and 2.0 with the failure line shown. The button can be scrolled to and tapped at 2.0. The existing cart tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No overflow at the four scales | `make test` (widget test) |
| Place-order behaviour unchanged | `make test` (existing tests) |
| `make check` green | `make check` exit 0 (gate) |
| On the iPhone with the largest text setting, the cart is usable | owner acceptance - "unverified" until done |
