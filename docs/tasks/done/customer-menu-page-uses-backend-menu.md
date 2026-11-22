---
executor: task-executor
scopes: [customer, shared, docs]
workKinds: [flutter, quality-gate, documentation]
blockedBy: [customer-menu-client-and-state]
securityReview: required
---

# Show the database menu as a grid in the customer menu page; remove the hardcoded menu

Includes review fixes from planning (injectable state in the widget test, no reliance on Flutter test's fake HTTP). **Revised 2026-11-10 for the grid request:** the page is now a responsive grid of food cards instead of a list, so the grid exists from this card on and later cards (toppings sheet, drinks, sold-out) build on it instead of rewriting a list. The slug is unchanged because other cards refer to it. **Revised 2026-11-10 for the image request:** the placeholder block must be its own small private widget so `customer-menu-tile-shows-image` can swap in the real picture without touching the rest of the tile.

## Why

Make the page read the menu from the new state (which gets it from `GET /menu`, backed by the database), delete the Flutter-side copy so there is a single source of truth, and give the menu the grid layout the owner asked for.

## Sources

`lib/customer/pages/menu_page.dart` (uses `sampleMenu` at the `ListView.separated`), `lib/customer/main.dart` (`const MenuPage()`), `lib/dev/demo.dart` (`const MenuPage()`; check it does not use `sampleMenu`), `lib/customer/state/menu_state.dart`, `lib/shared/data/sample_menu.dart`, `lib/shared/models/menu_item.dart` (doc comment mentions `sampleMenu`), `CLAUDE.md` "Layout".

## Goal

1. `MenuPage` gets an optional constructor parameter `MenuState? state`; when null it uses `MenuState.instance`. `main.dart` and `demo.dart` keep calling `const MenuPage()` unchanged. It renders with `ListenableBuilder`. Three visible states: loading spinner, error message with a Retry button, and the grid. Empty list shows a short "Menu is empty" text.
2. **The grid.** A `GridView` using `SliverGridDelegateWithMaxCrossAxisExtent` (the number of columns follows the width: about 2 columns at a 360 px phone, more on a laptop; plain Flutter, no package). Each tile is a card with: a placeholder block where the image goes (a fixed-height coloured box with an icon, built as one small private widget, e.g. `_TileImagePlaceholder`, taking only the size it fills; real pictures are the card `customer-menu-tile-shows-image`, so leave a one-line comment pointing there), the name, a short description (max 2 lines, ellipsis), the price, and the existing Add button with the existing "Added ..." SnackBar. Tile layout must not overflow at 360 px width or at larger text scale (use a sensible fixed `mainAxisExtent`, or an aspect ratio that leaves room). The "Your orders" banner stays above the grid and the page scrolls as one.
3. Start the load at app start (customer `main.dart`, fire-and-forget like `OrderRepository.init()`) or when the page first builds; the executor picks the smaller option and notes it. Backend down must not stop the app from booting.
4. Delete `lib/shared/data/sample_menu.dart` and update the `MenuItem` doc comment. If it was the last file in `lib/shared/data/`, the folder goes away.
5. Docs (owner approval for the CLAUDE.md edit is requested by this card): update the "Layout" tree (remove `data/`) and mention the menu comes from `GET /menu`, stored in the database (the editing instructions were added by `backend-menu-endpoint`; do not duplicate them, point to them).

## Non-goals

No real images (placeholder only; `customer-menu-tile-shows-image` does them), categories or drink sections, toppings, sold-out flags, staff editing UI, menu auto-refresh (a menu edit appears on page reload), no restaurant app change (it does not use the menu). Category sections and the toppings sheet are `customer-menu-topping-and-drink-sheet`.

## Tests written with the change

Widget test in `test/` (pumps `MenuPage(state: fakeState)`; the fake is a `MenuState` built on an `OrderApiClient` with a `MockClient`, or a small test subclass, so the test never touches the network or Flutter test's default fake 400 HTTP): loading shows a spinner; error shows Retry and tapping it reloads; loaded shows the item names and prices; empty shows "Menu is empty"; tapping add puts the item in the cart. Grid tests: set the test surface to 360 px wide and assert at least two tiles share the same row (same top offset) and no overflow exception is reported (also with `textScaler` 1.3); at 1000 px wide more tiles per row than at 360. Existing tests keep passing after `sample_menu.dart` is removed (fix imports in tests if any used it, and say so). `MenuPage` also builds inside the existing `test/widget_test.dart` flows without a network.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Page shows loading, error+retry, grid, empty states using an injected state | `make test` (widget test) |
| Grid has multiple columns at 360 px and no overflow | `make test` (widget test) |
| No leftover reference to `sampleMenu` | `make analyze` (gate) + `code-reviewer` (review) |
| Customer and restaurant still do not import each other | `make boundaries` (gate) |
| Docs match behaviour | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Grid looks right at `http://customer.local` on a narrow window and full width; menu appears; restart the backend and the menu is still there; stopping the backend shows the error and Retry works after restart; order placed still appears live in the restaurant app | owner acceptance in the real environment - "unverified" until done |
| Change a price with the documented `sqlite3` command, reload the customer page: new price is shown (and an order placed afterwards uses it) | owner acceptance in the real environment |
| Grid looks right on iPhone Safari (2 columns, no clipped text) | owner acceptance on the phone |

## Environment limits

Agents cannot run the browser flow, the backend stop/start check, or the `sqlite3` CLI edit; the owner does them.

## Added by `customer-menu-client-and-state` reviews (2026-11-10)

- **Stale cart items (code P2-1):** `MenuItem` is equal by id, and `Map` keeps the first key, so after a menu reload a cart item keeps its old price and name. Handle it here: when a new menu loads, replace cart keys with the fresh items (or drop items no longer on the menu, and tell the customer). Add a test. Planning note: put this in one small `Cart` method (e.g. `refreshItems(List<MenuItem>)`); `customer-state-cart-lines-and-toppings` will reshape `Cart` later and must carry this behaviour and its test over.
- **Error display (code P2-2):** show a generic message ("Couldn't load the menu") plus Retry. Never show `error.toString()`.
- **Disposal (code P2-2):** if this card creates a per-page `MenuState` rather than using the singleton, guard `notifyListeners()` after dispose.
- **Optional hardening (security P2-2, P2-3):** wrap `MenuState`'s `debugPrint` in `if (kDebugMode)`. Consider rejecting duplicate menu ids in `fetchMenu`.

## Execution note (2026-11-10)

`securityReview: required` was added during execution. The diff changes JSON parsing (`fetchMenu` now rejects duplicate menu ids, which was the optional hardening above) and how errors are logged (`kDebugMode`). Both are triggers in `CLAUDE.md` → "Safety policy".
