---
task: restaurant-confirm-bank-transfer
status: passed
p0: 0
p1: 0
---

# Execute review: restaurant-confirm-bank-transfer

Date: 2026-11-20. Reviewer: `code-reviewer` (independent, read-only). The security review is in `docs/reviews/security-restaurant-confirm-bank-transfer.md`; neither reviewer saw the other's conclusions.

## Candidate

- `lib/restaurant/pages/orders_page.dart`: two staff payment buttons on each order card.
  - **"Đã nhận chuyển khoản"** (`PaymentAction.confirm`): only while an order is still live (`awaiting_payment`, not expired).
  - **"Chuyển sang tiền mặt"** (`PaymentAction.switchToCash`): on a live order or an expired one (PAY13, no staff time limit). Never on any other status.
  - Credentials: silent when `StaffCredentialsHolder` already has sendable ones; otherwise `showStaffLoginDialog`. A 401 clears the holder and asks again. 403/429/409/other map to fixed Vietnamese texts; a 409 re-reads the repository (`OrderRepository.refresh()`).
  - `_busyPaymentIds` disables both buttons for an order while a request for it is in flight.
- `lib/restaurant/widgets/staff_login_dialog.dart` (new): `showStaffLoginDialog` — gathers and validates (`StaffCredentials.isSendable`) the staff ID and password; sends no request itself, so it's reusable later (e.g. `restaurant-menu-editing-page`). `export_month_dialog.dart` is deliberately left un-migrated, as the card allows.
- `test/orders_page_test.dart`: a new "staff payment buttons" group plus one pre-existing-group addition (short-id title fix carried from the prior card's review).

## Gates

| Command | Exit code | Output tail | Run by |
|---|---|---|---|
| `make analyze` | 0 | `No issues found!` | executor (first round) |
| `make test` | 0 | `+536: All tests passed!` (first round); `+537` after fix round 1 (one net new test) | executor / orchestrator |
| `make boundaries` | 0 | `boundaries: ok` | executor (first round) |
| `make format-check` | 0 | `Formatted 77 files (0 changed)` | executor (first round) |
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+537`, backend `+524: All tests passed!` | orchestrator, this session, final candidate |

## Findings

P0: none. P1 (round 1 only; closed): see below.

**First round confirmed correct (no issue):**
- The button-visibility state machine matches the card exactly: live `awaiting_payment` → both buttons; expired (`expiredUnpaid` or locally-lapsed, no staff time limit, "even days later") → only switch-to-cash; everything else → neither. The renewal transition re-derives correctly from current status.
- Credentials flow: remembered+sendable → silent single request; missing/unsendable → dialog; 401 → clear + loop + fresh dialog with `initialError`. The "close dialog then reopen on 401" pattern is acceptable — the per-order `busy` flag blocks re-tapping during the gap, so there's no stale-state exposure.
- No credential leakage anywhere: `_WrongCredentials` carries no data, `OrderRequestException.message`/`statusCode` never shown, `StaffCredentials.toString()` stays `<hidden>`.
- Error-code mapping matches the card's required texts exactly; no shared file was touched for the 429 text (the repository exception correctly has no `Retry-After`).
- Every `await` followed by context use is guarded by `mounted`.
- No `lib/customer` import (invariant 1); `showStaffLoginDialog` correctly scoped to `lib/restaurant/widgets/`, not `lib/shared/` (invariant 6, per the card's explicit instruction). No new dependency.
- The pre-existing chime/badge logic (`_onRepoChanged`, `_awaitingUnrung`, `_scheduleExpiry`) is untouched; a successful staff action legitimately rings the existing "paid" chime once, and revived/renewed orders still never double-chime.

**First-round P1, fixed in round 1 — see "Fix round 1 and Re-review 1" below.**

**First-round P2, resolved in round 1:**
1. Five tests left a pending expiry `Timer` without the file's usual `pumpWidget(SizedBox())` cleanup. Fixed: all five now have it.
2. The busy/double-tap guard was correct by inspection but untested. Fixed: a new test holds the first POST open with a `Completer`, taps both buttons again, and asserts exactly one request went out.
3. Gate evidence given to the first-round reviewer was a one-line exit-code summary. Fixed: full raw tails are now in this report and were given to the re-review.
4. The staff-login dialog's text stays English while the new payment-outcome texts are Vietnamese — matches the pre-existing `export_month_dialog.dart` split, not a regression. **Deferred, noted for `vi-translate-customer-ui` / `vi-translate-shared-and-restaurant-ui`.**

## Fix round 1 and Re-review 1

**P1 (code review): a 409-conflict snackbar could be silently overwritten.** `_doPaymentAction`'s conflict branch called `OrderRepository.instance.refresh()` fire-and-forget (`unawaited`), then immediately showed "Đơn này đã được xử lý". If the refreshed order came back `preparing` for an id the page had seeded as `awaiting_payment` (exactly the card's own scenario — "staff did on another device"), the pre-existing chime/snackbar logic (`_onRepoChanged`) would ring and show its own "New order from …" snackbar, racing with and replacing the conflict message. The first-round test dodged this by refreshing to `ready` instead of `preparing`, so the race was never exercised.

**Fix:** the refresh is now `await`ed before the conflict snackbar is shown, so the chime (a genuine signal of real new work) still rings first, but the direct answer to the staff member's tap is always the last thing left on screen. The test was rewritten to use the realistic `preparing` transition and assert both: the chime rings once, and the final visible text is the conflict message, not "New order from …".

The re-review traced the new sequencing (relying on `refresh()`'s synchronous `notifyListeners()` inside its own async body, before its Future resolves) and confirmed the fix is correct, introduces no new issue with the busy flag or `mounted` guards, and that the P2 fixes are each correct as described. **Verdict: passed (P0 0, P1 0), no new findings.**

| Command (final candidate) | Exit code | Output tail |
|---|---|---|
| `make check` | 0 | `0 changed`, `boundaries: ok`, analyze clean, Flutter `+537: All tests passed!`, backend `+524: All tests passed!` |

Card moved to `docs/tasks/done/`.

## Unverified (owner acceptance)

Live: place transfer orders from the customer app; confirm one, switch one to cash, let one expire and switch it to cash, let one expire and renew it from the customer phone — the customer page and this screen should show each result.
