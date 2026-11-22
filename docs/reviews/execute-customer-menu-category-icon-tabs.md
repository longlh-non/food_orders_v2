---
task: customer-menu-category-icon-tabs
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-category-icon-tabs

Independent reviewer: `code-reviewer` (read-only). No security review: plain UI, and the card has no `securityReview`. The reference design was used for style only: a grep for its tab names and brand found nothing in `lib/`.

## Candidate

- **`lib/customer/pages/menu_page.dart`:**
  - `_tabs` holds `(category, label, icon)`: Đồ ăn `rice_bowl`, Đồ uống `local_drink`, Ăn nhẹ `bakery_dining`, Ăn vặt `cookie` (TABS2; all exist in the installed SDK).
  - The tab row moved from `AppBar.bottom` into the body: `Column(_CategoryBar, Expanded(...))` (TABS3).
  - **`_CategoryBar`:** still a `TabBar` (TABS1). Scrollable, start-aligned, no indicator, transparent divider, 16 px left edge and 12 px gaps, no splash or overlay. Its height follows the text size (`textScaler.scale(16) + 64`).
  - **`_CategoryTile`:** follows `DefaultTabController` through `AnimatedBuilder(controller.animation)`.
    - **Selection:** on a tap it shows the target at once (`indexIsChanging ? index : animation.value.round()`); on a swipe it follows live.
    - **Look:** selected is a `primaryContainer` tile with a `primary` icon and bold label; unselected is white with a soft shadow and an `onSurfaceVariant` icon.
    - **Size:** at least 76 px wide and growing with the label (deviation from the card's fixed 72–80 px, so nothing is clipped at text ×2.0); the icon is excluded from semantics.
- **`test/menu_page_test.dart`:**
  - the label-order test now reads the `Text` inside each `Tab`;
  - new tests: icons per tile, a highlight (colour and bold) that follows taps, a swipe that moves the selection, no in-between highlight when tapping a far tile, and reaching and selecting 'Ăn vặt' at 360 px and text ×2.0;
  - all archived tab tests are unchanged and green: the cart visit keeps the tab, scroll position, empty message, banner on two tabs, fit at 1.0/1.3/2.0.

## Round 1: passed. P0 0, P1 0, P2 4

- **P2-1:** the TabBar ripple was painted under the opaque tiles (barely visible).
- **P2-2:** the selected pale-pink tile has only a faint edge on cream.
- **P2-3:** `animation.value.round()` made the highlight step through the tiles in between on a far tap.
- **P2-4:** the selection tests compared only the label colour.

Confirmed:
- Goals 1–4 and every archived tab behaviour (both `openTab` helpers still work);
- `controller.animation!` is safe (tiles unmount before the controller is disposed);
- the rebuild cost is negligible;
- the Tab height leaves 18 px of slack at ×2.0;
- the gaps and left edge are as specified;
- `primary` on `primaryContainer` is about 9–10:1;
- each tab's label is exposed once.

## Fixes

- **P2-1:** `splashFactory: NoSplash.splashFactory` and a transparent overlay; the highlight change is the feedback.
- **P2-3:** `indexIsChanging ? controller.index : animation.value.round()`. Test added: tapping a far tile never highlights the ones in between. It fails with the old rule, so it isn't vacuous.
- **P2-4:** the selection test also asserts the bold label.
- **P2-2:** left for the owner to judge in the browser. If it's too subtle, add a thin `primary` outline later.

## Re-review 1: passed. P0 0, P1 0, P2 0

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after fixes) | 0 |
| `make test` (266 tests, then 267 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 267 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

In the browser at `http://customer.local` and on iPhone Safari:
- the icons suit the foods;
- the selected state is obvious (P2-2);
- the diacritics render;
- swiping the tile row and swiping the menu pages don't fight;
- a screen reader's "Tab n of 4" output.
