---
task: backend-staff-token-gate
status: passed
p0: 0
p1: 0
---

# Review: backend-staff-token-gate

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-staff-token-gate.md`.

## Candidate

- `backend/lib/staff_token.dart` (new):
  - `StaffGate(String? configuredToken)` with `enabled` and `check(Request) -> Response?`;
  - `constantTimeEquals`, `staffTokenHeader` (`x-staff-token`), `minStaffTokenLength` (16).
- `backend/test/staff_token_test.dart` (new).
- `backend/bin/server.dart`: reads `STAFF_TOKEN` and prints only `staff routes: enabled` or `disabled`. No route uses the gate yet; `backend-orders-month-export-endpoint` wires it.
- `CLAUDE.md`, an owner-approved edit for this task (recorded in the card):
  - a "Staff token" section under Backend;
  - a "Known limitations" line.

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1:** a configured token with surrounding spaces or a newline counts as enabled but can never match. HTTP trims header values, so every request would get 401.
- **P2-2:** the length rule counts UTF-16 code units, while the comparison uses UTF-8 bytes. Harmless; it needed clearer documentation.
- **P2-3:** the comment on the 'Mã'/'Ma' test was misleading. Timing can't be tested deterministically, so that stays checked by reading the code.

Checked and correct:
- fail-closed rules (null, empty, under 16 characters give 403; exactly 16 is enabled);
- header case-insensitivity;
- the constant-time loop;
- fixed error bodies;
- no value or length printed;
- tests aren't vacuous;
- `CLAUDE.md` matches the code;
- scope.

## Fixes (one batch, with the security P2s)

- **Trimming:** `StaffGate` trims the configured token before the length check. Two tests were added: spaces and a newline are ignored, and 15 characters plus spaces stays disabled.
- **Docs:** the doc comment states the length rule (UTF-16 code units), and the test comment was corrected.
- **`CLAUDE.md`:**
  - a `read -rs STAFF_TOKEN && export STAFF_TOKEN && dart run bin/server.dart` tip, with the caveat that same-user or root processes can still read the environment;
  - "Spaces or a newline around the value are ignored."

## Re-review 1: passed. P0 0, P1 0, P2 0

All fixes are confirmed. The `CLAUDE.md` text still matches the code.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` (round 1 and after fixes) | 0 |
| `make backend-test` (184 tests, then 186 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1) | 0 |
| `make check` (final candidate; 181 app + 186 backend tests) | 0 |

## Unverified (owner acceptance)

Start the backend with and without `STAFF_TOKEN`. It should print `staff routes: enabled` / `disabled`, and never the value.
