# Translations (ARB files)

One file per language: `app_vi.arb` (template, defines keys and placeholders),
`app_en.arb`, `app_zh.arb` (Simplified), `app_lo.arb`, `app_es.arb`,
`app_fr.arb`, `app_ru.arb`, `app_de.arb`, `app_ko.arb`, `app_ja.arb`.
The `app_localizations*.dart` files are generated from them by
`flutter gen-l10n` (runs on `flutter pub get`, `flutter run`, `flutter test`);
do not edit them by hand. Every language must have the same keys
(`test/shared/arb_completeness_test.dart`).

## Wording status (owner decision LANG5, 2026-11-23)

- `vi`: the Vietnamese the owner already accepted, copied verbatim. Strings
  that appeared after that acceptance (menu editor, export dialog, payment
  buttons) were drafted by the same translation pass; owner acceptance of
  them is pending (unverified).
- `en`: restored from the old English where git history had it (orders page,
  export dialog, staff login, status labels, titles); everything else is
  redrafted, not restored (menu editor, payment texts, new strings).
- `zh`, `lo`, `es`, `fr`, `ru`, `de`, `ko`, `ja`: machine-quality drafts.
  **Unverified wording**: no fluent reader has checked them. Lao and the plural
  forms of Russian need particular care.

## Customer app strings (customer-l10n-wiring)

58 `customer*` keys (menu page, cart, add dialog, payment page) were added to
all 10 files. The customer UI was already hardcoded Vietnamese when they were
written, and the old English was no longer in git, so:

- `vi`: the existing hardcoded text, verbatim.
- `en`: redrafted from the Vietnamese, not restored.
- `zh`, `lo`, `es`, `fr`, `ru`, `de`, `ko`, `ja`: machine-quality drafts,
  **unverified** (same caveat as above). Plural messages (`customerCartPriceChanged`,
  `customerCartRemoved`) have `one`/`other` for en, es, fr, de; `one`/`few`/`many`/`other`
  for ru; only `other` for vi, lo, ja, zh, ko.
- Order status and payment method names reuse the `status*` / `payment*` keys.

## Menu add form (restaurant-menu-add-form)

16 `menuAdd*` / `menuFull` keys (add button tooltip, the form's title, labels,
field errors, "duplicate", "menu full", the "Added: {name}" snack bar and the
confirm button) were added to all 10 files. The category names reuse the
`customerCategory*` keys; cancel, price and save-failed texts are reused too.

- `vi`: written by the agent in plain Vietnamese, in the style of the existing
  menu editor texts. **Pending owner acceptance.**
- `en`: drafted.
- `zh`, `lo`, `es`, `fr`, `ru`, `de`, `ko`, `ja`: machine-quality drafts,
  **unverified** (no fluent reader has checked them). No plural messages were
  added, so Russian needed no `few`/`many` forms.

## Status "served" and staff status keys (status-finished-shared)

11 keys were added to all 10 files: `statusFinished`, `orderMarkFinished`,
`orderCheckPaidNote`, `orderCancel`, `orderCancelConfirm`,
`orderCancelPaidNote`, `orderCancelFinalNote`, `orderChangeStatus`,
`orderChangeStatusFinishedNote`, `orderChangeStatusNotAllowed`,
`orderChangeStatusCancelled`. No screen uses them yet.

- `vi`: `statusFinished` ("Đã phục vụ"), `orderMarkFinished` ("Đánh dấu đã phục vụ")
  and `orderCheckPaidNote` ("Vui lòng kiểm tra nếu đơn hàng đã được thanh toán")
  are the owner's exact words; the other 8 `vi` keys are agent drafts,
  **pending owner acceptance**.
- `en`: drafted.
- `zh`, `lo`, `es`, `fr`, `ru`, `de`, `ko`, `ja`: machine-quality drafts,
  **unverified** (no fluent reader has checked them). No plural messages.
