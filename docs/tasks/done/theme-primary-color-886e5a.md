---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: []
---

# Change the main (primary) colour to #886E5A

## Why

Owner request: "change the major color to #886e5a". Today `lib/shared/theme.dart` seeds the customer theme with `Colors.deepOrange` and the restaurant theme with `Colors.indigo` (different on purpose, so you can tell the apps apart at a glance, see the file's comment).

## Sources

`lib/shared/theme.dart` (only file with colours; both apps and `lib/dev/demo.dart` call `customerTheme()` / `restaurantTheme()`). Widgets use no hard-coded colours: the only colour code is `scheme.primaryContainer` / `onPrimaryContainer` in the "Your orders" banner (`lib/customer/pages/menu_page.dart`), which follows the theme automatically. No test asserts colours. `web/manifest.json` has `theme_color` / `background_color` `#0175C2` (Flutter default); `web/index.html` has no theme-color meta.

## Goal (recommended answers to COL1-COL6 assumed; change if the owner decides otherwise)

1. COL1: both themes use the new colour (one brand). Update the file's doc comment, which currently says the colours differ per app.
2. COL2: make the exact hex show up as the primary colour: `ColorScheme.fromSeed(seedColor: const Color(0xFF886E5A)).copyWith(primary: const Color(0xFF886E5A), onPrimary: Colors.white)`. Define the colour once as a private constant in `theme.dart`. Put the shared scheme in one small private function used by both themes.
3. Do not change fonts, shapes or other component themes.

## Non-goals

No dark theme (none exists today, COL4). No `web/` edits (COL5). No new dependency, no widget changes (COL6). Status-chip colours are not in the code today.

## Tests written with the change

New `test/theme_test.dart`: `customerTheme().colorScheme.primary == Color(0xFF886E5A)` and the same for `restaurantTheme()`; `onPrimary` is white. Existing tests must still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Both themes' primary is exactly #886E5A | `test/theme_test.dart` via `make test` (gate) |
| `make check` green | `make check` exit 0 (gate) |
| No boundary or scope creep (only `theme.dart` + test) | `code-reviewer` (review) |
| Colour looks right, text on buttons/app bar readable, banner on menu page looks OK | owner acceptance in browser and on iPhone - "unverified" until done |

## Environment limits

Agents cannot see the rendered colours. Contrast: white on #886E5A is about 4.75:1 (passes 4.5:1 for normal text, a narrow margin); black on it is about 4.4:1, so keep `onPrimary` white.

## Ordering

Independent of the other pending cards (they do not touch `theme.dart`). The menu-grid and tile cards use `colorScheme` roles, so they pick the colour up automatically in any order.

## Decided 2026-11-11

- **COL1 = both apps.** `customerTheme()` and `restaurantTheme()` both use `#886E5A` as the main colour. This replaces the deliberate orange/indigo difference; update the comment in `theme.dart` that explains it.
- COL2–COL6: the planner's recommendations stand. Exact primary via `fromSeed(...).copyWith(primary: #886E5A, onPrimary: white)`, light theme only, `web/` left to a later card, and no hard-coded colours to change.
