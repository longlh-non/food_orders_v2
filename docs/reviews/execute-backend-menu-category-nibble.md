---
task: backend-menu-category-nibble
status: passed
p0: 0
p1: 0
---

# Execute review — backend-menu-category-nibble

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-11. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-menu-category-nibble.md`.

Owner decisions applied:
- TAB1: Ăn vặt starts empty; nothing is seeded or moved.
- TAB-DB1: the category value is `nibble`.
- TAB-DB2: this is schema step 4, before the image and availability steps.

## Implementation notes

- **`database.dart`, new step 4,** rebuilds `menu_items` in one transaction, following SQLite's documented pattern:
  1. create `menu_items_new` with the same columns, types, NOT NULLs, defaults and CHECKs as steps 2 and 3, except that `category` also accepts `nibble`;
  2. `INSERT … SELECT … ORDER BY rowid`;
  3. `DROP` the old table and `RENAME` the new one;
  4. set `userVersion = 4`.
- Steps 1–3 are untouched. `menu_api.dart` is unchanged, because `allowToppings` was already gated on `food`.
- **`CLAUDE.md`:** the API category union now includes `nibble`, plus the Storage history ("Step 4 … empty on purpose"), `sqlite3` examples for adding an item to Ăn vặt or moving one there, and the refused-values list.
- **Test changes the card asked for:** `user_version` expectations go from 3 to 4 wherever a full migration runs. The step-3 failure test still expects 2.
- **Deviation from the card:** the "copy-of-real-database check" was run **by hand** on a scratch copy, not inside the test suite, because tests must not depend on a developer's local file. The reviewer agreed.

## Gates

| Command | Exit |
|---|---|
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (65) | 0 |
| `make backend-analyze` | 0 |
| `make backend-test` (107 = 91 + 16 new) | 0 |
| `make check` (final candidate) | **0** |

**Manual real-data check:** a scratch copy of `backend/data/orders.db` (version 3: 25 menu items, 5 toppings, 2 orders) went to version 4.
- **Unchanged:** every menu row (same order), the toppings and the orders are byte-identical.
- **Categories:** drink 9, food 9, snack 7; nothing in `nibble`.
- **Schema:** the new CHECK contains `'nibble'`, and no `menu_items_new` is left behind.
- **Real file untouched:** same size and modification time.

## Findings: P0 0 · P1 0 · P2 0

**Reviewer confirmed:**
- The new `CREATE TABLE` matches steps 2 and 3 exactly; the only change is the category list.
- Column order is kept, so `SELECT *` comparisons stay valid.
- Rowids are renumbered 1..n in the old order, so `GET /menu` keeps its order and only gaps disappear.
- `DROP` plus `RENAME` inside the transaction is safe: no foreign keys, triggers or views exist.
- The tests are strong: the v3 builder reuses the real DDL and seeds, and the failure path is covered.
- `CLAUDE.md` is accurate.

## Docs follow-up from the security review

The security review's three P2s were all about documentation. They were applied to `CLAUDE.md` as suggested, with no further review round:
- **Dated backups:** `orders.$(date +%F-%H%M).db`, so a good backup can't be overwritten.
- **A live-backup option:** `sqlite3 … ".backup …"`.
- **An off-disk reminder:** copy a backup elsewhere from time to time.
- **A note** that step 4 drops hand-made indexes, triggers and views on `menu_items`.

**Real-environment check the reviewer asked for:** a scratch copy of the owner's database contains only the three automatic primary-key indexes. There are no hand-made objects, so nothing is lost.

## Unverified (owner acceptance)

1. On the owner's real database: make a dated backup, then restart the backend.
2. `curl http://customer.local/api/menu` should list the same 25 items in the same order, with no `nibble`.
3. The documented Ăn vặt `INSERT` should show `"category":"nibble"` on the next request. Delete the test row afterwards.
