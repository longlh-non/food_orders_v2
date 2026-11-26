---
executor: task-executor
scopes: [shared]
workKinds: [flutter, documentation, quality-gate]
blockedBy: [staff-login-contract, status-finished-shared]
---

# Strings for the staff login screen, logout and the export password note, in all 10 languages

Planned 2026-11-26. Placed **before** the restaurant UI card (not after it) because the screen can't compile without its keys; unused keys are harmless. Runs after `status-finished-shared` so two cards never edit the same ARB files at once. Independent of the backend card.

## Sources

`lib/shared/l10n/app_*.arb` (10 files, `app_vi.arb` is the template with `@key` metadata; existing staff keys include `staffLoginTitle`, `staffIdLabel`, `staffPasswordLabel`, `staffPlainCharsError`, `staffWrongCredentials` and the two "too many staff logins" keys, with and without `{seconds}`), `lib/shared/l10n/README.md`, `test/shared/arb_completeness_test.dart`, CLAUDE.md "Languages".

## Goal

Add to **all 10** ARBs and regenerate (names are suggestions; the executor lists which existing keys it reused instead, e.g. the wrong-credentials and too-many-tries texts):

- `staffLoginHeading`: "Đăng nhập nhân viên" (screen title; the existing `staffLoginTitle` may do).
- `staffLoginButton`: "Đăng nhập". `staffLoginBusy`: e.g. "Đang đăng nhập...".
- `staffDeviceLabelLabel`: "Tên thiết bị (không bắt buộc)"; `staffDeviceLabelHint`: e.g. "Ví dụ: Tablet bếp" (SL-j).
- `staffLoginDisabled`: "Máy chủ chưa bật đăng nhập nhân viên" (403).
- `staffLoginFailed`: a short "could not sign in, try again" (no answer / server error / bad reply).
- `staffLogout`: "Đăng xuất" (AppBar button and tooltip).
- `staffSessionEnded`: "Phiên đăng nhập đã hết, vui lòng đăng nhập lại" (shown on the login screen after a 401 or a 16-hour expiry; a tapped action is not repeated).
- `exportPasswordNote`: "Nhập lại mật khẩu để xuất file" (line on the export dialog; the export always asks the password, SL-f).
- `staffNoDeviceNote`-style helper lines only if the executor needs one; otherwise none.

`vi` is the planner's draft (the owner accepts or edits it); the other 9 languages are machine drafts: record them as "unverified" in `lib/shared/l10n/README.md` (the review log is updated by `staff-login-docs`).

## Non-goals

Using the keys in a screen; backend text (LANG6); the status, cancel and picker keys (`status-finished-shared`).

## Tests written with the change

`test/shared/arb_completeness_test.dart` passes unchanged. One test: `staffSessionEnded` and `staffLogout` are non-empty in all 10 locales and `staffLogout` in `vi` is "Đăng xuất".

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| All 10 files have all keys; generated files in sync and committed | `make test` (arb_completeness_test), `make analyze` (gates) |
| Format | `make format-check` exit 0 (gate) |
| Wording of the 9 machine drafts and the new vi lines | owner acceptance, "unverified" until a fluent speaker checks |
