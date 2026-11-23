---
executor: task-executor
scopes: [restaurant, shared]
workKinds: [flutter, quality-gate]
blockedBy: [shared-l10n-infrastructure, shared-locale-picker-widget]
---

# Restaurant app: replace hardcoded Vietnamese with `AppLocalizations` lookups, add the language picker

**Assumes** the owner has approved LANG1–LANG4 and LANG8 as recorded in `i18n-multi-language-decisions`, and `shared-l10n-infrastructure` has already seeded ARB keys for the strings this card touches (it inventoried the same files). This card is the one that un-hardcodes what `vi-translate-shared-and-restaurant-ui.md` hardcoded — read that card's "done" version in full before starting, to know exactly which strings moved and where.

## Why

Right now `lib/restaurant/**` shows Vietnamese text with no way to show anything else, because `vi-translate-shared-and-restaurant-ui` deliberately deleted the English and wrote the Vietnamese directly into the widgets ("no new package, English is gone" — VI2). This card reverses that specific choice for the restaurant app: every user-visible string becomes an `AppLocalizations.of(context)!.someKey` lookup, and the restaurant `AppBar` gets the language picker from `shared-locale-picker-widget`.

## Sources

`lib/shared/models/order.dart` (`OrderStatusLabel` — becomes a function taking a `BuildContext` or an `AppLocalizations` instance, since static enum extensions can't reach localized context; check how the existing call sites use `.label` and adjust them, e.g. `order.status.label(context)` or pass `AppLocalizations` explicitly where there's no `BuildContext` handy), `lib/restaurant/pages/orders_page.dart` (AppBar title, SnackBar text and "Accept" action, empty state, 4+ action-button labels, "Order #...", "Total:", payment-action labels `_payOutcomeText` and the `PaymentAction` enum's doc-comment Vietnamese phrases that are also shown in the UI, status-update failure SnackBar), `lib/restaurant/pages/export_month_dialog.dart` (dialog title, labels, buttons, error messages), `lib/restaurant/widgets/staff_login_dialog.dart` (labels, buttons, error text), `lib/restaurant/main.dart` (app `title`, and this is where the `MaterialApp`'s `locale`/delegates from `shared-l10n-infrastructure` already live — this card just needs the `AppBar` picker placement), `test/widget_test.dart`, `test/orders_page_test.dart`, `test/export_month_test.dart` (restaurant-side assertions currently expect specific Vietnamese strings — inventory them fresh, they are marked modified in the working tree as of planning time).

## Goal

1. Every user-visible string in the files above is read from `AppLocalizations.of(context)!`, not written as a literal. Where a string has no `BuildContext` in scope (e.g. a pure function returning a label for a non-widget value), thread an `AppLocalizations` parameter through instead of reaching for `Localizations.of` statically.
2. Interpolated values (order id, customer name, counts, amounts formatted via `formatVnd`) keep working — ARB placeholders (`{orderId}`, `{customerName}`, `{count}`) carry them, `formatVnd` output is still passed in as a plain argument (currency formatting is unrelated to language per VI3/CUR1 — don't let `intl`'s own number formatting touch it).
3. Add the `LanguagePicker` widget (from `shared-locale-picker-widget`) to the restaurant `AppBar.actions`, next to the existing pending-orders `Badge`.
4. Any string that exists in Vietnamese today but wasn't in `shared-l10n-infrastructure`'s initial ARB seed (because it was added by a later card like `restaurant-orders-month-export-button`, `restaurant-orders-status-update-shows-failure`, `restaurant-confirm-bank-transfer`, or `restaurant-staff-id-password-clients` after the original translation card's scope) gets inventoried fresh here and added as a new key to all 10 ARB files (Vietnamese and English per the usual sourcing, the other 8 agent-drafted and flagged unverified, same as `shared-l10n-infrastructure`'s approach).

## Non-goals

No backend text (LANG6). No change to `lib/customer/**` (`customer-l10n-wiring`'s job). No change to `lib/dev/demo.dart` beyond whatever's needed for it to keep compiling. No new dependency.

## Tests written with the change

- Update `test/widget_test.dart`'s restaurant test to pump with an explicit `Locale('vi')` and assert the Vietnamese title (same text as today — this is a refactor, not a wording change), then re-pump the same widget tree with `Locale('en')` and assert the English title, proving the switch actually works end to end.
- `test/orders_page_test.dart`: for at least one status chip and one action-button label, assert the Vietnamese text under `Locale('vi')` and the English text under `Locale('en')`. Pick one non-Latin-script language (e.g. `Locale('ja')` or `Locale('ko')`) for at least one assertion, to catch a rendering/encoding problem specific to CJK text (missing font fallback, mojibake) that a Latin-script-only test suite wouldn't catch.
- `test/export_month_test.dart`: same before/after-locale-switch pattern for the dialog's title and one error message.
- A new unit test: every `OrderStatus` value's localized label is non-empty under all 10 locales (loop over `AppLocalizations.supportedLocales`), catching a missing key before it reaches a user.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| No hardcoded user-visible literal remains in the listed files (grep for Vietnamese-only characters or English words outside ARB files/tests) | `code-reviewer` (review) |
| Switching the app's locale changes every listed string, Vietnamese and English confirmed in tests, one CJK language spot-checked | `make test` |
| Language picker visible and functional in the restaurant `AppBar` | `make test` (widget test) + owner acceptance in the browser |
| Boundaries intact, no new dependency | `make boundaries` + `pubspec.yaml` diff empty (review) |
| `make check` green | `make check` exit 0 (gate) |
| Vietnamese wording is pixel-for-pixel the same as what the owner already accepted (no accidental rewording during the refactor) | `code-reviewer` diff review against `docs/reviews/execute-vi-translate-shared-and-restaurant-ui.md` and the pre-this-card source |
| All 10 languages render correctly on screen, no missing-glyph boxes, layout doesn't break with longer/shorter strings (German tends to run long, CJK tends to run short) | owner acceptance in the browser at `http://restaurant.local`, cycling the picker — "unverified" until done |

## Environment limits

Agents can't see the rendered browser UI, can't judge whether the 8 non-English/non-Vietnamese translations read naturally, and can't tell whether the installed browser font covers Lao or Chinese glyphs. The owner checks all of this by eye.
