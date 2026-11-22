---
task: customer-menu-page-uses-backend-menu
status: passed
p0: 0
p1: 0
---

# Execute review — customer-menu-page-uses-backend-menu

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-10. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-customer-menu-page-uses-backend-menu.md`.

## Implementation notes

- **`MenuPage`:** takes an optional `state`, defaulting to `MenuState.instance`. It's a `CustomScrollView` containing the orders banner plus one of four states: error with a generic message and Retry, a spinner, "Menu is empty", or the `SliverGrid`.
  - Grid: tiles at most 220 px wide, a 300 px fixed height, and a `_TileImagePlaceholder`.
  - Each tile's description fills the remaining space, and its price is one line that shrinks to fit.
- **Load at app start:** `MenuState.instance.load()` is called in `lib/customer/main.dart` and `lib/dev/demo.dart`, fire-and-forget. This was chosen over loading on page build so `test/widget_test.dart` never touches the network.
- **`MenuState.hasLoaded`** is new, and `debugPrint` runs only in debug builds (`kDebugMode`).
- **`Cart.refreshItems`** swaps in the fresh items by id, keeps quantities, drops items that left the menu, and returns `(removed, repriced)`. The page's snackbar announces both.
- **`fetchMenu`** rejects duplicate ids.
- **`MenuItem.fromJson`** cleans names and descriptions for display, and rejects a name with no visible text.
- **`sample_menu.dart` is deleted** (`lib/shared/data/` is gone). `CLAUDE.md` Layout and a "Menu:" line are updated.
- **`securityReview: required` was added during execution:** the diff changes JSON parsing and logging.

**Process slip, corrected:** `git rm --cached` staged the deletion of `sample_menu.dart`, which the owner hadn't asked for. The index entry was restored with `git update-index --cacheinfo` from `HEAD`. Afterwards nothing was staged, and the file showed as a normal unstaged deletion.

## Gates — first candidate

| Command | Exit |
|---|---|
| `make analyze` | 0 |
| `make test` | **2** first: a real `RenderFlex` overflow of 24–76 px in tiles at text scale 1.3 and in narrow tiles (the price text wrapped), and the first two tiles' Add buttons were on different rows (334 vs 321). **Fixed in code:** the description became `Expanded`, and the price became one line that shrinks to fit. |
| `make test` | **2** again: the cart-refresh test hit a `mounted` assertion after it completed, because the test used `tester.runAsync`, which put the snackbar on a real-time timer. **Fixed in the test:** it now uses `unawaited(load)` plus `pumpAndSettle`. App code unchanged. |
| `make test` (39) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (72) | 0 |

## Findings (first pass): P0 0 · P1 0 · P2 3

- **P2-1**: no layout test for very long names or extreme text size. **Fixed:** a 60-character name at text ×2.0 at 360 px, with no overflow.
- **P2-2** `menu_page.dart:165`: a failed reload after a successful load hides the grid behind the error. This is deliberate. **Deferred:** a later card could show a banner over the stale grid.
- **P2-3** `test/widget_test.dart`: the smoke test now only sees a spinner. **Fixed** with a comment explaining it.

**Every carried note is satisfied:**
- stale cart refresh, with a test;
- a generic error, with a test that the raw body isn't shown;
- listener add and remove are balanced;
- `kDebugMode`;
- duplicate ids rejected.

## Fix round 1

One batch covering code P2-1 and P2-3, and security P2-1 and P2-2 (see the security report):
- `refreshItems` returns `(removed, repriced)`, and the page announces both;
- name and description cleanup for display;
- the long-name ×2.0 test;
- the smoke-test comment.

**Gates:** `make analyze` 0, `make test` 0 (41), `make format-check` 0, `make boundaries` 0.

**Re-review 1 (code-reviewer):** resolved. Two new P2s:
1. Stripping U+200D (the zero-width joiner) breaks emoji.
2. A name that's only invisible characters becomes empty.

## Fix round 2

- U+200C and U+200D are kept.
- A name that's empty after cleanup gives a `FormatException`.
- From security re-review 1: U+2028, U+2029 and U+0085 become spaces, and U+061C and U+180E are stripped.
- New tests: separators, an emoji with ZWJ preserved, and a name that's invisible-only rejected.

**One slip in this round:** the first edit wrote literal bidi characters into the Dart source. `make analyze` failed with **exit 2** on `text_direction_code_point_in_literal` (the analyzer's "Trojan Source" guard). The lines were rewritten in pure ASCII with `\u` escapes; a non-ASCII count gives 0 for both files.

**Gates:** `make analyze` 0, `make test` 0 (44), `make format-check` 0, `make boundaries` 0.

**Re-review 2 (code-reviewer):** resolved. One new P2, accepted as is: a name made only of ZWJ or ZWNJ characters counts as "visible". It's harmless. **Deferred.**

## Final candidate

`make check` → **exit 0** (format, boundaries, analyze, 44 app tests, backend analyze, 72 backend tests).

## Unverified (owner acceptance)

**In a browser** at `http://customer.local`, after the web apps are restarted to pick up this code:
- the grid in a narrow window and at full width;
- restart the backend, and the menu is still there;
- stop the backend, see the error, start it again, and Retry works;
- an order placed still appears live in the restaurant app.

**With the `sqlite3` CLI:** change a price, reload, and the new price shows (and is used for new orders).

**On an iPhone (Safari):** 2 columns, no clipped text.
