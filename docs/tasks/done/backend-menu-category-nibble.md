---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
securityReview: required
---

# Menu gets a 4th category "nibble" ("Ăn vặt"): schema step 4 (table rebuild) and `GET /menu`

First card of the "category tabs" set (owner asked 2026-11-11 for tabs "Đồ ăn", "Đồ uống", "Ăn nhẹ", "Ăn vặt"). Contract first, read-only, no Flutter change. `blockedBy` is empty because the earlier schema cards are archived in `done/`.

## Why

The tabs need a category for "Ăn vặt". Today `menu_items.category` only accepts `food`, `snack`, `drink`. SQLite cannot change a CHECK rule on an existing column, so the table has to be rebuilt.

## Decisions this card carries

- **TAB1, decided by owner 2026-11-11: "Ăn vặt" starts EMPTY.** No existing item moves into it and nothing is seeded (not in step 4, not in `seedMenu`). The owner adds items later with `sqlite3` (examples in goal 1). No card in this set may seed or move items.
- **TAB-DB1, the value (planner recommendation):** `nibble`. ASCII, English like the other three (`food`, `snack`, `drink`), and clearly different from `snack` (which is "Ăn nhẹ"). The owner sees it only when typing `sqlite3` commands. Rejected: `an-vat` (mixes Vietnamese into a list of English words), `treat`/`street` (could be read as another word for snack).
- **TAB-DB2, step number (planner recommendation):** this is schema step **4**. The two planned column cards move to 5 (image) and 6 (availability); their cards were edited in place (2026-11-11). Why before them: the rebuild must copy every column and every CHECK of `menu_items`; doing it while the table still has only the step 2 + 3 columns is the simplest and least risky. Doing it later would mean re-listing their columns and CHECKs too. Nothing of the image/availability cards has shipped, so renumbering costs only text. Why not fold it into the image step: unrelated change, bigger review, one failed step would block both.
- `allow_toppings` stays meaningful only for `food`: `GET /menu` already returns `allowToppings` true only for `category == 'food'`. Same for `nibble`.

## Sources

`backend/lib/database.dart` (steps 1 to 3, `seedMenu`), `backend/lib/menu_api.dart` (`ORDER BY rowid`), `backend/test/menu_api_test.dart`, `docs/tasks/done/backend-menu-category-and-toppings.md` (how step 3 was tested, including a copy-of-real-database check), `CLAUDE.md` "Backend" table, "Storage", "Editing the menu", and sqlite.org "Making Other Kinds Of Table Schema Changes".

## Goal

1. `CLAUDE.md` (owner approval for this edit is requested by this card), in this order:
   - "Backend" table: `category` becomes `"food" | "snack" | "drink" | "nibble"`; `allowToppings` still only true for foods.
   - "Storage": `menu_items` line mentions the four values; add step 4 to the history ("Step 4 added the `nibble` category = Ăn vặt, empty on purpose; the table was rebuilt"); the backup warning already there covers it.
   - "Editing the menu": the add-item comment lists four categories; **add an example for Ăn vặt**: `sqlite3 backend/data/orders.db "INSERT INTO menu_items (id, name, description, price, category, allow_toppings) VALUES ('khoai-lang-nuong', 'Khoai lang nướng', '', 15000, 'nibble', 0)"` (clearly marked as an example name/price), plus `UPDATE menu_items SET category = 'nibble', allow_toppings = 0 WHERE id = '...'` for moving an existing item; "What the tables refuse" lists the four values; one sentence that the Ăn vặt tab shows an empty message until an item is added.
2. `database.dart`: new `if (db.userVersion < 4)` step, in one transaction ending with `db.userVersion = 4`, following the documented rebuild pattern:
   1. `CREATE TABLE menu_items_new (...)` with **the same columns in the same order and the same CHECKs as steps 2 and 3**, except `category TEXT NOT NULL DEFAULT 'food' CHECK (category IN ('food', 'snack', 'drink', 'nibble'))`;
   2. `INSERT INTO menu_items_new (id, name, description, price, category, allow_toppings) SELECT id, name, description, price, category, allow_toppings FROM menu_items ORDER BY rowid`;
   3. `DROP TABLE menu_items`; `ALTER TABLE menu_items_new RENAME TO menu_items`.
   No other table references `menu_items` (orders store item names and prices in `items_json`; `toppings` is separate), so no foreign-key handling is needed; the executor confirms there are no views or triggers on it and records that.
3. `GET /menu` needs no code change (it already passes `category` through and gates `allowToppings` on `'food'`); confirm with a test. Steps 1 to 3 are untouched ("never edit a shipped step").
4. Row order must be unchanged: `GET /menu` orders by `rowid`, and the copy is done `ORDER BY rowid` so the new rowids follow the old order.
5. Tests that said a fresh file ends at `user_version` 3 now say 4 (change notes, same pattern as earlier migrations).
6. No item is moved or inserted (TAB1): after the step, zero rows have category `nibble`.

## Non-goals

Flutter changes, moving or seeding any item, a write endpoint, images, availability.

## Tests written with the change

In `backend/test/menu_api_test.dart` (in-memory database per test unless stated):
- fresh database ends at `user_version` 4 with the same 25 menu rows (9 food, 7 snack, 9 drink, **0 nibble**) in the same order as before; `GET /menu` shape unchanged;
- a hand-built **version 3** database (created with the step 1-3 SQL, one price changed, one owner-added item, one deleted seed item, an order in `orders`, a topping edit) migrates to 4 and keeps every menu row (all columns), the **same order** from `GET /menu`, the toppings, and the order; running the migration again changes nothing;
- the rebuilt table accepts `category = 'nibble'` (the documented example INSERT works) and `GET /menu` returns it, with `allowToppings: false` even when `allow_toppings = 1` is written directly;
- still refused after the rebuild: `category` of `'cake'`, `''`, `NULL`; a negative price, a price over 1e9, a blob name, `allow_toppings = 2`, a duplicate `id` (all earlier CHECKs and the primary key survived; compare against `sqlite_master`);
- failure path: a v3 database where a table named `menu_items_new` already exists makes step 4 fail; afterwards it is still at version 3 with all rows intact (rollback works);
- copy-of-real-database check, as the step 3 card did: if `backend/data/orders.db` exists, copy it to a temp location (never open the original), run the migration on the copy, compare row count/ids/order before and after; if missing or already at 4, say so in the notes.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Rebuild keeps every row, the order and the orders; runs once; rolls back on failure; no `nibble` rows created | `make backend-test` (gate) |
| All old CHECK rules still hold, the new value is accepted, unknown refused | `make backend-test` (gate) + `security-reviewer` (review; DB schema + endpoint trigger) |
| Backend clean, no new dependency | `make backend-analyze` (gate) + empty `pubspec.yaml` diff (code-reviewer) |
| `CLAUDE.md` matches code, including the Ăn vặt example | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| On the owner's real database (version 3): `cp backend/data/orders.db backend/data/orders.backup.db`, restart the backend, `curl http://customer.local/api/menu` still lists the same 25 items in the same order with no `nibble`; the documented Ăn vặt INSERT then shows `"category":"nibble"` on the next curl (delete the test row afterwards if it was only a test) | owner acceptance in the real environment, "unverified" until done |

## Environment limits

Agents cannot run the real backend behind Caddy or the `sqlite3` CLI; the owner makes the backup, restarts the backend and runs the curls.

## Decided by the owner (2026-11-11)

TAB-DB1 (`nibble`) and TAB-DB2 (schema step 4, before image and availability) follow the recommendations, which the owner accepted ("all recommended"). TAB1: Ăn vặt starts empty.
