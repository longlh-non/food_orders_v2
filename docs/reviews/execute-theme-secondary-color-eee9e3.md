---
task: theme-secondary-color-eee9e3
status: passed
p0: 0
p1: 0
---

# Review: theme-secondary-color-eee9e3

Independent reviewer: `code-reviewer` (read-only). No security review: theme colours and a manifest value only. The card has no `securityReview`.

## Candidate

- **`lib/shared/theme.dart`:** `_cream` = `Color(0xFFEEE9E3)` with a doc comment. `_brandScheme()` adds `surface: _cream` and `surfaceContainerLow: Colors.white` to `fromSeed(_brand).copyWith(primary, onPrimary: white)`. Both apps share it.
- **`test/theme_test.dart`, per theme:**
  - `surface` is cream and `surfaceContainerLow` is white;
  - contrast ≥ 4.5 for onSurface and onSurfaceVariant on cream, and for onSecondaryContainer on secondaryContainer;
  - a widget test: a real `Scaffold` is drawn cream and a real `Card` white.
- **`web/manifest.json`:** `background_color` = `#EEE9E3`; `theme_color` stays `#7E1109`.

Owner decisions (2026-11-17): SEC1 = (c) cream page background; SEC2 white cards; SEC3 manifest splash cream; SEC4 both apps.

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1, the app bar is now cream:** there's no `appBarTheme`, and the Material 3 AppBar default is `surface`. The bars are cream with dark title text, not dark red as the card's option text said.
  - This follows from SEC1 and matches the owner's reference design, where the header sits on the cream page.
  - Left for the owner to judge. If a red bar is wanted, a later card adds `AppBarTheme(backgroundColor: _brand, foregroundColor: Colors.white)`.
- **P2-2, the add-food dialog:** it uses the derived `surfaceContainerHigh`, a pink-grey, which is a third tone next to the white cards and cream page. If the owner dislikes it, a later card pins dialogs to white.
- **P2-3, contrast assertions:** the tests use `greaterThan(4.5)`, while the card says "at least". Consistent with the existing tests, and the real values are far above (about 14 and 7–8).

Checked and correct:
- Goals 1–5;
- the widget test is sound (the outermost `Material` of `Scaffold` and of `Card` is the one checked);
- the banner, chips, SnackBars (`inverseSurface`), TabBar and tonal buttons are unaffected or fine.

## Deferred follow-ups (owner's call after looking)

1. **App bar:** red, or keep it cream as in the design.
2. **Dialog background:** pin it to white, if the pink-grey looks dull.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (256 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate; 256 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

- In the browser and on the iPhone: the cream page, white cards, cream app bar, pink banner and red buttons.
- The add-food dialog's tone.
- The cart error line.
- The splash colour (only in a real build; iOS mostly ignores manifest colours).
