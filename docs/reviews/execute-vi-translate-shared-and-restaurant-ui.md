---
task: vi-translate-shared-and-restaurant-ui
status: passed
p0: 0
p1: 0
---

# Review: vi-translate-shared-and-restaurant-ui

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `dart format <touched files>` | 0 | reformatted 2 files (cosmetic) |
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 540/540 passed |
| `make backend-analyze` | 0 | not in scope (no backend files touched); run anyway for the record |
| `make backend-test` | 0 | not in scope; run anyway for the record |
| `make analyze` | 2 | **pre-existing, repo-wide, unrelated to this change** — see below |
| `make check` | 2 | halts at the `analyze` step above, for the same pre-existing reason |

### The `make analyze` / `make check` failure is pre-existing

`flutter analyze --fatal-infos` reports 19 `deprecated_member_use` info findings: every file in the repo that imports `package:flutter/material.dart` is told to use a nonexistent `package:material_ui/material_ui.dart` instead (Flutter SDK 3.50.1 stable, built 2026-11-18). Verified via `git stash` in this session that the identical 19 findings reproduce on unmodified `main`, before this change existed. The owner was told and said to note it and continue — not scored against this or any other card in this batch. None of the 19 flagged lines are inside the files this card touches beyond the same generic import-line notice every file in the repo receives.

## Changed paths

`lib/restaurant/main.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `lib/restaurant/pages/orders_page.dart`, `lib/restaurant/widgets/staff_login_dialog.dart`, `lib/shared/models/order.dart`, `test/export_month_test.dart`, `test/menu_page_test.dart` (assertion only, no `lib/customer/**` source touched), `test/order_payment_test.dart`, `test/orders_page_test.dart`, `test/widget_test.dart`.

## Review (code-reviewer)

Independent `code-reviewer` pass confirmed: diff stays inside `scopes: [shared, restaurant]`; every English UI string in the in-scope files (including `staff_login_dialog.dart`, which wasn't in the card's original stale inventory but is correctly in-scope restaurant work) is translated; `OrderStatus` enum names and JSON wire values are untouched (`toJson` still writes `status.name`); interpolation preserved; the `Row`→`Wrap` layout fix for the longer Vietnamese action-button label is sound and matches an existing in-file pattern, validated by a pre-existing narrow-width test; all three required new/updated tests are present and pass; no new dependency.

Findings: **P0: 0, P1: 0, P2: 3** (all deferred as owner-facing polish, see below).

### P2 findings (deferred)

1. `lib/restaurant/pages/orders_page.dart:503-518` — `Wrap` with `WrapAlignment.spaceBetween` loses the previous right-alignment of the action button once it wraps to its own line (a single-child run ignores `spaceBetween`). Cosmetic only, no overflow, no test regression. Follow-up: owner to eyeball at narrow width in the browser; fix (if wanted) is a one-line alignment tweak.
2. `lib/restaurant/main.dart:26` vs `orders_page.dart:326` — inconsistent capitalization style between the app title ("Đặt Món — Nhà hàng") and the AppBar title ("Danh sách đơn hàng"). Stylistic; owner's wording call.
3. `lib/restaurant/widgets/staff_login_dialog.dart:19` — the translated default dialog title has no test asserting it renders. Minor coverage gap; not required by the card's acceptance criteria.

## Acceptance criteria

| Criterion | Status |
|---|---|
| No English UI text left in the listed files | Met — code-reviewer confirmed, plus the newly-discovered in-scope files (export dialog, staff login dialog, status-update-failure/new-order snackbars) |
| Status chips and action buttons show Vietnamese in the restaurant app | Met — `make test` |
| Boundaries intact, no new dependency | Met — `make boundaries` exit 0, `pubspec.yaml`/`pubspec.lock` diff empty |
| `make check` green | **Not met end-to-end** — halts at the pre-existing, unrelated `analyze` failure (see above); every other step is green |
| Vietnamese wording acceptable, diacritics render correctly | **Unverified** — owner acceptance in browser, not done yet |
| Same on iPhone Safari | **Unverified** — optional, not done |

## Verdict

**Passed**, P0: 0, P1: 0. The three P2 findings are deferred as owner-facing follow-ups (wording/alignment polish, one missing dialog-title test) rather than blockers. The `make check` gap is solely the pre-existing, repo-wide Flutter SDK deprecation issue (tracked separately, not caused by or fixable within this card). Browser/phone wording acceptance remains unverified per the card's own environment limits.
