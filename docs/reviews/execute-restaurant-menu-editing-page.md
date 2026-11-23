---
task: restaurant-menu-editing-page
status: passed
p0: 0
p1: 0
---

# Review: restaurant-menu-editing-page

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | restaurant imports only `shared/` and `restaurant/` |
| `make test` | 0 | 590 tests (29 new: 14 in `test/menu_admin_state_test.dart`, 15 in `test/menu_edit_page_test.dart`) |
| `make backend-analyze` / `make backend-test` | 0 / 0 | (implementer run; no backend change) |
| `make analyze` / `make check` | 2 | 22 infos, all `deprecated_member_use` on the `package:flutter/material.dart` import: the 20 known plus one for each of the two new files importing material (`menu_edit_page.dart`, `menu_edit_page_test.dart`). No other kind of finding; `pubspec.yaml` and `pubspec.lock` untouched |

## Changed paths

New: `lib/restaurant/state/menu_admin_state.dart`, `lib/restaurant/pages/menu_edit_page.dart`, `test/menu_admin_state_test.dart`, `test/menu_edit_page_test.dart`. Changed: `lib/restaurant/pages/orders_page.dart` (AppBar button "Chỉnh sửa thực đơn", plain `Navigator.push`; chime, badge and snackbar logic and existing tests untouched), the active card (deviation note). Not touched: `backend/`, `CLAUDE.md`, `.github`, `Makefile`, `tool`, `dev`, `deploy`, `.claude`, pubspec files.

## What it does

`MenuAdminState` (plain `ChangeNotifier`) loads the menu (loading/loaded/failed, retry, second load while loading ignored) and saves price or sold-out through `MenuAdminClient`; the item is replaced from the server reply, never optimistically; staff ID and password come only from `StaffCredentialsHolder` (memory). 401 clears the holder and re-prompts ("Sai mã nhân viên hoặc mật khẩu"), 403/429 (with a validated `Retry-After`)/404/400/other have fixed Vietnamese texts, no server body is echoed. Price input: digits only, 0 to 1,000,000, checked before sending. `MenuEditPage` rows show name, `formatVnd` price, "Còn hàng"/"Hết hàng", an edit-price button and a switch; controls are disabled while a row saves.

## Findings

Code review: P0 0, P1 0, P2 4. Security review (`docs/reviews/security-restaurant-menu-editing-page.md`): P0 0, P1 0, P2 3. Deferred P2 follow-ups:
1. The save-error banner is the first child of the `ListView`, so on a long menu a failed save can be off-screen above the toggled row (pin it above the list or use a `SnackBar` like `OrdersPage`).
2. `_saving` is per item, so two different rows can save at once with wrong credentials: two PATCHes burn lockout attempts and two login dialogs can stack (serialise with one busy flag or a single in-flight prompt).
3. No client-side cooldown after a 429 (the server refuses during the lockout either way).
4. The page builds its own `OrderApiClient` and `MenuAdminClient` and never closes them; neither has a `close()` and `OrderRepository`/`MenuState` do the same, impact on the browser build is negligible (add `MenuAdminClient.close()` or a comment).
5. Test gaps: no long-name item at 360 px / text scale 2.0; the page tests have no 400/404/network-error case nor re-login succeeding after a 401; the no-secrets test cancels the dialog first (add a unit test that `MenuAdminException.message`/`toString()` contain neither secret and that the holder is null after a 401); the "reply after dispose" test asserts nothing explicit; leading zeros ("0007") are accepted as 7 (harmless).
6. Accessibility: whether the switch's label merges cleanly with its on/off semantics needs a screen reader (TalkBack/VoiceOver) or `tester.getSemantics`.

Deviation: "two decimals" in the card is a leftover from the USD era; `formatVnd` is correct (recorded in the card).

## Unverified (owner acceptance)

Vietnamese wording and layout at `http://restaurant.local` and on the staff tablet/phone; a real PATCH through Caddy with `STAFF_ID`/`STAFF_PASSWORD` set, the new price and sold-out state showing on `customer.local` after a reload, and the "editing disabled" (403) case with the variables unset; a screen reader on the switch and the icon button.

## Verdict

**Passed**, P0: 0, P1: 0.
