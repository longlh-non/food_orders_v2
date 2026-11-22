---
task: restaurant-confirm-bank-transfer
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-confirm-bank-transfer

Date: 2026-11-20. Reviewer: `security-reviewer` (independent, read-only, first pass). It did not see the code review, and reviewed the original candidate (before the code review's P1 fix round, which touched only the chime/snackbar sequencing in `orders_page.dart` and added tests — nothing in the credential or request path it reviewed).

## Scope

`lib/restaurant/pages/orders_page.dart` (two staff payment buttons sending `X-Staff-Id`/`X-Staff-Password` via the already-reviewed `lib/shared/api/order_repository.dart` methods), `lib/restaurant/widgets/staff_login_dialog.dart` (new, credential-entry only, no network call), `test/orders_page_test.dart`.

## Gates

See `docs/reviews/execute-restaurant-confirm-bank-transfer.md`. The final `make check` exited 0 (orchestrator, this session; Flutter +537, backend +524).

## Findings

P0: none. P1: none.

**P2 (informational, not blocking):** a one-tap button now makes the already-gated, already-reviewed staff routes reachable from the restaurant UI without hand-crafting a request. This slightly lowers the effort to trigger the existing accepted 5-wrong-tries lockout (CLAUDE.md: "a nuisance, not a breach") — one click instead of a curl command. Not a regression in severity, just a lower bar to reach an already-accepted nuisance. No fix required.

## Checked and clean (summary)

- **Credentials never leak:** `StaffCredentials.headers` produces only the two header values; `toString()` hides them; `_WrongCredentials`, `_payOutcomeText` and every `OrderRequestException` message are fixed strings with no server text or credential value. `staff_login_dialog.dart` makes no network call at all.
- **401 handling:** clearing the holder and re-prompting requires a new manual interaction each time — no scriptable retry loop faster than a human; the fixed message never says which half was wrong, matching the CLAUDE.md contract. Server-side rate limiting is unchanged and already accepted.
- **`isSendable`** correctly rejects non-ASCII, control characters and CR/LF before any value reaches a header, confirmed by the diff's own "accent refused" test.
- **No id-tampering surface:** both buttons are bound to `orders[i].id` from `OrderRepository.instance.orders` (server truth); staff cannot type an arbitrary id through this UI.
- **No new double-submit path:** `_busyPaymentIds` is set before the first `await`, disabling both buttons for that order through the whole flow; the backend's conditional updates are the real backstop (already reviewed and archived).
- **The reference-collision note** (carried from `backend-payment-qr-endpoint`'s security review) is satisfied: the order id suffix, customer name, transfer reference and full total are all already shown right next to the new buttons, with no change needed.
- **No new dependency**, nothing added to `.claude/`, `dev/**`, CI, or the Makefile.

## Unverified (owner acceptance)

Live staff login flow end to end (401/429/403/409 from the real backend).
