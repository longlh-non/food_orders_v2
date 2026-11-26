---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [staff-login-backend]
securityReview: required
---

# Restaurant client: the session (login, logout, storage) and the export call that still needs the password

Planned 2026-11-26. Decisions SL-b, SL-d, SL-f, SL-g, SL-j in `staff-login-contract`. **Nothing here goes into `lib/shared/`** (invariant 2: only the restaurant needs it, and the customer app must never carry staff code). Shared code already takes a `Map<String, String> staffHeaders` for its staff calls (`confirmPayment`, `staffSwitchToCash`, and `updateStatus` from `status-finished-shared`), so the session only has to **produce** that map. No screens in this card. Security review is required: token storage.

## Sources

`lib/restaurant/state/staff_credentials.dart` (`StaffCredentials`, `StaffCredentialsHolder`, `retryAfterSeconds`), `lib/restaurant/api/export_client.dart`, `menu_admin_client.dart`, `lib/restaurant/state/menu_admin_state.dart`, `lib/shared/locale_storage*.dart` (the conditional-export `localStorage` pattern to copy), `lib/restaurant/download/save_file*.dart` (another conditional export), `pubspec.yaml` (`http` and `web` already there; **no new dependency**; `shared_preferences` stays unapproved).

## Goal

- `lib/restaurant/api/staff_session_client.dart`: `StaffSessionClient({http.Client? client})` with `login(StaffCredentials, {String? deviceLabel})` -> `StaffSession` and `logout(StaffSession)`; `POST /api/staff/login` and `POST /api/staff/logout`. A failure type like `ExportFailure`: `wrongCredentials` (401), `disabled` (403), `tooManyTries` (429, with `retryAfterSeconds`), `invalid` (400), `other` (no answer, 5xx, unreadable reply). Messages for developers only; never the typed values, the token or the reply text. A reply that isn't `{token: non-empty string, expiresAt: parseable UTC date}` is `other`. Throws `ArgumentError` (nothing sent) when the credentials aren't sendable (reuse `isSendable`) or the label has control characters / is longer than 40.
- `StaffSession` (token, expiresAt, plus `headers` -> `{'X-Staff-Session': token}`; `toString` prints `<hidden>`; no `==` on the token needed).
- `lib/restaurant/state/staff_session_controller.dart`: `StaffSessionController extends ChangeNotifier`, singleton like the other state classes: `session` (or null), `signedIn`, `Map<String, String> get headers` (empty-safe: throws or returns null when signed out, caller checks), `signIn(session)` (stores, notifies), `signOut({bool tellServer = true})` (clears memory and storage first, notifies, then best-effort `POST /staff/logout`; a failed call changes nothing visible), `endLocally()` for a 401 from any call (clears, notifies, no server call), `init()` read from storage (called in `main()` before `runApp`, like `LocaleController.init`): a stored value that is unreadable, malformed or **already expired by the phone clock** is deleted and means signed out. The phone clock is used only to drop an obviously expired session early; the server decides.
- Storage: conditional export `staff_session_storage.dart` -> `_web.dart` (`window.localStorage`, key `food_orders_staff_session`, a small JSON `{token, expiresAt}`) / `_stub.dart` (VM: keeps nothing). Blocked or full storage: the session lives in memory only until reload; no crash.
- `StaffCredentialsHolder` is **removed** once nothing uses it (this card plus `staff-login-restaurant`); keep `StaffCredentials` (login and export) and `retryAfterSeconds`. The executor lists every use; callers move in `staff-login-restaurant`, so **keep the holder here** and mark it deprecated in a comment, then delete it in `staff-login-restaurant`.
- `ExportClient.fetchMonth` is **unchanged**: it keeps taking `StaffCredentials` and sending the password headers; its 401 means a wrong password and **must not** end the session (add a test and a doc comment). Its doc comments are updated to say the password is asked every time.
- `MenuAdminClient.updateItem` / `addItem` take the headers map (`Map<String, String> staffHeaders`) instead of `StaffCredentials`; 401 stays `wrongCredentials` (the state layer turns it into `endLocally()`, done in `staff-login-restaurant`).

## Non-goals

Any screen, ARB text, backend code, a refresh token, cookies, anything in `lib/shared/` or `lib/customer/`.

## Tests written with the change

- `StaffSessionClient` (fake HTTP client): login sends exactly `{"id","password"}` (+ label when given) to `/api/staff/login` and returns the session; 401, 403, 429 (with `Retry-After`), 400, 500 and a malformed 200 map to the right failures; nothing typed, no token and no reply text appears in any exception `toString` / `message`; logout sends only the session header to `/api/staff/logout`, and a 401 or a network error on logout doesn't throw to the caller.
- controller: `signIn` stores and notifies once; `signOut` clears memory and storage **before** the server call and notifies, even when the call fails; `endLocally` clears and notifies without a request; `init` with expired / malformed / empty storage leaves it signed out and deletes the bad value; with a good value it is signed in; a second controller instance (a reload) reads the same value (fake storage).
- `toString` of `StaffSession` and the controller never shows the token.
- export: a 401 from `fetchMonth` throws `ExportFailure.wrongCredentials` and leaves a signed-in controller signed in (the dialog test is in the UI card; the client-level contract is tested here).
- `make boundaries`: nothing in `lib/shared/` or `lib/customer/` imports the new files.
- The web storage implementation is not run by `flutter test`; compile check `flutter build web -t lib/restaurant/main.dart` (exit code recorded in the review).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, boundaries | `make analyze`, `make format-check`, `make boundaries` (gates) |
| Web build compiles | `flutter build web -t lib/restaurant/main.dart` exit 0 (recorded) |
| The token is never logged, printed, put in a URL, an error or `toString` | `security-reviewer`, `code-reviewer` (reviews) |
| No new dependency; nothing staff-related in `shared/` or `customer/` | `code-reviewer` (review) |
| The session really survives a reload in Chrome and is gone after logout | owner acceptance, "unverified" until done |
