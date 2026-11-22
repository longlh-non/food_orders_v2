---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [shared-menu-item-category-parsing]
---

# Customer menu: four tabs "Đồ ăn", "Đồ uống", "Ăn nhẹ", "Ăn vặt"

The visible feature the owner asked for (2026-11-11). Plain UI, so no `securityReview` (data comes only from the validated `MenuItem.category`). It does **not** need toppings, so it can ship before the toppings chain.

**TAB1 decided by owner 2026-11-11: "Ăn vặt" starts empty.** No item is moved or seeded; the owner adds items later with `sqlite3`. So on first release the "Ăn vặt" tab shows the empty message, and that is the expected result, not a bug.

## Why

One long grid mixes foods, drinks and snacks. Tabs let the customer jump straight to a kind of item.

## Design (plain words, with the trade-off)

- Flutter's built-in `DefaultTabController` + `TabBar` (in `AppBar.bottom`) + `TabBarView`. No new package. Swiping on a phone also changes tab.
- Tab labels, **exactly as the owner wrote them and in this order:** "Đồ ăn" (`food`), "Đồ uống" (`drink`), "Ăn nhẹ" (`snack`), "Ăn vặt" (`nibble`). Defined once as a small const list in `menu_page.dart`. The rest of the UI is still English until `vi-translate-customer-ui`; the mix is accepted.
- **All four tabs always show,** even when a category has no items. An empty tab shows a short centred message in Vietnamese: "Chưa có món nào trong mục này" (wording for the owner to accept).
- **Start tab: "Đồ ăn"**. The selection is kept while the customer opens the cart and comes back, and resets on a page reload. No saving across visits.
- **"Your orders" banner** (TAB3): stays at the top of the content of **every** tab, scrolling away with the grid like today (first sliver of each tab's `CustomScrollView`). Why not a fixed strip above the tabs: with several active orders it would eat a phone screen.
- Loading, error ("Couldn't load the menu" + Retry) and the global "Menu is empty" states stay as today and replace the tab content (the tab bar may stay visible). The per-tab empty message covers an entirely empty menu too, so the executor may drop the global empty message; note which.
- Each tab filters `MenuState.items` by `category`, keeping server order. No new state class.
- **Narrow screens:** four labels fit at 360 px at normal size; at text scale 1.3 or 2.0 they may not. Use a fixed `TabBar` if tests pass at all three sizes, else `isScrollable: true`. Executor records which.
- Add button behaviour is unchanged (adds directly). The food add dialog arrives in `customer-menu-topping-and-drink-sheet`.

## Sources

`lib/customer/pages/menu_page.dart` (`MenuPage`, `_menuBody`, `_MyOrdersBanner`, `_MenuTile`), `lib/customer/state/menu_state.dart`, `lib/shared/models/menu_item.dart` (`category`), `test/menu_page_test.dart`, `test/widget_test.dart`.

## Goal

1. Four tabs as designed, one grid per tab, same tile and grid settings as today.
2. Banner in each tab; per-tab empty message; loading/error states preserved.
3. Items whose category has no tab cannot exist (the parser rejects them), so no fallback tab.
4. No item is seeded or moved into "Ăn vặt" by any code (TAB1).

## Non-goals

Toppings/drink dialog, sold-out handling, images, translation of other strings, saving the selected tab, counts on tab labels, search, restaurant app, seeding Ăn vặt items.

## Tests written with the change

Widget tests (fake `MenuState`; `Cart.instance` and `MyOrders` cleared in `setUp`):
- four tabs with the exact labels in order Đồ ăn, Đồ uống, Ăn nhẹ, Ăn vặt;
- on start only "Đồ ăn" items are shown; tapping each tab shows only that category's items, in menu order;
- with **no** `nibble` items (the real first-release state) "Ăn vặt" shows the empty message and is still tappable; with one `nibble` item it shows that item;
- the banner appears with an active order on at least two different tabs, and is absent without one;
- Add on a tile in a non-food tab still adds to the cart;
- loading and error states still render (existing tests pass);
- the tab bar fits at 360 px wide at text scale 1.0, 1.3 and 2.0 without overflow errors, and the grid has 2 columns at 360 px;
- selecting a tab, pushing the cart page and popping keeps the selected tab.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Four tabs, owner's order and labels, correct filtering, empty message | `make test` (widget tests) |
| Fits at 360 px and text scale 1.3/2.0 | `make test` (widget tests) |
| Banner position as designed | `make test` + owner acceptance |
| Boundaries, analyzer, format clean, no new dependency | `make boundaries`, `make analyze`, `make format-check` (gates) + empty `pubspec.yaml` diff (code-reviewer) |
| `make check` green | `make check` exit 0 (gate) |
| Independent review | code-reviewer |
| At `http://customer.local`: tabs look right, switching feels natural, Ăn vặt shows the empty message, then after the owner's `sqlite3` INSERT (CLAUDE.md example) and a reload shows the new item; Vietnamese labels render with diacritics | owner acceptance in the browser - "unverified" until done |
| Same on iPhone Safari (labels readable, swipe works, no clipped labels) | owner acceptance on the phone |

## Environment limits

Agents cannot see the browser or the phone; the owner checks the look and the Vietnamese wording of the empty message.

## Decided by the owner (2026-11-11): "all recommended"

- **TAB3:** the "Your orders" banner is the first item of every tab and scrolls away, as today.
- **TAB4:** an item with an unknown category fails the menu load with the usual generic error and Retry. There's no fallback tab.
- **Empty-tab message, wording approved:** "Chưa có món nào trong mục này".
- **Starting tab:** Đồ ăn. The chosen tab is kept while the customer visits the cart.
- **TAB1** (already decided): Ăn vặt starts empty.

## Decided by the owner (2026-11-12), after review round 1

- **Banner test (P1):** add it. Scope widened, with the owner's approval, to two small test-only seams in shared/customer state: `OrderRepository.setOrdersForTest` and `MyOrders.clearForTest` (both `@visibleForTesting`, no network, no behaviour change for the apps).
- **Scroll position (P2):** each tab keeps its own scroll position when the customer switches tabs and comes back (`PageStorageKey` per tab). Tested.
- **Tab alignment (P2):** tabs stay left-aligned (`isScrollable: true`, `TabAlignment.start`).
- Executor notes: `isScrollable: true` was chosen because a fixed `TabBar` clipped labels at text scale 2.0. The global "Menu is empty" message was dropped; the per-tab empty message covers an empty menu.
