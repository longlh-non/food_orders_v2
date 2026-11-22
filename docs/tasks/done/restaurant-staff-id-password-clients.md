---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [backend-staff-id-password-gate]
securityReview: required
---

# Restaurant app: send the staff ID + password (clients, holder, export dialog)

Follows the contract in `CLAUDE.md` as changed by `backend-staff-id-password-gate`. Read that card first. Nothing under `backend/`, `CLAUDE.md`, `dev/**` or `.github/**` changes here.

## Design (plain words)

- **Holder.** Rename `lib/restaurant/state/staff_token.dart` to `staff_credentials.dart`. A small immutable class `StaffCredentials(id, password)` and `StaffCredentialsHolder.instance` (still a plain singleton, memory only: lost on reload, never in `localStorage`, cookies or the URL). `restaurant-menu-editing-page` reuses this one holder; no second one.
- **Clients.** `MenuAdminClient.updateItem(..., credentials:)` and `ExportClient.fetchMonth(month, credentials:)` send headers `X-Staff-Id` and `X-Staff-Password` (never the URL, never a body). Existing exception kinds stay: 401 wrong, 403 disabled; add 429 "too many tries" (read `Retry-After` for the message; the text is fixed Vietnamese/English per the file's current language, no server text shown). Exceptions, `toString` and error messages never contain the ID or password.
- **Validation before sending.** ID 1..64 and password 12+ characters are NOT enforced client-side beyond "not empty" and "printable ASCII" (the server decides length; the ASCII check avoids a browser header error that would look like a network failure).
- **Dialog.** `export_month_dialog.dart` gets two fields: "Staff ID" (plain) and "Staff password" (obscured, not pre-filled from anything but the in-memory holder, as the token field is today). A 401 clears BOTH and says "Wrong staff ID or password" (one message; the server doesn't say which). 403 and 429 get their own messages. The password is never shown in any message.
- **Autofill: off (recommended).** No `autofillHints`, no `AutofillGroup`, `enableSuggestions: false`, `autocorrect: false`. Reason: the memory-only rule was deliberate (tablet/phone possibly shared), and letting the browser's password manager save it would store the shared password on every device used. Owner can reverse this later; open decision below.

## Sources

`lib/restaurant/api/menu_admin_client.dart`, `lib/restaurant/api/export_client.dart`, `lib/restaurant/state/staff_token.dart`, `lib/restaurant/pages/export_month_dialog.dart`, `test/menu_admin_client_test.dart`, `test/export_month_test.dart`.

## Non-goals

Menu editing page (own card), backend, remembering credentials, login screen, per-person accounts, changes to `lib/shared/` or customer code.

## Tests written with the change (`MockClient`, no network, fake values built in the test)

- Clients: both headers sent with exact values; no `X-Staff-Token`; credentials absent from URL and body; 401, 403, 429 (with and without `Retry-After`) map to the right exception; exception `toString` and message contain neither value.
- Holder: starts empty; set, read, clear.
- Dialog (widget): two fields exist, the password is obscured, the ID is not; submit with an empty ID or password does not call the client; a successful call stores both in the holder and the dialog prefills next time; 401 clears both and shows the single wrong-ID-or-password message; 429 and 403 messages; neither value is found in any `Text` in the widget tree after success or failure; non-ASCII input is rejected before sending; autofill hints are absent.
- Existing export and menu-client tests updated, not deleted.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Tests above pass | `make test` (gate) |
| Analyzer, format, boundaries clean | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Credentials only in memory and request headers; never in logs, errors, URLs, widget tree; 401 clears both; autofill off | `security-reviewer` (review; `security-restaurant-staff-id-password-clients.md`) |
| No new dependency; restaurant imports nothing from customer | `code-reviewer` (empty `pubspec.yaml` diff), `make boundaries` |
| `make check` green | `make check` exit 0 (gate) |
| Backend started with `STAFF_ID` and `STAFF_PASSWORD`: on `restaurant.local` the month export downloads; wrong ID gives "Wrong staff ID or password"; wrong password gives the same message; 5 wrong tries then the "too many tries" message | owner acceptance in the real environment - "unverified" until done |
| Backend started without the vars: export says disabled | owner acceptance in the real environment |

## Environment limits

Agents cannot run the browser or the real backend. The owner starts the backend with the new variables.

## Decided by the owner (2026-11-19)

Every recommendation was accepted:
- **`STAFF_ID`:** 1–64 characters.
- **`STAFF_PASSWORD`:** at least 12 characters.
- Both trimmed, printable ASCII only, stored as plain text in the env, with no hash.
- **Headers:** `X-Staff-Id` and `X-Staff-Password`, never `Authorization`/Basic.
- **Comparison:** constant time, with one fixed 401 that doesn't say which half was wrong.
- **Lockout:** global, in memory. After 5 failures in 60 s, every staff request gets 429 with `Retry-After` for 60 s. The deliberate lock-out risk is accepted.
- **Clean switch:** `STAFF_TOKEN` and `X-Staff-Token` stop working, and the backend prints a hint if `STAFF_TOKEN` is still set.
- **No browser password manager or autofill.**

## Executor notes (2026-11-19)

- **Holder:** `lib/restaurant/state/staff_token.dart` is deleted (it was never committed) and replaced by `staff_credentials.dart`:
  - `StaffCredentials(id, password)`, with a `headers` getter (`X-Staff-Id`, `X-Staff-Password`), an `isSendable` check (non-empty printable ASCII) and a `toString` that hides both values;
  - `StaffCredentialsHolder.instance`, in memory only.
- **Clients:** `ExportClient.fetchMonth(month, {credentials})` and `MenuAdminClient.updateItem(id, {credentials, …})`.
  - Credentials that aren't sendable throw `ArgumentError` before anything is sent.
  - The failure kind `wrongToken` is renamed `wrongCredentials`, and a new `tooManyTries` (429) carries `retryAfterSeconds` from `Retry-After`.
- **Dialog:**
  - "Staff ID" (plain) and "Staff password" (obscured) fields, both without autofill or suggestions;
  - Download is enabled only when both are filled;
  - accented input gets "Use plain letters, digits and symbols, no accents" before sending;
  - 401 → "Wrong staff ID or password", clearing both fields and the holder;
  - 429 → "Too many wrong tries. Try again in N seconds." (or "later" without `Retry-After`).
- **New English strings for `vi-translate-shared-and-restaurant-ui`:** "Staff ID", "Staff password", "Wrong staff ID or password", "Too many wrong tries. Try again in N seconds." / "…later.", "Use plain letters, digits and symbols, no accents" ("Staff token" and "Wrong staff token" are gone).
