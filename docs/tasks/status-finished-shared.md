---
executor: task-executor
scopes: [shared]
workKinds: [flutter, documentation, quality-gate]
blockedBy: [status-finished-contract]
---

# Shared: `OrderStatus.finished`, staff headers on `updateStatus`, and the new strings in all 10 languages (additive)

Planned 2026-11-26, revised for staff-set status, the owner's check-payment text, the three-target confirmation rule and the staff session. Decisions SF1, SF8, SF10, SF12, SF13, SF14, SF18 in `status-finished-contract`. **Additive on purpose** (SF10): `ready` and `delivered` stay until the screens stop using them, so `make check` is green after this card. Independent of the backend card.

## Sources

`lib/shared/models/order.dart` (the enum at line 12, the doc comment at line 6, the Vietnamese label extension near line 255), `lib/shared/localized_labels.dart`, `lib/shared/api/order_repository.dart` (`activeOrders` line ~37, `updateStatus`, and how `confirmPayment` / `staffSwitchToCash` take `staffHeaders: Map<String, String>`), `lib/shared/api/order_api_client.dart` (`updateStatus` line ~66 and the private helper that sends `staffHeaders`, line ~121), `lib/shared/l10n/app_*.arb` (10), `lib/shared/l10n/README.md`, `test/shared/arb_completeness_test.dart`, `test/order_payment_test.dart`, `test/order_calls_test.dart`, CLAUDE.md "Languages".

## Goal

- `enum OrderStatus { awaiting_payment, preparing, ready, delivered, finished, cancelled }` for now; JSON name `finished`; unknown statuses are still skipped. Fix every exhaustive `switch` the new value breaks (the executor lists them); in screens give `finished` the behaviour of `delivered` for now.
- `OrderRepository.activeOrders` also excludes `finished`.
- **`OrderApiClient.updateStatus` / `OrderRepository.updateStatus` take `required Map<String, String> staffHeaders`**, exactly like `confirmPayment` and `staffSwitchToCash` already do (SF13). Shared code knows nothing about *what* the headers are: the restaurant passes the staff session header (`staff-login-client`), curl users the password headers. 401/403/429 map to the errors the payment calls already use. A 409 from PATCH maps to a failure the page can tell apart from a network error. No new dependency. Update the existing callers and tests to pass headers (the executor lists them); nothing in `lib/customer/` calls it.
- New keys in **all 10** ARBs, regenerated and committed:
  - `statusFinished` "Đã phục vụ"; `orderMarkFinished` "Đánh dấu đã phục vụ".
  - **`orderCheckPaidNote`: "Vui lòng kiểm tra nếu đơn hàng đã được thanh toán"** (SF18, the owner's exact words in `vi`; the other 9 are machine drafts, unverified).
  - `orderCancel` "Hủy đơn"; `orderCancelConfirm` "Hủy đơn này?"; `orderCancelPaidNote` (money may have been received, refund by hand); `orderCancelFinalNote` (a cancelled order can't be changed back).
  - `orderChangeStatus` "Đổi trạng thái" (picker button and dialog title); `orderChangeStatusFinishedNote` (a draft second line in the `finished` dialog: "changes the monthly report", SF15); `orderChangeStatusNotAllowed` and `orderChangeStatusCancelled` for the 409 cases if no existing key fits. **No generic "change status to X?" confirmation key**: the owner confirms only `paid`, `finished` and `cancelled` (SF14).
  - `orderPayChip`-style key for the staff-only "Chưa thanh toán" chip on a **cash** `awaiting_payment` order only if the existing "Chưa thanh toán" key doesn't fit (it should; the executor reuses it).
  - Reuse existing Yes/No/failure keys where they exist; the executor lists what it reused.
- The 9 non-vi texts are machine drafts: record "unverified" in `lib/shared/l10n/README.md`; the review log is `status-finished-docs`.

## Non-goals

Removing any old value or key (`status-finished-shared-cleanup`). Using the keys in a screen. Backend text (LANG6). Anything about the login session (`staff-login-*`).

## Tests written with the change

- model: `finished` JSON round trip; unknown status skipped; `ready`/`delivered` still parse (until cleanup).
- `OrderStatus.finished.localized` is "Đã phục vụ" in `vi` and non-empty in all 10 locales; `orderCheckPaidNote` in `vi` is exactly the owner's sentence and non-empty in all 10.
- `activeOrders` leaves out `finished` and `cancelled`.
- `updateStatus` (fake HTTP client): sends the given headers and `{"status": ...}`, never logs or prints the header values; 401, 403, 429 (with `Retry-After`) map like the payment calls; 409 and 400 map to distinct failures.
- `arb_completeness_test.dart` passes unchanged.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, no import-boundary break | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Header values never appear in a log, error text or `toString` | `code-reviewer` (review) |
| Generated l10n files in sync and committed | `make test`, `make analyze` (gates), `code-reviewer` |
| The two owner sentences are exact | the tests above, plus `code-reviewer` against the requests quoted in `status-finished-contract` |
| Wording of the machine drafts and the new vi helper lines | owner acceptance, "unverified" until a fluent speaker checks |
