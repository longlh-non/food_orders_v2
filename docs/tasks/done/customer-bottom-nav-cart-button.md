---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [customer-menu-category-icon-tabs]
---

# Customer menu: bottom bar with a raised, centred cart button

Card 3 of 3 for the owner's UI refresh. Plain UI, so no `securityReview`.

## Style inspiration only

The look comes from `design/red-1.jpg`, a third-party brand mockup (Arby's). It is **style inspiration only**. Never copy its logo, brand name, slogans or product names. Its Home / Menu / Rewards / Profile items are **not** features of this app: do not add them.

## Why

The owner wants a bottom bar with a raised, centred, round dark-red cart button showing the item count in a badge. Today the cart is an `IconButton` with a `Badge` in the menu `AppBar`.

## Sources

- `lib/customer/pages/menu_page.dart`: `AppBar.actions` cart `IconButton` + `Badge` (`ListenableBuilder` on `Cart.instance`, `cart.itemCount`, `cart.isEmpty`), `Navigator.push(MaterialPageRoute(CartPage))`.
- `lib/customer/pages/cart_page.dart`: has its own `Scaffold` and pops back after "Place order".
- `lib/customer/state/cart.dart`: `itemCount`, `isEmpty`.
- Tests: `test/menu_page_test.dart`, `test/widget_test.dart` (the customer test uses `find.text('Menu')`), `test/cart_lines_test.dart`; re-grep `Icons.shopping_cart`, `Badge`, `IconButton` and `find.text('Menu')`.

## Decision NAV1: what is in the bar (owner)

The app has two real screens: the menu and the cart. "My orders" exists only as the banner on the menu page; there is no page for it.

- **Option A (recommended): a centred docked cart button only.** `Scaffold.floatingActionButton` (round, `primary` background, cart icon, `Badge` with `itemCount`) with `FloatingActionButtonLocation.centerDocked` in a slim `BottomAppBar` with a notch (`CircularNotchedRectangle`), cream/white, no other items. Needs: only `menu_page.dart`. No new page, no navigation package. Honest: one destination, no dead buttons. The bar is mostly empty on each side; if the owner finds that odd, choose the floating variant: the same button without a `BottomAppBar` (`centerFloat`).
- **Option B: Menu | [Cart] | My orders.** Needs a new "My orders" page (list of this session's orders incl. delivered ones, from `MyOrders` + `OrderRepository`), its own card, and a decision about whether the banner stays. "Menu" would be a no-op on the menu page. Bigger; not recommended until the owner wants the page.
- **Option C: Menu | [Cart] | My orders where My orders scrolls to the banner.** Hacky (banner is per tab and scrolls away). Not recommended.

The rest of this card assumes **Option A**. If the owner picks B or C, rewrite this card first.

## Decision NAV2: the cart page

Recommended: **stays a pushed page** (`Navigator.push`), unchanged. Making the cart a bar tab would need an `IndexedStack`/router and would break "selected category tab kept across the cart visit". `cart_page.dart` is not touched.

## Decision NAV3: the AppBar cart icon

Recommended: **remove it** (two cart buttons on one screen is confusing). The AppBar keeps the title "Menu". Alternative: keep both for a while.

## Goal (Option A, NAV2 and NAV3 as recommended)

1. `MenuPage`'s `Scaffold` gets `floatingActionButton` + `floatingActionButtonLocation: centerDocked` + `bottomNavigationBar: BottomAppBar(shape: CircularNotchedRectangle(), notchMargin: ...)`. The button is wrapped in a `ListenableBuilder(listenable: Cart.instance)` so the badge updates live: label hidden when the cart is empty, shows `itemCount` otherwise (same as today's badge). The button opens `CartPage` exactly as today.
2. Accessibility: `tooltip: 'Cart'` (semantics label; for a non-empty cart the executor may use 'Cart, N items'), size at least 56 px.
3. Remove the `AppBar.actions` cart button (NAV3).
4. The last grid row must not hide behind the bar or the button: add bottom padding to the grid `SliverPadding` (at least bar height + 16) so the last tile's "+" stays reachable. SnackBars ("Added X") must stay visible and not be covered by the bar (check that the default fixed SnackBar sits above the bar; if not, set the behaviour accordingly and note it).
5. The bar must not appear on the cart page or in dialogs (it belongs to the menu page `Scaffold`).
6. Keep keyboard focus and tab order sensible (FAB reachable).
7. Do not change `Cart`, `CartPage`, state classes or the restaurant app (no change there: the owner asked for the customer design only).

## Non-goals

No router or navigation package, no Home / Rewards / Profile / Menu items, no "My orders" page, no cart-as-a-tab, no animation work, no bar in the restaurant app, no `lib/dev/demo.dart` change (it embeds the customer app; the executor only checks it still builds and the bar does not break the split view).

## Tests written with the change

Update existing tests: those that tap `Icons.shopping_cart` in the AppBar, or count `Badge`, now find the cart button by tooltip `Cart` (`find.byTooltip('Cart')`). `test/widget_test.dart`'s `find.text('Menu')` must still find exactly one widget (the bar has no "Menu" label in Option A).

New widget tests (fake `MenuState`; `Cart.instance` cleared in `setUp`):
- the cart button is present with tooltip `Cart`, and there is no cart `IconButton` in the AppBar;
- empty cart: no badge text; add an item: the badge shows the count and updates when the count changes (for example 1 to 3);
- tapping the button opens `CartPage`; popping returns to the menu with the same tab selected (existing behaviour);
- the last tile of a tab can be scrolled fully clear of the bar: scroll to the end, the last "+" (tooltip finder) hit-tests as tappable and its rect does not overlap the bar's rect;
- the "Added X" SnackBar does not overlap the cart button's rect (or: the executor documents the measured behaviour);
- fit: no overflow at 360 px wide with text scale 1.0, 1.3 and 2.0; the grid still has 2 columns.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Docked centred cart button with a live badge, opens the cart | `make test` |
| AppBar cart icon removed; tests updated | `make test` + `code-reviewer` |
| Last row and SnackBar not hidden by the bar | `make test` |
| Fits at 360 px and text scale 1.3 / 2.0 | `make test` |
| Format, analyze, boundaries, no new dependency | `make format-check`, `make analyze`, `make boundaries`, empty `pubspec.yaml` diff |
| `make check` green | `make check` exit 0 (gate) |
| Independent review | `code-reviewer` |
| Button position and size feel right for a thumb, notch looks good on cream, iOS home-indicator area does not cover the bar | owner acceptance in the browser at `http://customer.local` and on the iPhone - "unverified" until done |
| Split demo still builds and looks sane | owner acceptance with `lib/dev/demo.dart` - "unverified" until done |

## Environment limits

Agents cannot see the browser, the phone or the iPhone safe area. The look of the notch is the owner's call.

## Ordering and overlaps

- Runs after `customer-menu-category-icon-tabs` (same file; last of the three).
- Before `customer-menu-sold-out-items`, `vi-translate-customer-ui` and `comments-customer`.
- New English strings: the tooltip `Cart` (and 'Cart, N items' if used). `vi-translate-customer-ui` must translate it.

## Decided by the owner (2026-11-17)

"All recommended" covers every open decision in the three design cards:
- **TILE1:** the description is dropped from the tile.
- **TILE2:** card shape and shadow come from the customer theme's `cardTheme`.
- **TABS1:** keep `TabController`/`TabBar`/`TabBarView` and restyle the bar.
- **TABS2, icons:** `Icons.rice_bowl` Đồ ăn, `Icons.local_drink` Đồ uống, `Icons.bakery_dining` Ăn nhẹ, `Icons.cookie` Ăn vặt.
- **TABS3:** the tab row sits in the body under the app bar.
- **NAV1:** a slim `BottomAppBar` with only a docked, centred red cart button.
- **NAV2:** the cart stays a pushed page.
- **NAV3:** remove the cart icon from the AppBar.

## Executor notes (2026-11-17)

- **The button:** `_CartButton` is a `FloatingActionButton` (56 px, `CircleBorder`, `primary`/`onPrimary`, `tooltip: 'Cart'`, a `Badge` with `itemCount` hidden while empty), inside a `ListenableBuilder` on `Cart.instance`. It's docked with `centerDocked` in a white `BottomAppBar(shape: CircularNotchedRectangle(), notchMargin: 6, height: 56)`. A white bar on the cream page, like the cards.
- **Tooltip:** a fixed "Cart"; no "Cart, N items".
- **AppBar:** the cart `IconButton` is removed; the title stays "Menu" (NAV3). `CartPage` is unchanged and still pushed (NAV2). The bar belongs only to the menu `Scaffold`; a test checks it's absent on the cart page.
- **Grid padding:** the bottom is now `16 + 56`. A layout probe at 360 px showed that with only 16 px, the last tile's card ran 12 px under the cart button, which sticks up above the bar (the "+" itself missed by 2 px). The test checks the whole tile rect, and fails without the padding.
- **SnackBar:** the default fixed SnackBar sits above the bar, and Flutter lifts the docked button above it. The test confirms the "Added …" SnackBar and the button don't overlap.
- **`lib/dev/demo.dart`:** not changed. It builds (`make analyze` covers it); its split-view look is owner acceptance.
