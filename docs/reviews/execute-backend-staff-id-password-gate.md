---
task: backend-staff-id-password-gate
status: passed
p0: 0
p1: 0
---

# Review: backend-staff-id-password-gate

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-staff-id-password-gate.md`.

## Candidate

- **`backend/lib/staff_gate.dart` (new; replaces `staff_token.dart`):** `StaffGate({id, password, now})`.
  - **Fail closed:** values are trimmed; the ID must be 1–64 and the password ≥ 12 printable-ASCII characters, otherwise 403.
  - **Comparison:** headers `x-staff-id` and `x-staff-password` (a missing one counts as empty); both halves are always compared in constant time (`&`).
  - **Responses:** one fixed 401 body and no `WWW-Authenticate`.
  - **Lockout:** global; after 5 failures within 60 s, every staff request gets 429 with `Retry-After` (whole seconds left, rounded up) for 60 s. The failure list is capped at 5 and the clock is injectable.
- **`backend/bin/server.dart`:** reads `STAFF_ID` and `STAFF_PASSWORD`.
  - It prints enabled, or disabled with the rules, never values.
  - It prints a note naming `STAFF_TOKEN` if that's still set.
- **`backend/lib/menu_api.dart`, `orders_api.dart`:** import the new gate; the default `StaffGate()` is disabled. Comments updated.
- **Tests:** `backend/test/staff_gate_test.dart` (new, 26; replaces `staff_token_test.dart`), and the export and menu tests updated to the new headers.
- **`CLAUDE.md` (owner-approved):**
  - "Staff ID and password" replaces "Staff token";
  - the API rows (headers, 401 wording, 429);
  - the curl examples;
  - Known limitations;
  - the code bullet and the runbook pointer.

Both deleted files were tracked: `git status` shows them as deleted plus the new untracked files. Nothing was staged.

Owner decisions (2026-11-19): ID 1–64; password ≥ 12; printable ASCII; no hash; custom headers; one 401; global lockout of 5 in 60 s; a clean switch; no autofill (client card). `CLAUDE.md` edits approved.

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1:** one sentence in `CLAUDE.md` ("The token only stops…") still said "token". **Fixed.**
- **P2-2:** comments in `orders_api.dart`, `menu_api.dart` and `bin/server.dart` still said "token". **Fixed.**
- **P2-3:** the CORS test only checks that the allow-headers don't include the staff headers; it would also pass if no allow-headers came back. It still guards the list. **Deferred** (optional: also assert the preflight's allow-headers is present).

Confirmed:
- naming as the card asks;
- every rule, the comparison and the lockout path;
- the tests aren't vacuous (lockout timing with the injected clock, one identical 401 body for seven kinds of wrong input, no values in responses);
- both routes are tested for 200, 401, 403 and 429;
- `CLAUDE.md` matches the code;
- no new dependency.

For the docs card: `docs/runbook-local.md` still mentions the token at lines 25, 28, 118, 138–154 and 246.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (337 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (325 tests) | 0 |
| `git diff --stat` on pubspec and lock files (empty) | 0 |
| `make check` (final candidate, after the wording fixes) | 0 |

## Unverified (owner acceptance)

Start the backend with `STAFF_ID` and `STAFF_PASSWORD`, then via curl:
- export and the menu PATCH with the headers give 200;
- a wrong ID or password gives 401;
- unset variables give 403;
- 5 wrong tries give 429.

Until `restaurant-staff-id-password-clients` lands, the restaurant app's staff actions get 401.
