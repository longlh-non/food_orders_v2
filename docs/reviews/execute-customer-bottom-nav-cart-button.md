---
task: customer-bottom-nav-cart-button
status: passed
p0: 0
p1: 0
---

# Review: customer-bottom-nav-cart-button

Independent reviewer: `code-reviewer` (read-only). No security review: plain UI, and the card has no `securityReview`. The reference design was used for style only; no Home, Rewards or Profile items were added.

## Candidate

- **`lib/customer/pages/menu_page.dart`:**
  - **AppBar:** just the title "Menu"; the cart icon is removed (NAV3).
  - **Bottom bar:** `Scaffold` gets `floatingActionButton: _CartButton()`, `centerDocked`, and a white `BottomAppBar` (notched, `notchMargin` 6, height 56) (NAV1, option A).
  - **`_CartButton`:** a `FloatingActionButton` (56 px, round, `primary`/`onPrimary`, tooltip "Cart") with a `Badge` showing `itemCount`, hidden while empty. It sits in a `ListenableBuilder` on `Cart.instance` and pushes `CartPage` as before (NAV2).
  - **Grid padding:** the bottom is `16 + 56`, so the last tile scrolls clear of the button.
- **`test/menu_page_test.dart`:** the cart-visit test taps `find.byTooltip('Cart')`, plus a new group "cart button":
  - one centred button of at least 56 px; no AppBar cart; the bar is present;
  - a live badge (hidden, then 1, then 3);
  - the button opens the cart (no bar there), and back keeps the tab;
  - at 360 px and text ×1.0/1.3/2.0, the last tile and its "+" don't overlap the button, the "+" works, 2 columns, no overflow;
  - the SnackBar doesn't overlap the button.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2-1:** the "tile doesn't overlap the bar" assertions could never fail (the body is laid out above the bar). **Fixed:** removed, with a comment that only the button can cover a tile.
- **P2-2:** "rows > 1" didn't check 2 columns. **Fixed:** it now asserts some row holds exactly two "+" buttons.

Confirmed:
- Goals 1–7;
- `CartPage` and state classes are untouched; `find.text('Menu')` still finds one widget;
- **no hero-tag clash:** `lib/dev/demo.dart` has one `MenuPage` in a nested navigator and the restaurant pane has no FAB; the cart opens inside the customer pane;
- rebuilding only the button on cart changes is cheap;
- the button is reachable by keyboard;
- the constant padding is right, because the button and bar don't scale with text.
- The tile-clearance check was shown not vacuous: with the padding back at 16, the ×2.0 case fails (the probe showed the last card 12 px under the button).

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (covers `lib/dev/demo.dart`; round 1 and after fixes) | 0 |
| `make test` (274 tests; round 1 and after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 274 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

- **Feel:** whether the button's position and size suit a thumb, and how the notch looks on cream.
- **iPhone:** the home-indicator area doesn't cover the bar (M3 `BottomAppBar` should add the safe-area inset; not tested).
- **Split demo:** `lib/dev/demo.dart` looks sane.
- **New text:** the tooltip "Cart"; `vi-translate-customer-ui` must translate it.
