---
task: status-finished-shared
status: passed
p0: 0
p1: 0
---

# Review: status-finished-shared

Changed (Dart and ARB, additive): `lib/shared/models/order.dart` (`OrderStatus.finished`, doc comment), `lib/shared/localized_labels.dart`, `lib/shared/api/order_api_client.dart` and `order_repository.dart` (`updateStatus` takes `required staffHeaders`; `activeOrders` excludes `finished`), 11 new keys in all 10 `lib/shared/l10n/app_*.arb` files with the regenerated `app_localizations*.dart`, `lib/shared/l10n/README.md` (an "unverified" entry), three small edits outside shared that keep the apps compiling and behaving as today (`lib/restaurant/pages/orders_page.dart` `_changeStatus` call, `lib/customer/pages/payment_qr_page.dart` switch case, `lib/customer/pages/menu_page.dart` active-orders filter), and the tests (`test/order_status_finished_test.dart` new; `test/order_calls_test.dart` and `test/menu_client_test.dart` updated for the new argument). `ready` and `delivered` stay in the enum until `status-finished-shared-cleanup`. The card's `securityReview: required` was added before the reviews (the change carries staff credential headers).

## Gates

| Command | Exit | Note |
|---|---|---|
| `make format-check` | 0 | after the last fixes |
| `make boundaries` | 0 | after the last fixes |
| `make analyze` | 2 | 30 infos, the same pre-existing `deprecated_member_use` baseline as before the change; no issue added |
| `make test` | 0 | 774 tests |
| `make backend-analyze` | 0 | backend untouched |
| `make backend-test` | 0 | backend untouched |
| `make check` | 2 | stops at `make analyze` on the baseline above; the later gates were run separately (rows above). Not claimed as passed. |

## code-reviewer: P0 0, P1 0, P2 3, all fixed

- **Fixed:** the temporary "empty headers" state of `_changeStatus` was recorded only in a code comment. A note was added to `status-finished-backend`, `status-finished-restaurant` and `staff-login-restaurant`: handling 401/403/429 on the status-change path (re-prompt or back to login, clear stored credentials, never loop on a 401 into the lock) belongs to the restaurant card, and the backend check must not be deployed before it ships.
- **Fixed:** the enum doc comment now mentions `finished` and that `ready`/`delivered` stay until the cleanup task.
- **Fixed:** a test comment says `Retry-After` is deliberately not read (the payment calls ignore it too).

Checked and clean: every Goal item done, nothing from Non-goals done; every exhaustive switch fixed; header values can never reach an error message, `toString`, a log or `print`/`debugPrint` (tested with fake values); all 11 keys in all 10 files, the owner's exact Vietnamese sentences ("Đã phục vụ", "Đánh dấu đã phục vụ", "Vui lòng kiểm tra nếu đơn hàng đã được thanh toán") pinned by a test; no new dependency; no import-boundary break.

## Security review: see `security-status-finished-shared.md`.

## Unverified (owner acceptance)

The Vietnamese helper lines and the nine other languages (machine drafts, README marks them unverified); how the status-change call behaves against the real backend once the staff check is enforced (the backend card is not done); the restaurant screens in a real browser.
