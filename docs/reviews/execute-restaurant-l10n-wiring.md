---
task: restaurant-l10n-wiring
status: passed
p0: 0
p1: 0
---

# Review: restaurant-l10n-wiring

No new ARB keys were needed: the 65 restaurant keys seeded by `shared-l10n-infrastructure` covered every string. The status/payment label extensions moved from `lib/customer/localized_labels.dart` to `lib/shared/localized_labels.dart` (renamed `OrderStatusText`, `PaymentMethodText`); customer imports updated.

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` / `make check` | 2 | 28 `deprecated_member_use` infos: 27 baseline + 1 `flutter/material.dart` import in new `test/restaurant_l10n_test.dart`. No new kind of finding. `make check` stops at analyze; the other gates were run separately. |

## Findings (code-reviewer): P0 0, P1 0, P2 4 — deferred

1. `lib/shared/models/order.dart:253-265`: `OrderStatus.label` / `PaymentMethod.label` still hold Vietnamese literals. Dead in `lib/` (only tests reference them: `test/order_payment_test.dart:169-188`, `test/orders_page_test.dart:178`). Follow-up: delete and point those tests at `.localized(...)`.
2. `staff_login_dialog.dart:8,16` and `orders_page.dart:426`: comment wording/length leftovers.
3. `staff_login_dialog.dart:22-25`: `initialError` is a pre-translated string, so a language change while that dialog shows a 401 message leaves it in the old language (edge case; picker is behind the dialog).
4. Test gaps: no staff-login-title locale switch test; no 429 `tooManyTriesWait` test in the export dialog under a non-vi locale.

Vietnamese parity: reviewer compared values with existing tests; orchestrator additionally checked `menuInStockSemantics`, `menuPriceLabel`, `menuLoadFailed`, `orderUpdateFailed` against `git show HEAD` sources: identical. `MenuSaveError` mapping covers all six values; state has no text or `BuildContext`; `formatVnd`/`transferReference` untouched; picker in the OrdersPage AppBar; `onGenerateTitle` set; `pubspec.*`, `web/`, ARBs untouched by this card.

## Unverified (owner acceptance)

All 10 languages in a browser (Lao/CJK glyphs, layout at real phone width, picker); tab title; wording of the 8 drafted languages; chime; demo split view. Fit tests use the Ahem font and catch overflow exceptions only.

## Verdict

**Passed**, P0: 0, P1: 0.
