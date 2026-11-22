---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [customer-menu-tile-redesign]
---

# Customer menu: category tabs as icon tiles

Card 2 of 3 for the owner's UI refresh. Plain UI, so no `securityReview`.

## Style inspiration only

The look comes from `design/red-1.jpg`, a third-party brand mockup (Arby's). It is **style inspiration only**. Never copy its logo, brand name, slogans or product names (its tab names such as "Featured", "Sandwiches", "Roast Beef" are theirs; do not use them). Use the owner's four tabs and Vietnamese labels.

## Why

The owner wants a horizontal row of small white rounded tiles, each with an icon and a label, the selected one highlighted (red icon, tinted tile).

## Sources

- `lib/customer/pages/menu_page.dart`: `const _tabs` (food "Đồ ăn", drink "Đồ uống", snack "Ăn nhẹ", nibble "Ăn vặt"), `DefaultTabController`, `TabBar(isScrollable: true, tabAlignment: TabAlignment.start)` in `AppBar.bottom`, `TabBarView`, `PageStorageKey('menu-tab-<category>')` per tab, `_TabContent` empty message "Chưa có món nào trong mục này".
- `docs/tasks/done/customer-menu-category-tabs.md`: the behaviour that must survive.
- `test/menu_page_test.dart`: tab tests (labels, filtering, empty tab, keep tab across the cart, scroll position, fit).

## Decision TABS1: keep or replace the TabController

Recommended: **keep `DefaultTabController` + `TabBar` + `TabBarView` and only restyle the bar.** Reason: swiping, keeping the selected tab across the cart visit (the controller lives in the page state), the per-tab scroll position and every existing test come for free. A hand-made row of buttons would need its own `PageView`/state and re-prove all of that, for no visible gain. Cost of keeping: `TabBar` has no "white tile" look built in, so we use a small trick (below).

Restyle plan (executor chooses the simpler that works, notes which):
- (preferred) `TabBar(isScrollable: true, tabAlignment: TabAlignment.start, dividerColor: Colors.transparent, indicatorColor/indicator: none)` with each `Tab(child: _CategoryTile(...))`. `_CategoryTile` reads `DefaultTabController.of(context)` and rebuilds with `AnimatedBuilder(animation: controller.animation!)` to know if it is the selected one, so it can draw a white tile with a soft shadow, or a tinted tile (`primaryContainer` lightly) with a `primary` icon and label.
- (fallback) plain `Tab(icon:, text:)` plus a `BoxDecoration` `indicator` (rounded, tinted), `labelColor: primary`, `unselectedLabelColor: onSurfaceVariant`. Simpler, but the unselected tiles cannot be white because the indicator is painted behind the tabs.
- Keep `isScrollable: true` (a fixed bar clipped labels at text scale 2.0 in the earlier card; same constraint).

## Decision TABS2: icons (owner approves)

Material icons only; no new icon package, no image assets.

| Tab | Label | Icon |
|---|---|---|
| food | Đồ ăn | `Icons.rice_bowl` |
| drink | Đồ uống | `Icons.local_drink` |
| snack | Ăn nhẹ | `Icons.bakery_dining` |
| nibble | Ăn vặt | `Icons.cookie` |

The executor checks each exists in the installed Flutter SDK; if one is missing, the closest Material icon is used and the owner is told. Icons are decoration: the tile's label text is the accessible name (exclude the icon from semantics).

## Decision TABS3: where the row sits

Recommended: **in the body, directly under the app bar, on the cream page** (as in the reference), not inside the dark-red `AppBar.bottom` (white tiles on dark red look heavy, and the shadow is lost). The body becomes `Column(TabBar in a padded SizedBox, Expanded(TabBarView))`; error and loading states still replace only the tab content (the bar may stay visible, as now). The `AppBar` keeps the title "Menu" (and for now the cart icon; card c moves it). Alternative: leave it in `AppBar.bottom` (smaller change, worse look).

## Goal

1. A scrollable row of icon tiles (about 72-80 px wide, 64-72 px tall, radius about 16, labels one line, 12 px gap, left padding 16) replaces the text tabs.
2. The selected tile: tinted background, `primary` icon and label, bold label. Unselected: white tile, soft shadow, `onSurfaceVariant` icon.
3. Every behaviour from the archived tabs card is kept: starts on Đồ ăn, tap or swipe changes tab, the selected tab survives opening and closing the cart, each tab keeps its own scroll position, empty tab shows "Chưa có món nào trong mục này", the "Your orders" banner stays the first sliver of each tab.
4. Tab order and labels unchanged; `_tabs` gets the icon as a third field.

## Non-goals

No new tabs, no counts on tabs, no new state class, no search, no "Featured"/"View all", no banner/hero image from the reference, no change to tiles (card a) or the cart button (card c), no restaurant app.

## Tests written with the change

Existing tests in `test/menu_page_test.dart` stay and must pass; update finders only where the widget type changed (`find.text('Đồ ăn')` still works because the label stays a `Text`; if a test used `find.byType(Tab)`, adjust). New or extended widget tests:
- four tiles with the exact labels in order and the four icons (`find.byIcon`);
- the selected tile differs from the others (for example the selected label's style colour equals `primary`); after tapping another tile, the selection moves;
- swiping the content changes the selected tile;
- selected tab kept after pushing the cart and popping (existing test, still green);
- scroll position kept per tab (existing test, still green);
- the row fits at 360 px with text scale 1.0, 1.3 and 2.0 with no overflow exception, is scrollable horizontally, and all four labels can be reached (`scrollUntilVisible` or drag);
- tapping a tile that is off-screen after scroll selects it;
- the empty-tab message and the banner still show.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Four icon tiles, labels, selection highlight, swipe | `make test` |
| Archived tab behaviours kept (cart visit, scroll position, empty message, banner) | `make test` (existing tests green) |
| Fits at 360 px and text scale 1.3 / 2.0 | `make test` |
| Format, analyze, boundaries, no new dependency | `make format-check`, `make analyze`, `make boundaries`, empty `pubspec.yaml` diff |
| `make check` green | `make check` exit 0 (gate) |
| Independent review | `code-reviewer` |
| Icons suit the foods, selected state is obvious, row feels natural to swipe, diacritics render | owner acceptance in the browser at `http://customer.local` - "unverified" until done |
| Same on iPhone Safari (no clipped labels, swipe on the row and on the grid do not fight) | owner acceptance on the phone - "unverified" until done |

## Environment limits

Agents cannot see the browser or phone. Horizontal swipe on the tile row versus the tab pages is a real-device check.

## Ordering and overlaps

- Runs after `customer-menu-tile-redesign` and before `customer-bottom-nav-cart-button` (same file).
- Before `customer-menu-sold-out-items`, `vi-translate-customer-ui`, `comments-customer` (same file).
- New strings: none (labels are already Vietnamese; icons have none).

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

- **Restyle method (preferred option):** `TabBar` with no indicator and a transparent divider. Each `Tab(child: _CategoryTile)` reads `DefaultTabController.of(context)` and rebuilds on `controller.animation`, so the highlight follows a swipe (`animation.value.round()`).
  - Selected: `primaryContainer` tile, `primary` icon and bold label.
  - Unselected: a white tile with a soft shadow, `onSurfaceVariant` icon.
- **Sizes differ from the card:** tiles are at least 76 px wide and **grow with their label** instead of a fixed 72–80 px, and the row height follows the text size (`textScaler.scale(16) + 64`). That way no label is cut off at text ×2.0. It's the same reason the old bar was scrollable.
- **Placement (TABS3):** the row sits in the body (`Column(_CategoryBar, Expanded(...))`), not in `AppBar.bottom`. Loading and error states still replace only the tab content.
- **Icons:** all four exist in the installed Flutter SDK (`rice_bowl`, `local_drink`, `bakery_dining`, `cookie`). They're wrapped in `ExcludeSemantics`; the label is the accessible name.
- **Test change:** the "four tabs with the owner's labels" test read `Tab.text`, which is null when a `Tab` has a `child`. It now reads the `Text` inside each tab.
