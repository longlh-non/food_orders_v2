---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [shared-order-and-menu-models-toppings, customer-menu-page-uses-backend-menu]
---

# Customer state: cart lines with toppings, and the menu state loads toppings

No new screen. The Add button on the grid still adds a plain dish; this card makes the state and the cart page ready for toppings. Runs after `vi-translate-customer-ui` (it edits `cart_page.dart`, which that card translates) and writes any new text in Vietnamese directly.

## Why

`Cart` is a `Map<MenuItem, int>` keyed by item, so "burger with cheese" and "plain burger" cannot be two lines. A cart line must be (dish + chosen toppings) with a quantity.

## Sources

`lib/customer/state/cart.dart`, `lib/customer/pages/cart_page.dart`, `lib/customer/state/menu_state.dart`, shared models from `shared-order-and-menu-models-toppings`, the stale-cart-refresh behaviour and test added by `customer-menu-page-uses-backend-menu`.

## Goal

1. `Cart` keeps plain `ChangeNotifier`. A line is a small value class `CartLine {MenuItem item, List<Topping> toppings}`: its identity (`==`/`hashCode`) is the item id plus the **set** of topping ids (order of picking does not matter). `Cart.add(MenuItem item, {List<Topping> toppings = const []})` merges into an existing identical line (quantity + 1) or creates a new line; `remove(CartLine)` / `add` from the cart page's +/- work per line. Public reads: `lines` (line -> quantity, unmodifiable), `itemCount` (sum of quantities), `total` (sum of `(item price + toppings) * quantity`), `isEmpty`, `clear()`. `toOrderItems()` maps each line to an `OrderItem` with `toppings` filled (base price in `price`).
2. The stale-menu refresh from `customer-menu-page-uses-backend-menu` keeps working: after a menu reload, line items (and toppings) are replaced by the fresh ones; lines whose dish or topping vanished are dropped. Test carried over.
3. `MenuState` loads toppings together with the menu (one `load()`, `Future.wait` of `fetchMenu` and `fetchToppings`), exposes `toppings`. One loading state and one error state for both: if either fails the page shows the same generic error and Retry (simplest; the sheet can then rely on toppings being there). Same listener/dispose guards as before.
4. `cart_page.dart` per line: dish name, then one small line listing toppings (`+ name` each) when present, unit price including toppings, +/- per line. Strings in Vietnamese. Nothing else on the page changes.

## Non-goals

The sheet, category sections, drink choice, sold-out, restaurant display, persistence of the cart.

## Tests written with the change

In `test/`:
- cart: adding the same dish twice with no toppings -> one line, quantity 2; the same dish with `[cheese]` and with none -> two lines; `[cheese, bacon]` and `[bacon, cheese]` -> one line; different toppings -> separate lines; remove decrements then deletes only that line; `total` and `itemCount` correct with toppings and quantities; `toOrderItems` carries base price and toppings; `clear`;
- stale refresh (carried over): changed price/name replaced, vanished dish or topping dropped;
- menu state: loads menu and toppings; a failing `fetchToppings` gives the error state; retry works; second load while loading ignored;
- cart page widget test: two lines (plain and with toppings) render, the toppings line is visible, +/- affects only its line, total shown, placing an order sends items with toppings (fake repository or inspect `toOrderItems`); existing cart/widget tests pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Lines merge and separate as listed; totals right | `make test` (gate) |
| Stale-refresh behaviour preserved | `make test` (gate) |
| Customer imports nothing from restaurant | `make boundaries` (gate) |
| Analyzer, format clean, no new dependency, `ChangeNotifier` only | `make analyze`, `make format-check` + empty `pubspec.yaml` diff (code-reviewer) |
| `make check` green | `make check` exit 0 (gate) |
| Cart page still works in the browser (plain adds, +/-, place order) | owner acceptance at `http://customer.local` - "unverified" until done |

## Environment limits

Agents cannot see the browser; the owner checks the cart page.

## Added 2026-11-10 (owner decision TOP3: ids now)

When the cart builds order lines (today `toOrderItems()`), every `OrderItem` must set `menuItemId` to the dish id, and every `OrderTopping` must set its topping `id`. Test it: an order built from the cart has the ids of the dish and each topping. This is what makes the later server-side price check (MENU-DB3) a backend-only change.

## Order change (owner, 2026-11-11): toppings before translation

The owner chose to let the toppings work go ahead of the Vietnamese translation, so VI1–VI3 no longer block it. Write any new user-facing text **in English**, the same as the rest of the app today. `vi-translate-customer-ui` now comes *after* this card and translates that text.

## Decided 2026-11-11: currency is VND (CUR1 / VI3)

The owner chose **VNĐ** for the whole app. The display change is card `currency-vnd-display` (prices shown as `10.000 VNĐ`, whole numbers). VI3 is no longer an open question.
