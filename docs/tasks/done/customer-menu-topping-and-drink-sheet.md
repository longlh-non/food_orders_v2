---
executor: task-executor
scopes: [customer]
workKinds: [flutter, quality-gate]
blockedBy: [customer-state-cart-lines-and-toppings, customer-menu-category-tabs]
---

# Customer menu: adding a food asks "toppings? a drink?" in a small dialog

The visible feature the owner asked for. New text is written in Vietnamese directly (VI1/VI2); wording drafted by the agent, accepted by the owner.

The slug still says "sheet" because other cards reference it. Revised 2026-11-11: TOP5 decided by owner 2026-11-11 = a small prompt dialog when a food is added (this replaces the earlier plan of one bottom sheet with a drink radio list). Nothing of this card was started before the revision.

**Revised 2026-11-11 (category tabs request):** the page is split by four tabs (`customer-menu-category-tabs`, now a blocker), which replaces this card's earlier "three headed sections in one grid". This card no longer builds any category layout; it only adds the dialogs to the food tiles that the tabs card already shows.

## Why

Choosing a dish should let the customer add toppings and/or a drink, but only when they want to. Customers who want just the dish pay one extra tap.

## Design (plain words, with the trade-off)

- The page already has four tabs "Đồ ăn", "Đồ uống", "Ăn nhẹ", "Ăn vặt" (previous card). Foods live in "Đồ ăn". The drink picker lists drinks from `MenuState` (category `drink`) **whatever tab is open**; the tab and the picker are independent.
- **Snacks ("Ăn nhẹ") and "Ăn vặt" items are added directly, with no dialog,** like drinks. They never take toppings. Asking "a drink?" for them is a possible later change (open decision ADD5, owner to answer; default = no dialog).
- **ADD1 (flow).** Tapping **Add** on a **food** opens a small `AlertDialog` titled "Add <dish name>" with two unticked checkboxes, "Extra toppings" and "A drink", and two buttons: "Cancel" and "Add".
  - "Add" with nothing ticked: adds the plain dish (one tap, same as today plus the dialog).
  - "Extra toppings" ticked: after "Add", a second small dialog lists the toppings (checkbox with `+price`, live total) with "Back" and "Add".
  - "A drink" ticked: a further small dialog lists the drinks (radio list with price) with "Back" and "Add". Order of steps: toppings, then drink.
  - The cart is changed **once, at the very end**, never before: dish with the chosen toppings as one line, the chosen drink as its own separate line (quantity 1). Then the existing "Added ..." SnackBar.
  - **Dismiss** (tap outside, Escape, phone back, or "Cancel") at any step = **nothing is added**. Reason: the customer did not say yes; adding by surprise is worse than one more tap. "Back" in a picker returns to the previous dialog with ticks kept.
  - Why checkboxes in one dialog and not three buttons ("Add toppings" / "Add a drink" / "Just the burger"): three buttons force a choice between toppings and drink, or need a loop back to the prompt (more state). Checkboxes allow both with no loop.
  - Plain-Flutter helper: a small function returning a result object (`toppings`, `drink?`) or null for cancel; the menu page does the single `Cart.add` calls. No new state class.
- **ADD2 (drinks).** Tapping **Add** on a **drink** adds it directly, no dialog. Only foods get the dialog.
- **ADD3 (frequency).** Every time a food is added. It is skippable in one tap ("Add"), so no "don't ask again" setting and no per-session memory. Trade-off: repeat customers see it each time; accepted, remembering a choice needs state the owner did not ask for.
- **ADD4 (no split).** One card, not "drinks-only first". The dialog needs toppings and cart lines, which come from the blocking cards, so a smaller slice would not ship any earlier. (Categories/tabs are already done by the previous card.)
- Same dish with different topping choices becomes different cart lines (cart card).
- If the dish has `allowToppings == false` (TOP2c, owner 2026-11-11: some dishes are "no toppings") **or** the menu has no toppings, the "Extra toppings" row is not shown; if it has no drinks, the "A drink" row is not shown; if neither, the dish is added directly with no dialog.

## Sources

`lib/customer/pages/menu_page.dart` (tabs from the previous card; `_MenuTile._add` today calls `Cart.instance.add(item)`), `lib/customer/state/menu_state.dart` (`items`, `toppings`), `lib/customer/state/cart.dart` (`add(item, toppings:)`), `lib/shared/models/menu_item.dart` (`category`, `allowToppings`).

