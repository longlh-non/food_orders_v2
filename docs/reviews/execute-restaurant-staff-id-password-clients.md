---
task: restaurant-staff-id-password-clients
status: passed
p0: 0
p1: 0
---

# Review: restaurant-staff-id-password-clients

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-restaurant-staff-id-password-clients.md`.

## Candidate

- **`lib/restaurant/state/staff_credentials.dart`** (new; replaces the uncommitted `staff_token.dart`):
  - `StaffCredentials(id, password)` with `headers` (`X-Staff-Id`, `X-Staff-Password`), `isSendable` (non-empty printable ASCII) and a `toString` that hides the values;
  - `StaffCredentialsHolder.instance`, memory only;
  - `retryAfterSeconds()` (1..3600 or null).
- **`lib/restaurant/api/export_client.dart`, `menu_admin_client.dart`:**
  - take `credentials`, refused before sending when not sendable;
  - send them only in headers;
  - `wrongToken` → `wrongCredentials`; a new `tooManyTries` (429) with `retryAfterSeconds`.
- **`lib/restaurant/pages/export_month_dialog.dart`:**
  - "Staff ID" (plain) and "Staff password" (obscured) fields, no autofill;
  - Download only when both are filled;
  - accented input refused before sending;
  - 401 → "Wrong staff ID or password" and clears both;
  - 429 → "Too many wrong tries. Try again in N seconds." / "…later.".
- **Tests:** `test/export_month_test.dart`, `test/menu_admin_client_test.dart` (updated), `test/staff_credentials_test.dart` (new).

## Round 1: changes requested. P0 0, P1 1, P2 5

- **P1:** `ExportClient` had no 429 test with and without `Retry-After`, and the dialog's "Try again later." branch was untested. **Fixed:**
  - a client test (42, none, and the bad values -5/0/99999/soon → null);
  - a dialog test without the header.
- **P2-1:** no direct holder test. **Fixed:** `test/staff_credentials_test.dart`.
- **P2-2:** the "no values on screen" test was weak. **Fixed:** it now runs after 401/403/429/500, scans all `RichText`, and asserts the scan isn't empty. A comment says it covers messages and labels only.
- **P2-3:** stale "token" wording. **Fixed.**
- **P2-4:** `Retry-After` unbounded. **Fixed:** `retryAfterSeconds()` keeps 1..3600.
- **P2-5:** the client `ArgumentError` guard repeats the dialog check. **Kept** on purpose as defence in depth (the menu editing page will use the client directly).

## Re-review 1: passed. P0 0, P1 0, P2 1

All fixes were verified as real, with non-vacuous tests and no regressions.

- **New P2:** a doc comment in `menu_admin_client.dart` was still oddly wrapped, and two test names or comments said "token". **Fixed** before the final `make check`. This was cosmetic only, so there was no further review round.
- The test-local variable is still named `token`; that's cosmetic and left as is.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after the fixes) | 0 |
| `make test` (332 → 341 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate) | 0 |

## Unverified (owner acceptance)

The backend must be started with `STAFF_ID` and `STAFF_PASSWORD`. Then, on `restaurant.local`:
- the month export downloads;
- a wrong ID or password shows "Wrong staff ID or password";
- 5 wrong tries show "Too many wrong tries…";
- without the variables, "Export is turned off on the server";
- Chrome doesn't offer to save the password.
