---
executor: task-executor
scopes: [customer, shared]
workKinds: [flutter, quality-gate]
blockedBy: [shared-l10n-infrastructure, shared-locale-picker-widget]
---

# Customer app: replace hardcoded text with `AppLocalizations` lookups, add the language picker

**Assumes** the owner has approved LANG1–LANG4 and LANG8 as recorded in `i18n-multi-language-decisions`.

## Why, and a fork this card must resolve on inspection

This card's starting point depends on whether `docs/tasks/vi-translate-customer-ui.md` (still active, unblocked, not yet run as of this planning pass — see `i18n-multi-language-decisions`'s LANG7) has run by the time this card starts:

- **If it has not run:** `lib/customer/**` still has its original English text. This card both translates (adds the other 9 languages' worth of strings) and wires up `AppLocalizations`, in one pass — effectively doing `vi-translate-customer-ui`'s job and this card's job together, which is fine and avoids a wasted intermediate hardcode-then-un-hardcode step.
- **If it has run:** `lib/customer/**` now has hardcoded Vietnamese with the English deleted, same as the restaurant app already does. This card un-hardcodes it the same way `restaurant-l10n-wiring` does for the restaurant app, reconstructing English from source control / review history where needed.

**Inventory `lib/customer/**` fresh when this card starts and note in the PR/review which fork applied** — don't assume either state from this planning pass.

## Sources

`lib/customer/pages/menu_page.dart` ("Menu" title or current equivalent, "Your orders" banner, order-status SnackBar, "Added <item>", Add tooltip, loading/error/Retry/empty-menu text), `lib/customer/pages/cart_page.dart` ("Your Cart", empty-cart text, name field and validation message, order-placed confirmation, "Total:", "Place Order", payment-method choice labels, failure SnackBar), `lib/customer/pages/add_food_dialog.dart` (dialog title, "Extra toppings", "Add drinks" checkbox, drink-step title, Cancel/Add buttons), `lib/customer/pages/payment_qr_page.dart` (whatever text it shows around the QR and countdown), `lib/customer/main.dart` (app `title`), `test/widget_test.dart`, `test/menu_page_test.dart`, `test/order_payment_test.dart` (currently modified in the working tree per planning-time `git status` — inventory fresh).

Menu item names and descriptions are **data from the backend**, not UI strings — they stay exactly as-is regardless of UI language (same "VI5" boundary the original Vietnamese card drew). Prices stay formatted by `formatVnd` regardless of language (VI3/CUR1 — VND display doesn't change with locale).

## Goal

1. Every user-visible string in the files above is read from `AppLocalizations.of(context)!`. Interpolated values (item name, customer name, order id, item count, cart total) use ARB placeholders.
2. Add the `LanguagePicker` widget (from `shared-locale-picker-widget`) somewhere reachable in the customer app — recommend the `MenuPage` `AppBar.actions`, consistent with where it sits in the restaurant app.
3. Add every string this card touches to all 10 ARB files in `lib/shared/l10n/` (Vietnamese reused verbatim if `vi-translate-customer-ui` already ran and the owner accepted that wording; English reconstructed or freshly drafted; the other 8 agent-drafted and flagged unverified, consistent with `shared-l10n-infrastructure` and `restaurant-l10n-wiring`'s approach). Re-run `test/shared/arb_completeness_test.dart`'s key-set check after adding these — it must still pass across all 10 files.

## Non-goals

No backend text (LANG6). No change to `lib/restaurant/**`. No change to menu item names/descriptions/categories (backend data, not UI strings — a fully separate, much bigger feature: a translated menu, not asked for here and not assumed). No new dependency.

## Tests written with the change

- Update `test/widget_test.dart`'s customer test to pump with `Locale('vi')` and `Locale('en')` and assert the respective title text.
- `test/menu_page_test.dart`: the Add tooltip/SnackBar text asserted under at least `Locale('vi')`, `Locale('en')`, and one CJK locale (e.g. `Locale('zh')`) to catch rendering/encoding issues.
- A `CartPage` widget test: empty-cart text and the "enter your name" validation message asserted under two locales, proving the switch propagates into validation messages (not just static labels).
- `test/order_payment_test.dart`: whatever payment-related customer-facing text it currently asserts, re-asserted across at least two locales.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No hardcoded user-visible literal remains in the listed files | `code-reviewer` (review) |
| Locale switch changes every listed string; Vietnamese, English and one CJK language confirmed in tests | `make test` |
| Language picker visible and functional in the customer app | `make test` (widget test) + owner acceptance in the browser |
| Menu item data (names/descriptions) is untouched by the locale switch | `make test` (assert the same backend-sourced menu item name string renders under two different locales) |
| Boundaries intact, no new dependency | `make boundaries` + `pubspec.yaml` diff empty (review) |
| `make check` green | `make check` exit 0 (gate) |
| All 10 languages render correctly, including on the cart form and the payment QR page's surrounding text | owner acceptance in the browser at `http://customer.local` and on iPhone Safari — "unverified" until done |

## Environment limits

Agents can't see the rendered browser UI or judge non-English/non-Vietnamese wording quality; same caveat as `restaurant-l10n-wiring`.
