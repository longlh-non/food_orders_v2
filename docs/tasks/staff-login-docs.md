---
executor: task-executor
scopes: [docs]
workKinds: [documentation, quality-gate]
blockedBy: [staff-login-restaurant, status-finished-docs]
---

# Docs: runbook, deploy notes, language record and the Layout tree for the staff login

Planned 2026-11-26. `CLAUDE.md` rules were written in `staff-login-contract`. **Editing `CLAUDE.md` here (the "Layout" tree and the Notifications / How-the-Flutter-side lines only) needs the owner's explicit approval for this task**; without it, do the other files and list the `CLAUDE.md` lines for the owner. Runs after `status-finished-docs` so two cards don't edit `docs/runbook-local.md` and `docs/deploy.md` at once.

## Sources

`docs/runbook-local.md` (the "Staff ID and password" section, the menu editing and export sections, "Language review log", the section `status-finished-docs` added), `docs/deploy.md` (**uncommitted owner edits may exist: `git status` and `git diff docs/deploy.md` first, change only what this card needs**), `lib/shared/l10n/README.md`, `CLAUDE.md` (Layout tree, "How the Flutter side consumes it"), the shipped files of the staff-login cards.

## Goal

- `docs/runbook-local.md`, an owner section "Đăng nhập nhân viên":
  - open the restaurant app, sign in once with the staff ID and password (same values as the backend start command); the session lasts **16 hours** or until "Đăng xuất"; reloading the page keeps it; another tablet or phone can sign in at the same time (up to 20 at once; the 21st ends the oldest);
  - what does and does not need the password again: price, sold-out, adding items, "Đã nhận chuyển khoản", "Chuyển sang tiền mặt" and status changes use the session; **the month export (CSV and both Excel reports) always asks the password again**;
  - what an expired session looks like (login screen with "Phiên đăng nhập đã hết"; a tap made at that moment is not repeated: tap again);
  - **restarting the backend does not sign anyone out; changing `STAFF_PASSWORD` or `STAFF_ID` and restarting signs everyone out** (HMAC key choice, if confirmed);
  - curl still works with the old `X-Staff-Id` / `X-Staff-Password` headers; a curl example for `POST /staff/login` that does not put the password in shell history (`read -rs`), and an example of using the token with `X-Staff-Session` from a file (`curl -H @file`);
  - plain words on limits: one shared login for everyone; a lost tablet's session lasts up to 16 hours unless someone signs out on it or the password is changed and the backend restarted; the login screen doesn't hide the orders list (existing open API); who changed a status is recorded only once `order-status-audit-log` ships, per session, not per person;
  - schema step 11 (`staff_sessions`) belongs to the first-start reminder: steps 9 to 12 run together after one dated backup.
- `docs/deploy.md`: the release checklist and the Docker update steps mention step 11 in the "dated backup first" line; **no new environment variable**; note that the proxies pass `X-Staff-Session` and the Docker Caddyfile removes `Authorization` (the reason the token isn't a Bearer header). No change to `deploy/**`.
- `lib/shared/l10n/README.md` and the "Language review log": the new keys, and that the 9 non-vi texts are machine drafts, unverified; the new vi lines await owner acceptance.
- `CLAUDE.md` (with approval): add `staff_session_client.dart`, `staff_session_controller.dart`, the session storage files and `staff_login_page.dart` to the restaurant side of the Layout tree and `staff_sessions.dart` / `staff_api.dart` to the backend side; remove `staff_login_dialog.dart` and the "kept in memory only" wording if they are still there.

## Non-goals

Any code. Contract text (already done). The audit-log docs (`order-status-audit-log`).

## Tests

None. Re-read each command against the files it names.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Text matches the shipped behaviour and names real files | `code-reviewer` (review) |
| No secret, token, env value or personal detail in any example | `code-reviewer` (review) |
| The owner's uncommitted `deploy.md` edits are untouched | `git diff` in the review |
| `make check` green | `make check` exit 0 (gate) |
| The owner can follow the runbook section on their machine | owner acceptance, "unverified" until done |
