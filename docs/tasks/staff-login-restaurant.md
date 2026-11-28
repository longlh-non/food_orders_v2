---
executor: task-executor
scopes: [restaurant]
workKinds: [flutter, quality-gate]
blockedBy: [staff-login-client, staff-login-l10n, status-finished-shared]
securityReview: required
---

# Restaurant UI: login screen, logout, the session on every staff action, and the export that still asks the password

Planned 2026-11-26. Decisions SL-d, SL-e, SL-f, SL-g, SL-j in `staff-login-contract`. Runs **before** `status-finished-restaurant`, which then reuses the helper built here. Security review is required: it replaces every credential prompt.

## Sources

`lib/restaurant/main.dart` (`RestaurantApp`, `home: OrdersPage`), `lib/restaurant/pages/orders_page.dart` (`_changeStatus` ~242, `_sendPaymentAction`, `_doPaymentAction` ~256-343, the AppBar), `lib/restaurant/pages/menu_edit_page.dart` (lines ~18, ~59-65), `lib/restaurant/state/menu_admin_state.dart`, `lib/restaurant/pages/export_month_dialog.dart` (credential fields, `StaffCredentialsHolder` use, 401 handling), `lib/restaurant/widgets/staff_login_dialog.dart`, the session pieces from `staff-login-client`, `lib/dev/demo.dart` (embeds `OrdersPage` directly at line ~83), tests `orders_page_test`, `menu_edit_page_test`, `export_month_dialog_test`, `restaurant_l10n_test`.

## Goal

- **Login screen** `lib/restaurant/pages/staff_login_page.dart`: heading, ID field, password field (obscured, no autofill, as the old dialog), optional device label, "Đăng nhập" button, plain-characters check before sending, busy state (no double submit), fixed error texts for 401 / 403 / 429 (with the wait seconds) / other, `staffSessionEnded` note when it appears after a 401. On success the password and ID fields are cleared and the session is stored. The language picker stays available on this screen.
- **Gate in `RestaurantApp`:** a `ListenableBuilder` on `StaffSessionController.instance`: signed in -> the normal app, signed out -> the login screen. **Everything pushed on top of the orders page (the menu editor, open dialogs) must be gone when the session ends**; recommended: do it in `MaterialApp.builder` so the Navigator is rebuilt (the orders page then starts fresh after the next login); the executor may choose `home` + `popUntil` if it passes the test below. `StaffSessionController.init()` is awaited-or-fired before `runApp` in `main()` like `LocaleController.init()`.
- **Logout:** an AppBar button "Đăng xuất" next to the language picker; one tap, no dialog; clears the session (and tells the server, best effort).
- **One staff-action helper** (a small function next to the orders page, reused by `status-finished-restaurant`): it takes the session headers, sends the call, and maps failures: **401 -> `StaffSessionController.endLocally()`** (the login screen appears with `staffSessionEnded`, the tapped action is **not** replayed), 403 / 429 / 409 / other -> the existing fixed snackbar texts. Moves onto it: `_changeStatus` (needs `status-finished-shared`'s `updateStatus(staffHeaders:)`), confirm payment, switch to cash, menu price / sold-out / add (via `MenuAdminState`). **No staff ID or password prompt remains in these paths.**
- **Remove** `StaffCredentialsHolder` and `showStaffLoginDialog` (and its file) when nothing uses them; update every doc comment that says "typed once per visit" / "kept in memory".
- **Export dialog keeps asking the password every time** (owner exception): both fields empty each time it opens (the ID may be pre-filled from the current login session's typed ID only if that is still in memory; otherwise empty); nothing is remembered after the download; a short line `exportPasswordNote`; a wrong password (401) shows the wrong-credentials text and **does not end the session**; 403, 429 and 503 as today. All three report choices (CSV and both xlsx) ask the password (SL-f, recommended; if the owner limits it to xlsx, the CSV path keeps the same prompt unless he says otherwise before this card runs).
- `lib/dev/demo.dart` embeds `OrdersPage` directly, so the demo skips the login gate; the staff actions there would 401 and show the login screen only in the real app. **Decide and record:** the demo gets the same gate around its restaurant half, or a comment saying it needs a session. Recommended: wrap the right half in the same gate so the demo behaves like the real app.

## Non-goals

The picker, cancel button and check-payment dialog (`status-finished-restaurant`), any backend or shared change, a refresh token, a "who am I" call, showing session expiry time, a customer screen.

## Tests written with the change

- signed out: the app shows the login screen and **not** the orders page; signing in (fake client) shows the orders page; a stored valid session (fake storage) goes straight to the orders page; an expired one shows the login.
- login screen: wrong credentials -> `staffWrongCredentials`; 403 -> disabled text; 429 -> wait text with seconds; network failure -> failed text; password field obscured; double tap sends one request; non-plain characters are refused before any request; the label is sent only when typed.
- logout: the button signs out, the login screen shows, a failed server call changes nothing visible.
- 401 on a staff action (status change, confirm payment, switch to cash, menu save) ends the session: the login screen shows, the action is not retried, **no** credential dialog appears anywhere; with the menu editor open at the time, it is gone after the 401.
- 403 / 429 / 409 on those actions keep their existing snackbar texts; the session stays.
- export dialog: opens with an empty password every time, even right after a successful export; sends the password headers (not the session); a 401 shows the error and the session stays; 429 / 403 / 503 as before; **no** session header is sent to the export route.
- the token never appears in any visible text (`find.textContaining` on the fake token finds nothing) or in a captured debug print.
- the existing badge, chime and card tests pass (with a signed-in fake session).
- no overflow at 360 px and text scale 2.0 on the login screen.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Behaviour as listed | `make test` (gate) |
| Gates, no import across apps | `make analyze`, `make format-check`, `make boundaries` (gates) |
| No credential prompt left outside the login screen and the export dialog; the token is never shown or logged | `code-reviewer`, `security-reviewer` (reviews) |
| Login, reload, 16-hour expiry, logout on two devices at once, and the export password prompt work on the real tablet and phone | owner acceptance, "unverified" until done |

## Note from `status-finished-shared` (2026-11-28)

`OrdersPage._changeStatus` sends the remembered staff credentials, or an EMPTY header map when staff haven't typed any, because the backend does not check headers on `PATCH /orders/{id}` yet. When the staff check is enforced this call gets 401/403/429 and today the page shows one generic "update failed" snackbar and never prompts. Handling 401 (re-prompt or back to the login screen, and clear the stored credentials), 403 and 429 on the status-change path belongs to the restaurant card; do not deploy the backend check before it ships. A repeated tap after a 401 counts toward the 5-in-60-seconds lock, so the restaurant card must not let status buttons loop on a 401.
