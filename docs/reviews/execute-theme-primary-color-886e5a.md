---
task: theme-primary-color-886e5a
status: passed
p0: 0
p1: 0
---

# Execute review — theme-primary-color-886e5a

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-11. No security review: a pure theme change with no Safety-policy trigger.

Owner decisions applied: COL1 = both apps; COL2–COL6 as the planner recommended.

## Implementation notes

- `lib/shared/theme.dart`: one constant `_brand = Color(0xFF886E5A)`.
- `_brandScheme()` = `ColorScheme.fromSeed(seedColor: _brand).copyWith(primary: _brand, onPrimary: Colors.white)`.
- `customerTheme()` and `restaurantTheme()` both use it, with Material 3. The orange/indigo comment is replaced.
- New `test/theme_test.dart` (7 tests): for each theme, the primary colour is exactly #886E5A, `onPrimary` is white, and Material 3 is on; plus a check that both schemes are equal.
- Scope: only `theme.dart` and the new test. No widget, `web/` or dark-theme changes.

## Gates

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` (51) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make check` (final candidate, after the comment fix below) | **0** |

## Findings: P0 0 · P1 0 · P2 2

- **P2-1** `lib/dev/demo.dart:40`: the comment says each pane gets its own `Theme` "so the colour palette matches" the real apps, which is stale now that both themes are identical. The code stays as it is, so the demo follows the apps if they diverge again. **Deferred:** `lib/dev/` is outside this card's scope; reword the comment in a later card that touches `demo.dart`.
- **P2-2** `lib/shared/theme.dart:3`: the file-level `///` comment, followed by a blank line, attached to nothing. **Fixed** exactly as the reviewer suggested: plain `//` comments, comment text only. `make check` was rerun afterwards with exit 0, and there was no further review round for a comment-only change.

**Checked with no issues found:**
- Contrast, recomputed by the reviewer: #886E5A has luminance ≈ 0.171, so white on it is ≈ 4.74:1 (passes AA for normal text, narrowly) and black ≈ 4.43:1. The code comment's "about 4.75:1" is a rounding.
- Palette: the derived roles share the seed's hue, so the result should look coherent.
- `surfaceTint` stays derived from the seed and isn't pinned, which is fine.

## Unverified (owner acceptance)

Browser and iPhone, after the web apps are restarted:
- the app bar and button colours, and that their text is readable;
- the "Your orders" banner (`primaryContainer`);
- the grid tile placeholders (`secondaryContainer`).

`fromSeed` derives tones around T40, so the derived containers may look slightly different from the pinned primary. Only the eye can judge that.
