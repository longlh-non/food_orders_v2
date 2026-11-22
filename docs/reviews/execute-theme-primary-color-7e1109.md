---
task: theme-primary-color-7e1109
status: passed
p0: 0
p1: 0
---

# Review: theme-primary-color-7e1109

Independent reviewer: `code-reviewer` (read-only). No security review: a theme colour and a manifest value only (no endpoint, parsing, network, dependency or permission change). The card has no `securityReview`.

## Candidate

- **`lib/shared/theme.dart`:** `_brand` = `Color(0xFF7E1109)`. The comments now give the new hex and about 10.6:1 for white on it. `fromSeed(...).copyWith(primary: _brand, onPrimary: Colors.white)` is unchanged.
- **`test/theme_test.dart`:**
  - the brand constant and test name changed;
  - a WCAG `contrast()` helper, with a sanity test (black on white 21, white on white 1);
  - per theme, onPrimary on primary ≥ 4.5 and onPrimaryContainer on primaryContainer ≥ 4.5.
- **`web/manifest.json`:** `background_color` and `theme_color` = `#7E1109` (were Flutter's default `#0175C2`); no other key changed.
- `grep -ri 886e5a lib test web` is empty; the manifest parses as JSON.

COL1–COL4: the card's recommended answers, as its Goal assumes. The owner chose to run the card without changing them:
- **COL1:** both apps.
- **COL2:** error colour unchanged.
- **COL3:** manifest colours updated.
- **COL4:** the pale-pink banner from `fromSeed` is left to the owner's eye.

## Round 1: passed. P0 0, P1 0, P2 0

The reviewer confirmed:
- the change matches the card, and only the three files changed;
- the contrast tests check real values (the container colours come from `fromSeed`, not overrides);
- the helper formula is correct;
- the 10.6:1 figure checks out (luminance about 0.0486 → about 10.65:1);
- nothing else in `lib/` hard-codes a colour.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (246 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate; 246 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

- **Browser and iPhone look:** the app bar, buttons and chips, and the pale-pink "Your orders" banner (COL4).
- **Error line:** whether the cart's red error line still reads clearly as an error next to the brand red (COL2). If not, the follow-up is an error icon on that line.
- **Phone browser bar tint:** Android Chrome honours `theme_color`; iOS Safari mostly ignores it.
