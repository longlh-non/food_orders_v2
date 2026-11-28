---
task: status-finished-shared
status: passed
p0: 0
p1: 0
---

# Security review: status-finished-shared

Reviewer: security-reviewer (the card's `securityReview: required` was added because `updateStatus` now carries staff credential headers). Read-only; nothing run. **P0 0, P1 0, P2 0.**

## Checked and clean

1. **Credential leak.** `staffHeaders` goes only into the request headers, through `OrderRepository.updateStatus` to `OrderApiClient.updateStatus`; neither layer stores it. `_orderCall` builds exception messages only from a fixed label and the status code, and never copies the response body or the headers; `OrderRequestException.toString` prints only the message; `_changeStatus` catches the exception and shows a fixed text without printing it; `StaffCredentials.toString` returns `<hidden>`; the tests use fake values only.
2. **Temporary behaviour (remembered credentials or an empty map).** Today the backend ignores the headers on `PATCH`, so nothing changes. The headers go only to the relative same-origin `/api` base. Once the check is enforced, a 401, 403 or 429 is one call that ends in one generic snackbar, with no loop and no automatic retry. A repeated tap after a failure counts toward the 5-in-60-seconds lock and `_changeStatus` does not clear stored credentials on 401: a usability gap the restaurant card must close (re-prompt on 401, clear the stored credentials, no status-button loop). Recorded in the three follow-up cards. The cleartext-over-wifi weakness is the one `CLAUDE.md` already lists.
3. **Error mapping.** Status codes 400, 401, 403, 404, 409 and 429 reach the caller as distinct `statusCode` values without echoing server text; the response body is never shown or logged.
4. **Customer app.** No match in `lib/customer` for `staffHeaders`, `StaffCredentials`, `X-Staff`, `confirmPayment`, `staffSwitch` or `.updateStatus`; the only customer edits are the `finished` status checks. The staff credentials holder lives in `lib/restaurant`.
5. **Unknown status.** On the list and the stream an unknown status skips that one order; on `PATCH` the parse error becomes a request exception. `finished` is handled everywhere the compiler requires.
6. **Dependencies and secrets.** No new dependency; no secret in the new strings or tests.

## Needs confirmation in a real environment

Once the backend enforces the staff check on `PATCH`: an unauthenticated status tap gives the generic failure and no retry; the login-screen card clears the stored credentials on 401.
