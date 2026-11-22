---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [vi-translate-shared-and-restaurant-ui, customer-menu-page-uses-backend-menu, customer-menu-topping-and-drink-sheet]
---

# Vietnamese UI text: customer app

## Why

Second half of the Vietnamese translation (see `vi-translate-shared-and-restaurant-ui`). Blocked by `customer-menu-page-uses-backend-menu` because that card rewrites `menu_page.dart` and adds new strings (loading error, Retry, "Menu is empty"). Translating after it avoids merge conflicts and covers those new strings. `test/widget_test.dart` is also edited by the first card, hence the second blocker.

## Sources

`lib/customer/pages/menu_page.dart` ("Menu" title, "Your orders" banner, "Order #...: status" SnackBar, "Added <item>", "Add", plus the loading/error/Retry/empty text added by the menu card), `lib/customer/pages/cart_page.dart` (about 8 strings: "Your Cart", "Your cart is empty.", "Your name", "Please enter your name", "Order placed, <name>!", "Total:", "Place Order"), `lib/customer/main.dart` (app `title`), `test/widget_test.dart` (`find.text('Menu')`).

## Goal

Every user-visible English string in those files becomes Vietnamese (about 15 strings, wording drafted by the agent, accepted by the owner). Status text already comes from `OrderStatus.label` (done in the previous card). Menu item names and descriptions are data from the backend and are not changed here (VI5).

## Non-goals

No localization package, no toggle, no `$` to VND change (VI3), no date formatting, no menu data, no restaurant files, no `lib/dev/demo.dart`.

## Tests written with the change

- Update `test/widget_test.dart` customer test to the Vietnamese title.
- Widget test for `CartPage`: empty cart shows the Vietnamese empty text; with an item and empty name, tapping place order shows the Vietnamese "enter your name" SnackBar.
- Widget test for `MenuPage`: Add button label and "Added" SnackBar appear in Vietnamese (use the fake menu state the menu card introduced).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No English UI text left in the listed files | `code-reviewer` (review) |
| Cart and menu show Vietnamese in widget tests | `make test` |
| Boundaries intact, no new dependency | `make boundaries` + `pubspec.yaml` unchanged (review) |
| `make check` green | `make check` exit 0 (gate) |
| Wording is natural, diacritics render, banner and SnackBars read well | owner acceptance in the browser at `http://customer.local` - "unverified" until done |
| Same on iPhone Safari | owner acceptance on the phone - optional |

## Environment limits

Agents cannot see the browser; the owner approves the Vietnamese.

## Order change (owner, 2026-11-11): runs after the toppings work

The owner let the toppings work go first, so this card now also waits for `customer-menu-topping-and-drink-sheet`. That card and `customer-state-cart-lines-and-toppings` add English text this card must translate: the add dialog ("Add <dish>", "Extra toppings", "A drink", Cancel, Add), the toppings and drink pickers, and the topping lines in the cart. Inventory the strings again when this card starts.

## Decided 2026-11-11: currency is VND (CUR1 / VI3)

The owner chose **VNĐ** for the whole app. The display change is card `currency-vnd-display` (prices shown as `10.000 VNĐ`, whole numbers). VI3 is no longer an open question.

## Added 2026-11-12: order failure text

If `customer-cart-place-order-shows-failure` is done before this card, also translate its new text in `cart_page.dart`: the failure SnackBar 'Couldn't place your order. Try again.' and anything shown on the button while sending (add a widget-test assertion for the Vietnamese failure message). Inventory the strings again when this card starts.

## Added 2026-11-17: UI refresh strings (tiles, tabs, bottom bar)

The three UI-refresh cards add English text this card must translate: `customer-menu-tile-redesign` (the "+" tooltip "Add <name>", also its test finders), `customer-bottom-nav-cart-button` (the cart button tooltip "Cart", or "Cart, N items"). `customer-menu-category-icon-tabs` adds no text (labels are already Vietnamese). Those cards also remove the old "Add" tile button and the AppBar cart icon, so the "Add button label" test line above becomes "the '+' tooltip" and tests find it with `find.byTooltip(...)`. Recommended order: run the three refresh cards first (they all rewrite `menu_page.dart`), then this card, so there is one inventory. The dialog's own "Add" confirm button is unchanged by them and is still translated here. If this card runs first instead, the refresh cards must write their new strings in Vietnamese directly.

## Added 2026-11-19: dialog label changed by the owner

The owner renamed the add-food dialog's checkbox from "A drink" to **"Add drinks"** (`lib/customer/pages/add_food_dialog.dart`). Translate the new text. The drink step's title is still "A drink"; translate that too.
