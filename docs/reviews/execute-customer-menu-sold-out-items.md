---
task: customer-menu-sold-out-items
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-sold-out-items

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 560 tests (8 new in `test/menu_sold_out_test.dart`) |
| `make backend-analyze` / `make backend-test` | 0 / 0 | (implementer run; no backend change) |
| `make analyze` / `make check` | 2 | 20 infos, all `deprecated_member_use` on the `package:flutter/material.dart` import: the 19 pre-existing plus the same info on the import of the new test file (same import as the existing tests). No other finding |

## Changed paths

`lib/customer/pages/menu_page.dart`, `lib/customer/pages/add_food_dialog.dart`, `test/menu_sold_out_test.dart` (new). `Cart`, `MenuState`, `lib/shared/**`, `CLAUDE.md`, backend and infra untouched.

## Behaviour

Sold-out item (`available == false`): tile at 50% opacity with a non-dimmed "Hết hàng" pill over the picture (tile height unchanged); "+" disabled (`onPressed: null`, tooltip kept) and `_add` returns early; sold-out drinks are listed disabled in the drink dialog with "Hết hàng" instead of the price. Items already in the cart are not touched (MENU-EDIT6). Beyond the card: `addFoodAsks` counts only available drinks, and the "Thêm đồ uống" checkbox is hidden when none is available, so a food without toppings goes straight to the cart instead of leading to a dead-end drink step (reviewer: justified small fix, documented in the comments, not a correctness risk).

## Findings (code-reviewer): P0 0, P1 0, P2 4 — deferred

1. No widget test for the user-visible effect of the `addFoodAsks` addition (food without toppings + only a sold-out drink → tap "Thêm X" → no dialog, food in cart).
2. Accessibility: the "Hết hàng" label is a separate semantics node from the disabled "+"; wrap the sold-out card in `Semantics(label: '<name>, Hết hàng')`/`MergeSemantics`. Contrast under `Opacity(0.5)` is owner acceptance. Overlay height `96` duplicates `_TileImage(height: 96)`; extract a constant.
3. `_add` doc comment (`menu_page.dart` ~641-644) runs the new sentence into the old paragraph and wraps badly.
4. The fit tests assert no exception only, not that the pill stays inside the tile or that a two-line name fits at text scale 2.0.

## Unverified (owner acceptance)

"Hết hàng" wording and the dimmed look in a real browser at `http://customer.local` and iPhone Safari; end to end: mark an item sold out, reload the customer page.

## Verdict

**Passed**, P0: 0, P1: 0.
