---
task: backend-menu-category-nibble
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/database.dart
  - backend/test/menu_api_test.dart
  - CLAUDE.md
---

# Security review — backend-menu-category-nibble

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-11.

## Scope

- **Assets:** the owner's `menu_items` rows and `orders`, both in one SQLite file.
- **Inputs:** none from requests; this step is constant SQL. The only outside actor is the `sqlite3` CLI, or a second process, writing to the same file.

## Checked with no issues found

- **Atomicity:** one `BEGIN`/`COMMIT`, with `userVersion` set inside it.
  - A crash, power loss or full disk leaves a rollback journal that SQLite replays, so the database stays at version 3.
  - A thrown error triggers the explicit `ROLLBACK`.
  - `DROP` and `RENAME` are transactional in SQLite.
- **CHECKs preserved:** `typeof(name)`, `typeof(description)`, the price type check with its 0..1e9 bounds, `allow_toppings` 0/1, the primary key, NOT NULL and the defaults all match steps 2 and 3. Only `category` gains `nibble`. Nothing was dropped, so text and Infinity prices are still refused.
- **Data copy:** an explicit column list plus `ORDER BY rowid`. Rowids are renumbered, which only closes gaps, and `GET /menu`'s order is unchanged.
- **Foreign keys:** none reference `menu_items`. Orders store item copies as JSON, so the `DROP` can't cascade.
- **A pre-existing `menu_items_new`:** the step fails closed and rolls back, and a test covers it.
- **A concurrent CLI writer:** the step waits up to 2 s for the lock, then throws and rolls back. Rows committed before `BEGIN` are copied.

## Findings: P0 0 · P1 0 · P2 3 (all documentation; addressed)

1. **`DROP TABLE` loses any hand-made index, trigger or view on `menu_items`.** **Addressed:** `CLAUDE.md` now says so. A check on a copy of the owner's database found only the automatic primary-key indexes, so nothing is lost for the owner.
2. **The fixed-name backup command could overwrite a good backup.** **Addressed:** `CLAUDE.md` now uses a dated name, `orders.$(date +%F-%H%M).db`.
3. **A plain `cp` of a live database can be inconsistent.** **Addressed:** the guidance says to stop the backend first, or to use `sqlite3 … ".backup …"`, and adds an off-disk reminder.

The `CLAUDE.md` `sqlite3` examples use constant, valid values, and the CHECKs still apply. Nothing unsafe is encouraged.

**Counts:** P0 0 · P1 0 · P2 0 open.
