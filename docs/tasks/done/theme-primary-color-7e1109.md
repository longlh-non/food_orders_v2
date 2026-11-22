---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: []
---

# Change the main (primary) colour to #7E1109

## Why

Owner request: "change the main color to #7e1109" (a dark red). It replaces #886E5A, which `docs/tasks/done/theme-primary-color-886e5a.md` set. Same shape of change.

## Sources

- `lib/shared/theme.dart`: `_brand = Color(0xFF886E5A)`, `_brandScheme()` = `fromSeed(...).copyWith(primary: _brand, onPrimary: Colors.white)`, used by both `customerTheme()` and `restaurantTheme()`. The doc comments name the old hex and its contrast numbers (lines 3, 15-16).
- `test/theme_test.dart`: `brand = Color(0xFF886E5A)` and a test name that says `#886E5A`.
- Search for hard-coded copies (done by the planner): the old hex appears only in those two files. No widget hard-codes a colour; they use `colorScheme` roles (`primaryContainer`/`onPrimaryContainer` in the "Your orders" banner, `secondaryContainer` in `menu_page.dart` ~line 510, `error` in `cart_page.dart` line 192, a plain `Chip` in `orders_page.dart`). `web/index.html` has no `theme-color` meta. `CLAUDE.md` and `docs/` (outside archived cards) do not mention the colour.
- `web/manifest.json` has `background_color` and `theme_color` `#0175C2` (the Flutter default blue, never changed). On a phone this tints the browser bar or the home-screen splash, so after this change it would be blue next to a dark-red app. See COL3.

## Goal (recommended answers to COL1-COL4 assumed)

1. COL1: both apps use the new colour (same as the previous card; one brand).
2. In `theme.dart`, change `_brand` to `Color(0xFF7E1109)` and update the two comments (hex and contrast numbers below). Keep `fromSeed(...).copyWith(primary: _brand, onPrimary: Colors.white)`.
3. COL3: set `theme_color` and `background_color` in `web/manifest.json` to `#7E1109`. No other manifest key (the `vi-web-page-metadata` card edits the name and description keys; the two do not conflict).
4. COL2: do not change the error colour or any widget (see Contrast).

## Non-goals

No dark theme, no new dependency, no widget changes, no fonts or shapes, no icon image changes (`web/icons/` stay as they are), no `CLAUDE.md` edit.

## Contrast (planner's calculation, WCAG relative luminance)

- #7E1109 has luminance about 0.049. White on it is about **10.6:1** (passes AA 4.5:1 and AAA 7:1 with plenty of room; better than the old colour's 4.75:1). Keep `onPrimary` white.
- `fromSeed` derives `primaryContainer` (a pale pink, tone ~90) and `onPrimaryContainer` (a very dark red, tone ~10). Material 3 builds these tones to pass AA, so the "Your orders" banner text should read well. The test below checks it, so nobody has to trust this.
- Error colour: the Material 3 default error is #BA1A1A. Error text on the page background is readable (about 6:1), so legibility is fine. The problem is identity: brand #7E1109 and error #BA1A1A are both reds. The contrast between the two is only about 1.7:1, so a red app bar and a red error line look like the same family. The cart's "Couldn't place your order. Try again." is the one inline error. It is a sentence on a plain background under a button, nowhere near the app bar, so it will still be read as an error because of its words and place. Recommended: leave it as is, and let the owner judge in the browser. If it feels confusing, a follow-up card can add a leading error icon (`Icons.error_outline`) to that line (small widget change, out of scope here).

## Tests written with the change

Update `test/theme_test.dart` (the earlier card had no contrast assertions; add two small ones, no new dependency, `Color.computeLuminance()` is in Flutter):

- Change `brand` to `Color(0xFF7E1109)` and the test name to `#7E1109`. Both `customerTheme` and `restaurantTheme` groups keep: primary equals brand exactly; `onPrimary` is white; Material 3; and the "same scheme" test.
- Add per theme: contrast of `onPrimary` on `primary` is at least 4.5; contrast of `onPrimaryContainer` on `primaryContainer` is at least 4.5. Compute the ratio as `(lighter + 0.05) / (darker + 0.05)` with `computeLuminance()` in a small helper in the test file.
- No test for the manifest (a JSON asset; checked by reviewer and owner).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Both themes' primary is exactly #7E1109, onPrimary white | `test/theme_test.dart` via `make test` (gate) |
| White-on-primary and onPrimaryContainer-on-primaryContainer are at least 4.5:1 | same test file (gate) |
| `make check` green (format, analyze, test, backend gates, boundaries) | `make check` exit 0 (gate) |
| Only `theme.dart`, `theme_test.dart`, `web/manifest.json` changed; old hex gone from `lib/` and `test/` (`grep -ri 886e5a lib test web` empty) | `code-reviewer` (review) |
| App bar, buttons, "Your orders" banner, chips look right; the cart error line is clearly an error; phone browser bar colour matches | owner acceptance in browser and on iPhone - "unverified" until done |

## Environment limits

Agents cannot see rendered colours or the iPhone bar tint (manifest `theme_color` is mostly honoured by Android Chrome; iOS Safari mainly ignores it, so the iPhone may show no change there). The contrast numbers above are hand-computed; the new test is the real check.

## Ordering

Independent. It does not touch the files of other pending cards except `web/manifest.json` (also in `vi-web-page-metadata`, different keys; whichever lands second just rebases a line).

## Open decisions (owner)

- **COL1: both apps or only one?** Recommend both, as before. Only-one would need `_brandScheme()` split, which the previous card chose not to do.
- **COL2: error colour near the brand red.** Recommend leave the error colour unchanged and judge it in the browser; if confusing, add a follow-up card for an error icon on the cart message. Not recommended: a custom error colour (orange or magenta), which fights Material's meaning of error.
- **COL3: update `web/manifest.json` colours?** Recommend yes, included here (two values, no risk). Say no and drop requirement 3 if you want the card to be `theme.dart` only.
- **COL4: the `primaryContainer` banner will be pale pink.** That is automatic from the seed. If the owner finds it too pink, a later card can pin `primaryContainer` to a neutral instead. Recommend wait and look first.
