---
task: customer-menu-tile-redesign
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-tile-redesign

Independent reviewer: `code-reviewer` (read-only). No security review: plain UI, and the card has no `securityReview`. The reference design (`design/red-1.jpg`, a third-party brand mockup) was used for style only. The reviewer grepped `lib`, `test`, `web`, `assets` and `pubspec.yaml` and found no brand text or copied image.

## Candidate

- **`lib/customer/pages/menu_page.dart`:**
  - `_MenuTile`: picture (96 px), name (2 lines), `Spacer`, then the price and a new round "+" (`AddItemButton`, tooltip `Add <name>`). The description is no longer shown (TILE1).
  - `_add()` is unchanged.
  - Grid `mainAxisExtent` 300 → 250. Height search: 200, 215, 230, 236 and 242 failed the fit tests; 246, 248 and 250 passed. 250 leaves a 4 px margin.
  - `AddItemButton`: a public `@visibleForTesting` `IconButton.filled` with a 36 px circle, `tapTargetSize: padded` (≥ 48 px target), and an `onPressed` that can be null (a disabled state, ready for `customer-menu-sold-out-items`).
- **`lib/shared/theme.dart`:** `customerTheme()` gets a `cardTheme` (radius 20, elevation 2, a soft black shadow, white, no tint, anti-alias clip) (TILE2). `restaurantTheme()` is unchanged. The cart page cards also become rounder (intended).
- **Tests:**
  - `test/menu_page_test.dart`: tile finders use `AddItemButton`; a new group "tile redesign" (no description, 48 px target, direct add with SnackBar, disabled button).
  - `test/add_food_dialog_test.dart`: `tapTileAdd` uses `find.byTooltip`; the dialog's own Add finders are unchanged.
  - `test/theme_test.dart`: customer cards are rounded, shadowed and white; restaurant cards are the default.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2:** the `_MenuTile` doc comment still mentioned the description and an "Add button". **Fixed** (comment only).
- **P2:** the grid comment hard-coded "246 px is the tightest", which would go stale. **Fixed:** it now points to the fit tests.

Confirmed:
- Goals 1–7;
- `_add()` behaviour is unchanged;
- the 48 px target is measured on the padded box;
- the disabled test isn't vacuous;
- the tile "+" and the dialog's Add can't be confused in tests;
- the 360 px fit at text ×1.0, ×1.3 and ×2.0 is covered by the existing grid tests.

## Deferred / notes

- **Thin margin:** the 4 px height margin will shrink if fonts change; the fit tests will catch it.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (262 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate, after the comment fixes; 262 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

In the browser at `http://customer.local` and on iPhone Safari:
- the look (in the spirit of the reference, not a copy);
- how strong the shadow is on cream;
- that the "+" is easy to hit with a thumb.
