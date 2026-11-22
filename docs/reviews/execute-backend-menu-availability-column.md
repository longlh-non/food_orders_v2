---
task: backend-menu-availability-column
status: passed
p0: 0
p1: 0
---

# Review: backend-menu-availability-column

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-menu-availability-column.md`.

## Candidate

- **`backend/lib/database.dart`:** schema step 6, `ALTER TABLE menu_items ADD COLUMN available INTEGER NOT NULL DEFAULT 1 CHECK (available IN (0, 1))`. It runs in one transaction with rollback and ends at `user_version` 6.
- **`backend/lib/menu_api.dart`:** `GET /menu` returns `available` as a boolean (`row['available'] == 1`).
- **Tests:**
  - `backend/test/menu_api_test.dart`: a new group "schema step 6 (sold out)"; `seedMenuJson` and the shape test include `available`; every latest-version test now says 6; the step-4 and step-5 tests compare rows without `image` and `available`; the version 4 fixture drops both columns.
  - `backend/test/orders_api_test.dart`: version 6.
- **`CLAUDE.md` (owner-approved):**
  - the `/menu` row;
  - the Storage `menu_items` bullet and a step-6 bullet;
  - `sqlite3` examples for sold out and available again;
  - "What the tables refuse".

Owner decisions (2026-11-13): run this card, then `backend-request-body-limit`, then `backend-menu-staff-write-endpoint`. `CLAUDE.md` and `dev/**` edits were approved for those cards.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2-1:** a clumsy sentence in the Storage `menu_items` bullet ("..., and ... , and ..."). **Fixed** (wording only).
- **P2-2:** step 6 has no rollback test. Optional; steps 4 and 5 have none either.

Checked and correct:
- Goals 1–4;
- the step matches the card exactly, and steps 1–5 are untouched;
- it runs once and rolls back on failure;
- both fixtures are fair;
- the tests aren't vacuous: the "twice" test flips a value first, and the refusal tests cover 2, -1, 'yes' and NULL;
- `MenuItem.fromJson` ignores the extra key;
- no new dependency.

## Deferred follow-ups

- **Rollback test:** an optional rollback test for steps 5 and 6 (also listed in `execute-backend-menu-image-column.md`).
- **Notes for `backend-menu-staff-write-endpoint` (from the security review):**
  - check `available` strictly as a JSON boolean before writing, because SQLite would coerce `"1"`;
  - `POST /orders` doesn't check `available` until MENU-DB3.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (257 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make test` (241 Flutter tests) | 0 |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate, after the wording fix) | 0 |

## Unverified (owner acceptance)

After a dated backup and a backend restart (the real database moves from version 5 to 6), `curl http://customer.local/api/menu` should show `available` on every item.