## Goal

1. The dialogs as above, in a separate widget file in `lib/customer/pages/` (executor decides naming), reading toppings and drinks from the injected `MenuState`. Content scrolls when tall; buttons always visible. Must fit at 360 px width and text scale up to 2.0.
2. The topping dialog total updates as toppings change; formatted with `formatVnd`.
3. Plain Flutter widgets only (`showDialog`, `AlertDialog`); no new package.
4. The tab layout is not changed by this card.

## Non-goals

Tab/section layout (previous card), images, per-dish topping rules, topping quantity (two cheeses), drink quantity, "don't ask again", sold-out handling (`customer-menu-sold-out-items`, adapts to this card), restaurant changes, backend changes.

## Tests written with the change

Widget tests in `test/` with a fake `MenuState` (foods, drinks, snacks, nibbles, toppings) and `Cart.instance` cleared in `setUp`:
- Add on a food (tab "Đồ ăn") opens the dialog; nothing in the cart yet; both boxes unticked;
- "Add" with nothing ticked -> one plain line;
- ticked toppings -> topping dialog -> pick two -> cart has the dish line with those toppings; shown total matches `cart.total`;
- ticked drink -> drink dialog (drinks listed although the open tab is "Đồ ăn") -> cart has the dish line and a separate drink line;
- both ticked -> toppings dialog then drink dialog; the cart has the dish+toppings line and a separate drink line;
- "Back" keeps earlier ticks;
- dismiss paths (tap outside, "Cancel", cancel in a picker) -> cart unchanged, no SnackBar;
- same configuration twice merges (quantity 2); different toppings make a second line;
- Add on a drink, on a snack ("Ăn nhẹ") and on a "Ăn vặt" item -> added directly, no dialog;
- menu with no toppings or no drinks hides the matching row; neither -> direct add; a dish with `allowToppings: false` shows only "A drink" (or adds directly if there are no drinks);
- dialogs fit at 360 px and text scale 1.3 and 2.0 without overflow.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Dialog flow adds the right lines; dismiss adds nothing; drink/snack/Ăn vặt add directly; merge/separate behaviour | `make test` (widget tests) |
| No overflow at 360 px and text scale 1.3/2.0 | `make test` (widget tests) |
| Boundaries and analyzer clean, no new dependency | `make boundaries`, `make analyze` (gates), code-reviewer (empty `pubspec.yaml` diff) |
| `make check` green | `make check` exit 0 (gate) |
| Independent review of the change | code-reviewer |
| Whole flow at `http://customer.local`: Add a burger, tick toppings and drink, pick, open cart, see correct lines and total, place the order | owner acceptance in the browser - "unverified" until done |
| Same flow on iPhone Safari (dialogs usable with one thumb) | owner acceptance on the phone |
| Placeholder topping/drink names and prices are right (or edited); Vietnamese wording acceptable | owner acceptance (owner edits with `sqlite3`) |

## Environment limits

Agents cannot judge wording or see the browser; the owner runs the end-to-end check, including the restaurant side (`restaurant-orders-show-toppings`).

## Decisions log

- TOP5 decided by owner 2026-11-11: small prompt dialog when a food is added (not a drink inside a bottom sheet).
- ADD1-ADD4 above are the planner's recommendations; the owner may change them before the card runs.
- ADD5 (open): do snacks ("Ăn nhẹ") and "Ăn vặt" items ask "a drink?" Recommended: no, add directly.

## Order change (owner, 2026-11-11): toppings before translation

The owner chose to let the toppings work go ahead of the Vietnamese translation, so VI1–VI3 no longer block it. Write any new user-facing text **in English**, the same as the rest of the app today. `vi-translate-customer-ui` now comes *after* this card and translates that text. (The four tab labels and the empty-tab message are already Vietnamese, from `customer-menu-category-tabs`.)

## Decided 2026-11-11: currency is VND (CUR1 / VI3)

The owner chose **VNĐ** for the whole app. The display change is card `currency-vnd-display` (prices shown as `10.000 VNĐ`, whole numbers). VI3 is no longer an open question.

## Decided by the owner (2026-11-11)

**ADD5 = no.** Snack ("Ăn nhẹ") and Ăn vặt items are added directly, with no dialog and no "a drink?" question.
