---
task: backend-menu-staff-write-endpoint
status: passed
p0: 0
p1: 0
---

# Review: backend-menu-staff-write-endpoint

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-menu-staff-write-endpoint.md`.

## Candidate (final)

- **`backend/lib/menu_api.dart`:**
  - `MenuApi(db, {StaffGate? staffGate})`. Without a gate, writes answer 403 (fail closed).
  - **`PATCH /menu/<id>`:**
    - the gate check comes first;
    - `_readSmallBody` refuses bodies over 4 KB with 413 (a declared Content-Length, or streamed past the cap);
    - `_menuEditProblem` accepts only an object with `price` and/or `available`: price a whole number from 0 to 1,000,000, `available` strictly a bool;
    - the id is decoded once and only ever bound;
    - an `UPDATE` built from fixed column names; `updatedRows == 0` gives 404;
    - the reply is `_itemJson(row)`.
  - `GET /menu` output is unchanged (refactored into `_selectItems` and `_itemJson`).
- **`backend/bin/server.dart`:** passes the server's gate.
- **`backend/test/menu_api_test.dart`:** a group "PATCH /menu/{id} (staff only)", and a combined-cascade test.
- **`CLAUDE.md` (owner-approved):**
  - the PATCH row, and the GET `/menu` row wording;
  - the Staff token section;
  - an "Editing the menu" bullet with a curl example and the `ps` warning;
  - the code bullet.

Owner decisions (2026-11-17): MENU-EDIT0–4 as recommended; `CLAUDE.md` edits approved.

## Round 1: passed. P0 0, P1 0, P2 4

- **P2-1:** fractional prices were accepted, but `CLAUDE.md` says prices are whole VND.
- **P2-2:** error shapes are mixed: the gate's 401/403 are JSON, while 400/404/413 are plain text. Clients key off the status.
- **P2-3:** no test through the combined cascade, the real server path.
- **P2-4:** the `CLAUDE.md` code bullet didn't mention the staff PATCH.

Checked and correct:
- `GET /menu` output is unchanged;
- `CLAUDE.md` matches the code;
- the token is checked before the body (the test isn't vacuous);
- the id is decoded once and the column names are fixed;
- no race between UPDATE and SELECT;
- the token never appears in responses;
- CORS isn't widened;
- validation edges (`1e999`, a bool price, a strict `available`).

## Fixes

- **P2-1:** `price == price.truncate()` is required. Tests: 25000.5 → 400; 27000.0 → 200.
- **P2-3:** a combined-cascade test: an unknown id gives 404, a missing token 401, and the row is unchanged.
- **P2-4:** the code bullet is updated.
- **P2-2:** left as is.
- **Security P2:** `CLAUDE.md` warns that `curl -H` shows the token to `ps` and suggests `curl -H @file` on shared machines.

## Re-review 1: passed. P0 0, P1 0, P2 1 (optional)

- **P2:** `27000.0` is bound as a double. That's harmless: the `price` column is REAL anyway, and both forms are JSON numbers the apps read as `num`.

## Deferred follow-ups

1. **Runbook:** add `STAFF_TOKEN` to `deploy-runbook` through the server-only environment file, as this card's deployment note says.
2. **MENU-DB3:** look up prices on the server at `POST /orders`, and reject sold-out or unknown items. A price change doesn't affect open carts until then. Required before real customers.
3. **Error shapes:** optionally make all errors from this endpoint JSON, if the staff client wants that.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` (round 1 and after fixes) | 0 |
| `make backend-test` (303 tests, then 306 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 241 app + 306 backend tests) | 0 |

## Unverified (owner acceptance)

With `STAFF_TOKEN` set and the backend restarted:
- `curl -X PATCH` with the token changes a price, and it shows in `GET /api/menu`;
- without the header, 401;
- without the environment variable, 403;
- a browser preflight with `x-staff-token` is rejected.
