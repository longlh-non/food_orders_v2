---
task: restaurant-staff-id-password-clients
status: passed
p0: 0
p1: 0
---

# Security review: restaurant-staff-id-password-clients

Independent reviewer: `security-reviewer` (read-only), on the same first-round candidate as `execute-restaurant-staff-id-password-clients.md`.

- **Asset:** the shared staff ID and password.
- **Inputs:** the two dialog fields, plus the server's status and `Retry-After`.
- **Boundary crossed:** browser → `/api/*` over LAN HTTP (accepted risk).

## Round 1: passed. P0 0, P1 0, P2 1

- **P2:** a stale "token" comment in `export_month_dialog.dart`. **Fixed.**

Checked and clean:
- the credentials leave only via `StaffCredentials.headers`, never in the URL or body;
- error messages are fixed strings and never include the server's text;
- `toString` hides both values, and the dialog shows only fixed texts;
- no persistence: the holder is in-memory only and set only after a 200;
- autofill, suggestions, autocorrect and IME learning are off on both fields;
- a plain (not obscured) ID field is acceptable: it's an identifier, not the secret;
- 401 clears both; 429 keeps them;
- `Retry-After` is parsed as an int and shown as plain text (after the code review it's also bounded to 1..3600);
- the ASCII rule matches the backend's `[\x20-\x7E]+`;
- all new code is in `lib/restaurant/`;
- no `X-Staff-Token` is left in `lib/`.

The round-1 fixes (tests, the `Retry-After` bound, wording) only tighten the reviewed behaviour, so there was no security re-review.

## Gates

See `execute-restaurant-staff-id-password-clients.md`. `make check` exits 0.

## Needs the real environment

- Chrome may still offer to save a `type=password` field despite `autofillHints: []`; check in a browser.
- `Retry-After` should be readable through Caddy (same origin).
