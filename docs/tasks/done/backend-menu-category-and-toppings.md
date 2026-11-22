---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: []
securityReview: required
---

# Menu gets a category (food / drink) and a toppings list: schema step 3, `GET /menu`, new `GET /toppings`

First card of the "grid menu with toppings and optional drink" set. Contract first, read-only, no Flutter change. Order contract (what an order carries) is the next card, `backend-order-item-toppings`.

## Why

The customer grid must tell foods from drinks (drinks never get toppings and are offered as the optional drink), and it must know which toppings exist and what they cost. The menu has neither fact today (soda is just an item).

## Sources

`backend/lib/database.dart` (steps v1, v2, `seedMenu`), `backend/lib/menu_api.dart`, `backend/bin/server.dart` (mounts the APIs), `backend/test/menu_api_test.dart`, `CLAUDE.md` "Backend" table, "Storage", "Editing the menu".

## Design (plain words)

- **Category** is one extra column on `menu_items`: `'food'`, `'snack'` or `'drink'` (snack added 2026-11-11). Toppings are NOT a category; they are a different kind of thing (they hang on a food and cost extra), so they get their own small table.
- **Toppings are one global list** any food can take (option a). Smallest thing that delivers the request. Deferred, not built: per-food allowed toppings (a join table), topping groups with rules ("choose up to 3"), topping sold-out flag, Per-food allowed toppings (a join table) stay deferred. A simple per-food on/off switch **is** in this card: see `allow_toppings` (TOP2c, owner 2026-11-11).
- **Schema version.** This card is step 3. **Revised 2026-11-10 (image request):** the next two schema steps are `backend-menu-image-column` = step 4 (the owner's current request, small, independent) and `backend-menu-availability-column` (sold-out) = step 5 (it is blocked behind the staff-token work anyway). The image column was not folded into this card: this card is already category + a new table + seed data, and one card should stay one reviewable change. One migration step here creates both the column and the table (never edit a shipped step; this one has not shipped).
- `GET /menu` stays a JSON **array** (old clients keep working; they ignore the new field). Toppings are a separate endpoint, not nested in `/menu`, so the menu shape does not become an object.

## Goal

1. `CLAUDE.md` (owner approval for the edit is requested by this card), in this order:
   - "Backend" table: `GET /menu` items become `{id, name, description, price, category, allowToppings}` with `category` one of `food`, `snack`, `drink` and `allowToppings` a boolean (always `false` for snacks and drinks); add row `GET /toppings` -> 200 JSON list of `{id: string, name: string, price: number}` in insertion order, read-only.
   - "Storage": three tables now; describe step 3 and the seed data (the owner's real list, below); editing instructions for categories and toppings via `sqlite3` (examples: `UPDATE menu_items SET allow_toppings = 0 WHERE id = '<dish>'`, `INSERT INTO toppings ...`, `DELETE FROM toppings WHERE id = ...`). Keep ids stable; past orders keep their own names and prices.
2. `database.dart`: `if (db.userVersion < 3)` step, in one transaction, ending with `db.userVersion = 3`:
   - `ALTER TABLE menu_items ADD COLUMN category TEXT NOT NULL DEFAULT 'food' CHECK (category IN ('food', 'snack', 'drink'))`;
   - `ALTER TABLE menu_items ADD COLUMN allow_toppings INTEGER NOT NULL DEFAULT 1 CHECK (allow_toppings IN (0, 1))`. Drinks are seeded with `0`; `GET /menu` returns `allowToppings: false` for any drink, whatever the column says;
   - `CREATE TABLE toppings (id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK (typeof(name) = 'text'), price REAL NOT NULL CHECK (typeof(price) IN ('real','integer') AND price >= 0 AND price <= 1000000000))` (same price rule as `menu_items`);
   - `DELETE FROM menu_items WHERE id = 'soda'` (TOP2b, owner 2026-11-11: soda is removed; no-op if already gone; past orders keep their own copy of the name and price);
   - seed rows below, inserted with `INSERT OR IGNORE` so an item the owner already created with the same id cannot make the migration fail.
3. `menu_api.dart`: `GET /menu` adds `category`; new `GET /toppings` (same CORS/JSON style; `SELECT id, name, price FROM toppings ORDER BY rowid`, constant SQL).
4. Tests that said a fresh file ends at `user_version` 2 now say 3 (mention in change notes, same pattern as earlier migrations).

### Seed data (owner's real list, given 2026-11-11, replaces the earlier placeholders)

Prices are in **VND**, as whole numbers. Names are exactly as the owner wrote them (Vietnamese, UTF-8). Ids are ASCII slugs made from the names, because ids must stay stable and appear in order items (TOP3).

Toppings (`toppings` table):

| id | name | price |
|---|---|---|
| `cha` | Thêm chả | 10000 |
| `thit` | Thêm thịt | 10000 |
| `trung-trang` | Thêm trứng tráng | 8000 |
| `xuc-xich` | Thêm xúc xích | 10000 |
| `lap-xuong` | Thêm lạp xưởng | 12000 |

Drinks (rows in `menu_items` with `category = 'drink'`, description `''`):

| id | name | price |
|---|---|---|
| `tra-da` | Trà đá | 4000 |
| `nuoc-dong-chai` | Nước đóng chai | 12000 |
| `lavie` | Lavie | 6000 |
| `lavie-them-khoang` | Lavie thêm khoáng | 10000 |
| `bo-huc` | Bò húc | 20000 |
| `tra-chanh` | Trà chanh | 15000 |
| `tra-quat` | Trà quất | 15000 |
| `ca-phe-den` | Đen | 20000 |
| `ca-phe-nau` | Nâu (Cà phê sữa) | 25000 |

~~Still open before this card runs~~: superseded. CUR1 and the food list were both decided on 2026-11-11 (see below).

## Non-goals

Any write endpoint, topping availability, per-food topping rules, images (`backend-menu-image-column`, next schema step), changing `POST /orders` (next card), Flutter changes, auth.

## Tests written with the change

In `backend/test/menu_api_test.dart` (in-memory DB per test):
- every `/menu` item has `category` in {food, snack, drink}; the 9 seeded drinks (`tra-da` … `ca-phe-nau`) are `drink`, the snacks are `snack`, the foods `food`; none of the old foods (`burger`, `pizza`, `salad`, `fries`) remain; no `soda` row exists after migrating (fresh and version-2 databases); each food's `allowToppings` matches the owner's food list, and every snack and drink is `false`; array shape and insertion order unchanged;
- `/toppings` returns the seeded list with string id/name and finite non-negative numeric price, in order;
- a database at version 2 with a changed burger price, an extra owner item and an order migrates to 3 and keeps all of them; running `migrate` twice changes nothing; an owner item with id `tra-da` already present does not break the migration;
- direct SQL: `category = 'beverage'` and `price = -1` on `toppings` are refused by the CHECK; a row set to `drink` shows `drink` on the next GET;
- fresh file ends at `user_version` 3; existing order tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Documented shapes equal real responses | `make backend-test` (gate) |
| Migration 2 -> 3 keeps data, runs once, tolerates id collisions | `make backend-test` (gate) |
| Backend clean | `make backend-analyze` (gate) |
| Constant SQL only, CHECKs block bad hand edits, no new dependency | `security-reviewer` (review; endpoint + DB trigger) |
| `CLAUDE.md` matches code; seed data matches the owner's list exactly (names, ids, VND prices) | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| `curl http://customer.local/api/menu` and `/api/toppings` on the owner's real (version 2) database show the new data; the owner checks the Vietnamese names and prices | owner acceptance in the real environment - "unverified" until done |

## Environment limits

Agents cannot run the real backend behind Caddy or the `sqlite3` CLI edit; the owner restarts the backend and runs the curls.

## Open decisions added 2026-11-11 (from the owner's real list)

- **CUR1, currency: DECIDED 2026-11-11 = VND.** The display switch is card `currency-vnd-display`, which waits for this card. **Consequence for this card:** every price this card writes must be VND, including the food list once the owner gives it. Original note: the owner's prices are VND, but the existing menu (burger 9.50 …) and the app's display (`$x.xx`) are USD. VND toppings next to USD foods would show nonsense like `$10000.00`. Recommended: switch the whole app to VND, which is also VI3, in its own small card **before** the toppings reach the UI. That card would change the display format to `10.000 ₫` (no decimals, `.` as the thousands separator), re-price or replace the 5 food seeds, and give the owner a `sqlite3` step for the real database, which already holds USD prices.
- **TOP2b, soda: DECIDED 2026-11-11 = remove** (see the migration step above). Original note: the owner's drink list doesn't include soda. Keep it as a drink (and at what VND price), or remove it from the seed?
- **TOP2c, which foods take toppings: DECIDED 2026-11-11 = some dishes are "no toppings".** This is the `allow_toppings` column above. Which dishes is part of the food list.
- ~~**Food list:**~~ superseded by "Food list (owner, 2026-11-11)" below. Original note: the 5 starting foods (burger, pizza, salad, fries, soda) don't match these toppings (chả, lạp xưởng …). Does the owner want to give real foods too? Note: the owner's real database already has the 5 foods, written by schema step 2. A new seed list only affects brand-new databases, so replacing foods on the real database is a `sqlite3` step or an explicit migration step. Decide which.

## Food list (owner, 2026-11-11), replaces the "ON HOLD" notice

Prices in VND. Names exactly as the owner wrote them. No descriptions were given, so every item has description `''`.

**Foods** (`category = 'food'`):

| id | name | price | toppings |
|---|---|---|---|
| `xoi-thit` | Xôi thịt | 25000 | yes |
| `xoi-cha` | Xôi chả | 25000 | yes |
| `xoi-ruoc` | Xôi ruốc | 25000 | yes |
| `xoi-trung-op` | Xôi trứng ốp | 23000 | yes |
| `xoi-trung-ran` | Xôi trứng rán | 23000 | yes |
| `xoi-xuc-xich` | Xôi xúc xích | 25000 | yes |
| `mi-tom-trung-chan` | Mì tôm trứng chần | 23000 | yes |
| `mi-tom-trung-op` | Mì tôm trứng ốp | 25000 | yes |
| `mi-tom-bo` | Mì tôm bò | 30000 | yes |

**Snacks, "Ăn nhẹ"** (`category = 'snack'`, a new third category; `allow_toppings = 0`):

| id | name | price |
|---|---|---|
| `trung-ngai-cuu` | Trứng ngải cứu | 10000 |
| `lap-xuong-nuong-da` | Lạp xưởng nướng đá | 15000 |
| `an-nhe-cha` | Chả | 10000 |
| `an-nhe-thit` | Thịt | 10000 |
| `an-nhe-trung-trang` | Trứng tráng | 8000 |
| `an-nhe-xuc-xich` | Xúc xích | 10000 |
| `an-nhe-lap-xuong` | Lạp xưởng | 12000 |

**Old foods:** `burger`, `pizza`, `salad` and `fries` are removed, along with `soda`.
- **Fresh databases:** the seed list in `database.dart` becomes the list above.
- **The owner's existing database (version 2):** step 3 deletes the old ids and inserts the new rows (`INSERT OR IGNORE`).
- **Past orders** keep their own copies of names and prices.

**Decided (owner, 2026-11-11):**
- **FOOD1:** Xôi trứng is two separate dishes, **Xôi trứng ốp** and **Xôi trứng rán**, both 23000. No "options" feature.
- **FOOD2:** toppings can also be ordered on their own as the 5 snacks above, at the same prices as the toppings and named without "Thêm". They're separate rows from the `toppings` table, so a price change must be made in both places. The `CLAUDE.md` editing instructions added by this card must say so.

The card now has its full seed data: 9 foods, 7 snacks, 9 drinks and 5 toppings. It is ready to run.
