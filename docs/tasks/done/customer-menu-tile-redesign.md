---
executor: task-executor
scopes: [customer, shared]
workKinds: [flutter, quality-gate]
blockedBy: [theme-secondary-color-eee9e3]
---

# Customer menu: restyle the product tiles (round "+" button, softer cards)

Card 1 of 3 for the owner's UI refresh (a: tiles, b: `customer-menu-category-icon-tabs`, c: `customer-bottom-nav-cart-button`). Plain UI, so no `securityReview`.

## Style inspiration only

The look comes from `design/red-1.jpg`, a third-party brand mockup (Arby's). It is **style inspiration only**. Never copy its logo, brand name, slogans or product names. Use only the owner's own menu data and labels. Do not copy the image into `web/` or `assets/`.

## Why

The owner wants tiles like the reference: photo on top in a white rounded card, name below, price on the left and a small round dark-red "+" on the right, no description line, rounder corners, soft shadow.

## Sources

- `lib/customer/pages/menu_page.dart`: `_MenuTile` (picture `_TileImage` 96 px, name `titleSmall` 2 lines, description 2 lines, price in a `FittedBox`, `FilledButton.tonal` "Add"), `_add()` (food dialog, direct add, SnackBar), `_TabContent` grid (`maxCrossAxisExtent: 220`, `mainAxisExtent: 300`).
- `lib/customer/pages/add_food_dialog.dart` (`showAddFoodDialog`, `AddFoodChoice`, `addFoodAsks`).
- `lib/shared/theme.dart`: `customerTheme()` / `restaurantTheme()` (the cream card pins `surface` cream and `surfaceContainerLow` white).
- Tests that find the Add button: `test/menu_page_test.dart` (about 9 places), `test/add_food_dialog_test.dart` (about 11), `test/cart_lines_test.dart` (2), `test/widget_test.dart` (1). Re-grep `'Add'`, `FilledButton` and `widgetWithText` when the card starts.

## Goal

1. `_MenuTile` becomes: image on top (rounded top corners), then name (max 2 lines), then a row with the price (`formatVnd`, one line, `FittedBox` as today) on the left and a round dark-red "+" button on the right. No description line in the tile (TILE1).
2. The "+" calls the same `_add(context)`: the food dialog for foods that ask, direct add for drinks, snacks and Ăn vặt, same SnackBar text and duration. No change to `_add()` logic.
3. **Rounded corners and soft shadow live in the theme, for the customer app only** (decision TILE2, recommended): this card adds a `cardTheme` to `customerTheme()` only (shape `RoundedRectangleBorder` radius about 20, soft elevation about 2-3 with a faint shadow colour, white `color`, `clipBehavior: Clip.antiAlias`). `restaurantTheme()` is unchanged, so the restaurant `Card`s do not move. This is why the card is `scopes: [customer, shared]`. The cart page `Card` (`cart_page.dart`) also picks up the rounder look from the theme; that is intended, the executor notes it. The "+" button style is local to `_MenuTile` (a small private widget, `_AddButton`): `IconButton.filled` or a `Material`/`InkWell` circle, `primary` background, `onPrimary` icon. Do not add shapes to `_brandScheme()`.
4. Accessibility of the "+": `tooltip: 'Add ${item.name}'` (also its semantics label), visual circle about 36 px, tap target at least 48 x 48 (use `minimumSize`/`constraints` or pad the hit area; do not shrink the target with `MaterialTapTargetSize.shrinkWrap`). `Icons.add`.
5. Disabled state (for `customer-menu-sold-out-items`): `_AddButton` takes `onPressed` that may be null; when null it uses the disabled colours (greyed circle) and keeps its tooltip. This card never passes null; it only makes room for it. Do not build sold-out logic here.
6. Re-fit the tile height. With the description gone, `mainAxisExtent` can shrink (about 240-260); the executor finds the smallest value that has no overflow at 360 px wide and text scale 1.0, 1.3 and 2.0, and notes it. Keep `maxCrossAxisExtent: 220` (2 columns at 360 px).
7. Add a short comment on `_AddButton` and on the changed tile (no more than the existing style).

## Open decision TILE1: the description

Recommended: **it disappears from the tile and is not moved anywhere in this card.** Reason: the reference has none; most descriptions are empty strings in the owner's real menu (`description: ''` in the CLAUDE.md examples), so there is little to show. Alternatives, not recommended now: (i) show it in the food add dialog under the dish name (small, touches `add_food_dialog.dart` and its tests; drinks/snacks never open the dialog, so they would lose it entirely); (ii) keep a one-line description in the tile (crowds the tile at text scale 2.0). `MenuItem.description` stays in the model and the API untouched. If the owner picks (i), write a follow-up card.

## Non-goals

No change to `_add()` behaviour, `Cart`, the add dialog, `MenuState`, the grid column logic, image loading (`_TileImage`), the banner, tabs (card b), bottom bar (card c), the restaurant app, any dependency, any image or font, the reference's banner, promo or "View all" sections.

## Tests written with the change

Existing tests updated (not deleted):
- Everywhere a test does `find.widgetWithText(FilledButton, 'Add')` on a menu tile, replace it by a finder on the tooltip: `find.byTooltip('Add <exact item name>')` (add a small helper `addButtonFor(name)` in the test file). Tests in `test/add_food_dialog_test.dart` that tap the **dialog's own** "Add" confirm button keep `find.widgetWithText(FilledButton, 'Add')` (the dialog still has one); only tile taps change. Check each occurrence by hand, which is which.
- Tests that count Add buttons (for example "N tiles") count the tooltips instead.

New widget tests (fake `MenuState`; `Cart.instance` and `MyOrders` cleared in `setUp`):
- a tile shows the name, the `formatVnd` price and a "+" with tooltip "Add <name>"; it shows **no** description text even when the item has one;
- tap target: the "+" `getSize` is at least 48 x 48;
- tapping "+" on a drink adds it and shows the SnackBar; on a food that asks, opens the dialog, and cancel adds nothing (existing behaviour kept);
- `_AddButton` with `onPressed: null` is disabled (tapping does nothing). It may be tested through a tiny test-only pump of the widget if it stays private, or the executor makes it package-visible with `@visibleForTesting`;
- fit: the grid shows 2 columns at 360 px; no overflow exception at 360 px wide with text scale 1.0, 1.3 and 2.0 (long name, large price such as 1.250.000 VNĐ);
- `test/theme_test.dart`: customer theme has `cardTheme.shape` with a radius of at least 16 and a non-null elevation; restaurant theme's `cardTheme` is the default (unchanged).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Tile layout, no description, "+" behaves as the old Add | `make test` (widget tests) |
| "+" has a tooltip and a 48 px target | `make test` |
| No overflow at 360 px and text scale 1.3 / 2.0 | `make test` |
| Customer theme rounder with a soft shadow, restaurant unchanged | `make test` (theme test) |
| Format, analyze, boundaries, no new dependency | `make format-check`, `make analyze`, `make boundaries`, empty `pubspec.yaml` diff (review) |
| `make check` green | `make check` exit 0 (gate) |
| Independent review | `code-reviewer` |
| Looks like the reference in spirit (not a copy), shadow readable on cream, "+" easy to hit with a thumb | owner acceptance in the browser at `http://customer.local` - "unverified" until done |
| Same on iPhone Safari | owner acceptance on the phone - "unverified" until done |

## Environment limits

Agents cannot see the browser or the phone: the look, the shadow strength and the thumb target are the owner's call.

## Ordering and overlaps

- Runs **after** `theme-secondary-color-eee9e3` (cream page, white cards): the shadow and radius are tuned on that background and both cards edit `theme.dart`.
- Runs before `customer-menu-category-icon-tabs` and `customer-bottom-nav-cart-button` (all three edit `menu_page.dart`).
- Should run **before** `customer-menu-sold-out-items` (that card disables the "+"; it now needs the `_AddButton` disabled state from here), `vi-translate-customer-ui` and `comments-customer` (both rewrite the same file; whoever runs later works on the new code).
- New English strings in this card: only the tooltip "Add <name>". `vi-translate-customer-ui` must translate it.

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

- **The "+" button:** `AddItemButton`, a `@visibleForTesting` public widget in `menu_page.dart` so tests can pump it with `onPressed: null`. It's an `IconButton.filled` with a 36 px circle (`fixedSize`), an icon of 20 px, `tapTargetSize: padded`, so the hit area is at least 48 x 48 (tested), and `tooltip: 'Add <name>'`.
- **Tile height:** `mainAxisExtent` 300 → **250**. 246 is the smallest value that passes the fit tests (60-character name and a 1.250.000 VNĐ price at text ×2.0 at 360 px), plus a 4 px margin. The picture stays 96 px.
- **Card theme, customer only:** radius 20, elevation 2, shadow black at 30 %, white with `surfaceTintColor` transparent, `clipBehavior: antiAlias`. The cart page cards also pick up the rounder look (intended). `restaurantTheme()` is unchanged.
- **Tests changed:**
  - `test/menu_page_test.dart`: the 6 tile-tap finders now use `find.byType(AddItemButton)`.
  - `test/add_food_dialog_test.dart`: `tapTileAdd` now uses `find.byTooltip('Add <name>')`. The dialog's own "Add" finders are unchanged.
  - `cart_lines_test.dart` and `widget_test.dart` had no tile "Add" finders.
