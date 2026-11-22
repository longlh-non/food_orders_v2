---
task: backend-menu-image-column
status: passed
p0: 0
p1: 0
---

# Review: backend-menu-image-column

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-backend-menu-image-column.md`.

## Candidate

- `backend/lib/menu_image.dart` (new): `menuImageName` (`^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$`) and `isValidImageName`, the one rule both image cards use.
- `backend/lib/database.dart`: schema step 5, `ALTER TABLE menu_items ADD COLUMN image TEXT CHECK (...)`. It runs in one transaction with rollback and ends at `user_version` 5. The installed SQLite accepts a CHECK on `ADD COLUMN`, so no table rebuild was needed.
- `backend/lib/menu_api.dart`: `GET /menu` returns `image` only when the stored value passes `isValidImageName`, otherwise `null`.
- Tests:
  - `backend/test/menu_api_test.dart`: a new group "schema step 5 (menu pictures)"; the shape tests include `image` (and the `nibble` category); version asserts are now 5; two step-4 tests were adjusted (explained in the card).
  - `backend/test/orders_api_test.dart`: version asserts are now 5.
- `CLAUDE.md` (owner-approved edit):
  - the `/menu` row in the Backend table;
  - in Storage, the `menu_items`, step-5 and "What the tables refuse" bullets;
  - in Editing the menu, the `sqlite3` picture examples and the picture-name rules, including renaming `IMG_1234.JPG`.

Owner decisions (2026-11-13): IMG1, IMG3 and IMG4 as recommended; run this card before `backend-menu-image-file-serving`; `CLAUDE.md` edits approved for both cards.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2:** no test that step 5 rolls back on failure. Steps 1–4 use the same BEGIN/try/ROLLBACK shape, and the card didn't ask for one.
- **P2:** the version 4 fixture is built by dropping `image` from a fresh database, not by running steps 1–4 alone. The reviewer judged it a fair stand-in: the columns, CHECKs and row order are exactly step 4's output, and the "keeps everything" test compares all three tables.

Checked and correct:
- Goals 1–5;
- step-5 SQL matches the card exactly;
- steps 1–4 are untouched;
- runs once and is idempotent (tested);
- tests aren't vacuous: refusals check both the exception and the unchanged value, and the "sneaky" names prove the regex layer does real work;
- the step-4 test changes still cover what those tests were for;
- `MenuItem.fromJson` ignores unknown keys, so the apps keep working;
- `CLAUDE.md` matches the code;
- scope and boundaries;
- no new dependency.

## Deferred follow-ups

1. **Rollback test:** a failing-step-5 test. Pre-create an `image` column on a version 4 file, then assert `migrate` throws and the version stays 4. Optional, for consistency.
2. **Future table rebuilds:** any later rebuild of `menu_items` (like step 4) must carry the `image` column **and its CHECK** forward, or the CHECK is silently lost. This note is from the security review.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (202 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make test` (208 Flutter tests) | 0 |
| `git diff --stat backend/pubspec.yaml` (empty) | 0 |
| `make check` (final candidate) | 0 |

## Unverified (owner acceptance)

After a dated backup and a backend restart (the real database moves from version 4 to 5):
- `curl http://customer.local/api/menu` shows `"image": null`;
- after the `sqlite3` UPDATE, it shows the name.
