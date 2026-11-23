---
task: restaurant-menu-editing-page
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-menu-editing-page

## Scope

`lib/restaurant/state/menu_admin_state.dart`, `pages/menu_edit_page.dart`, `api/menu_admin_client.dart`, `state/staff_credentials.dart`, `widgets/staff_login_dialog.dart`, the `OrdersPage` menu button, the two new test files, and the backend contract (`backend/lib/menu_api.dart`). Read-only review.

## Findings: P0 0, P1 0, P2 3

1. Two rows can save at once (`_saving` is per item): with wrong credentials both PATCHes fail, burn the server's 5-in-60 s lockout budget and two login dialogs can stack. No credential leak. Fix: serialise saves or keep one in-flight credential prompt.
2. No client-side cooldown after a 429; bounded by human tapping speed, the nuisance `CLAUDE.md` already accepts.
3. The no-secrets test is weak: it cancels the login dialog before asserting and the error text is a fixed string. Add a unit test on `MenuAdminException.message`/`toString()` and assert the holder is null after a 401.

## Checked and clean

Credentials only in the in-memory holder (no storage, URL, body, log, exception text or widget tree); sent only as `X-Staff-Id`/`X-Staff-Password` to the same-origin relative `/api/menu/{encoded id}` (`.`, `..` and the empty id rejected); `StaffCredentials.toString` is `<hidden>`; the password field is obscured with autofill off, values trimmed and checked to printable ASCII (blocks CR/LF header injection); 401 clears the holder; no automatic retry loop (the user must type again); every UI message is a fixed Vietnamese string, `Retry-After` is parsed as an int and capped 1–3600; client validation `^[0-9]{1,7}$` and 0..1,000,000 re-checked in `setPrice`, matching the backend (a double like `25000.0` is accepted there); the same row is guarded against double saves; item names render only in plain `Text` and tooltips; a 404 on a deleted item leaves the list unchanged; no weakening of the accepted-risk statements and no new endpoint.

## Needs the real environment

`PATCH` and an encoded id passing through Caddy/nginx; a browser sending the custom `X-Staff-*` headers same-origin (no preflight expected).

## Verdict

**Passed**, P0: 0, P1: 0.
