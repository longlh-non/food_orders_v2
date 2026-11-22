---
executor: task-executor
scopes: [backend, docs]
workKinds: [backend, quality-gate, documentation]
blockedBy: [backend-orders-sqlite-storage]
securityReview: required
---

# Store the menu in the SQLite database and serve it (GET /menu)

Revised at planning time (owner: "create menu in the DB"). Replaces the earlier "Dart constant, no database" design. Same slug on purpose: other cards refer to it.

## Why

The menu is a hardcoded Dart list in the Flutter customer app (`lib/shared/data/sample_menu.dart`). The backend, which already holds the orders, should own the menu: one place decides what exists and what it costs, and it survives restarts. The owner asked for the menu to live in the database. This card is the table + backend half. Invariant 3: contract (table in `CLAUDE.md`) first, then backend, then client (next card).

## Sources

`CLAUDE.md` "Backend" table, `backend/lib/orders_api.dart` (router style, how `OrdersApi` receives the database after `backend-orders-sqlite-storage`), `backend/bin/server.dart`, `backend/test/orders_api_test.dart`, `lib/shared/data/sample_menu.dart` (the five items to seed), `lib/shared/models/menu_item.dart` (shape), `docs/tasks/backend-orders-sqlite-storage.md` (database design this card builds on).

## Design in plain words

- **One database file, two tables.** `orders` (from the sqlite card) and a new `menu_items`. One file means one thing to back up and one connection to open. The file keeps the name chosen there (`backend/data/orders.db`, env var `ORDERS_DB`); the name is slightly off now. Renaming was considered and rejected (MENU-DB1).
- **Schema versioning: a "version 2" step**, not an edit of the sqlite card. That card sets `PRAGMA user_version` to 1 (creates `orders`) and explicitly expects "the next schema change adds an `if version < 2` step". This card adds exactly that step: create `menu_items`, insert the 5 seed rows, set version 2, all in one transaction. Why this is simpler: the two cards stay independent and each can be reviewed alone; the version number is what makes the seeding run once. (Folding menu into v1 would mean rewriting a card the owner already decided.)
- **Table:** `menu_items(id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', price REAL NOT NULL CHECK (price >= 0))`. Listed `ORDER BY rowid` (insertion order = today's menu order). No sort column, images, categories or sold-out flag (M4, deferred).
- **Seeding once, idempotent.** The seed runs only when the database is at version 1 (fresh or orders-only). Restarting does not re-seed, so a row the owner deleted stays deleted and a price the owner changed stays changed. The seed list lives in Dart next to the migration, copied from `sample_menu.dart` (backend cannot import `lib/`, invariant 4). The Flutter copy is deleted in the UI card.
- **Who owns the database handle.** `bin/server.dart` opens the database once and gives the same handle to `OrdersApi` and a small new `MenuApi` (new file, for example `backend/lib/menu_api.dart`, so it does not conflict with `orders_api.dart`). The migration function is shared and runs once at open. If the sqlite card put "open + migrate" inside `OrdersApi`, this card moves it to a small shared function (for example `backend/lib/database.dart`) and says so. Closing: whoever opens the database closes it; the executor makes sure `OrdersApi.close()` no longer closes a handle it did not open, or that the order is documented. Keep it small; no repository interface (invariant 6).
- **Read per request, no caching.** `GET /menu` queries the table every time, so a menu edit is visible without restarting the backend.

## How the owner edits the menu (no editing UI yet)

Use the `sqlite3` command-line tool on the database file. Example (documented in `CLAUDE.md` "Backend" by this card):

```bash
sqlite3 backend/data/orders.db "UPDATE menu_items SET price = 9.5 WHERE id = 'burger';"
sqlite3 backend/data/orders.db "INSERT INTO menu_items (id, name, description, price) VALUES ('fries', 'Fries', 'Crispy', 3.5);"
```

(The ids shown are placeholders; the card documents real ones from the seed.) The CLI needs `sudo apt install sqlite3`, which the owner runs; agents never do. The change shows up in the customer app the next time it loads the menu (page reload), with no backend restart. Do NOT delete the database file to "re-seed": it also holds the orders. Editing the seed list in code only affects a brand-new database. Old orders are unaffected by price changes because each order stores its own item names and prices. Keep item ids stable; renaming an id breaks nothing in orders today (orders have no item ids) but would matter after MENU-DB3.

This is where open decision M1 matters: if staff must edit from the restaurant app, a later card adds write endpoints, restaurant UI, and auth thinking. Not in this card.

## Goal

1. Add a row to the API table in `CLAUDE.md` -> "Backend" (owner approval for this edit is requested by this card): `GET /menu` -> 200, JSON list of `{id: string, name: string, description: string, price: number}`, in insertion order. Read-only; no POST/PATCH/DELETE. Also update the prose: the backend now stores orders and the menu in SQLite; document the CLI editing method above.
2. Version-2 migration and seed as above; `MenuApi` with the `GET /menu` route mounted next to the orders routes, same CORS/JSON headers as `/orders`. Parameterised statements only (no request data reaches SQL here anyway).
3. The sqlite card's test "a fresh file gets `user_version` 1" becomes "2" in this card; say so in the change notes.

## Non-goals

Create/update/delete menu endpoints or any editing UI (M1), images, categories, sold-out flags, multi-restaurant, Flutter changes, server-side price check on `POST /orders` (MENU-DB3), renaming the database file/env var (MENU-DB1).

## Tests written with the change

In `backend/test/` (new `menu_api_test.dart`, `:memory:` database per test):
- `GET /menu` returns 200 with `application/json`; body is a list of exactly 5 items matching the seed (ids, names, prices); each has string `id`, `name`, `description` and numeric `price`; ids unique and non-empty.
- POST/PATCH/DELETE on `/menu` are not 200 (404/405).
- Migration: fresh database ends at `user_version` 2 with 5 rows; running the migration twice does not add rows (idempotent); a database at version 1 with existing orders gets the menu and keeps the orders.
- Temp-file test: open, delete one menu row, close, reopen: row is still gone (no re-seed) and orders are intact; a changed price persists.
- A row changed directly in SQL shows up in the next `GET /menu` (no caching).
- Existing order tests still pass.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `GET /menu` returns the documented shape from the table | `make backend-test` (gate) |
| Seed runs once, survives reopen, no re-seed | `make backend-test` (temp-file test) |
| Backend code is clean | `make backend-analyze` (gate) |
| Read-only endpoint, parameterised SQL, DB file still git-ignored, no new dependency beyond `sqlite3` already approved | `security-reviewer` (review; endpoint + DB triggers) |
| `CLAUDE.md` table and editing instructions match the code | `code-reviewer` (review) |
| Existing order endpoints unchanged | `make backend-test` (gate) |
| `make check` green | `make check` exit 0 (gate) |
| Restart backend: `curl http://customer.local/api/menu` still returns the menu | owner acceptance in the real environment - "unverified" until done |
| Change a price with the documented `sqlite3` command, no restart: `curl` shows the new price | owner acceptance (needs `sqlite3` CLI installed by the owner) |

## Environment limits

Agents cannot check the Caddy path or install the `sqlite3` CLI; the owner restarts the backend, runs the curl and the edit command.

## Open decisions (owner)

- M1 staff editing from an app: the owner asked for it (2026-11-09). It's planned as separate cards that come after this one (`backend-menu-availability-column` → `backend-menu-staff-write-endpoint` → …), so this card stays read-only.
- M2 is answered: the menu lives in the database.
- **MENU-DB1: decided (owner, 2026-11-09). Keep `orders.db` / `ORDERS_DB`.** No rename.
- **MENU-DB2: decided (owner, 2026-11-09). Edit the menu with the `sqlite3` CLI**, as in "How the owner edits the menu". The owner installs it.
- MENU-DB3 / M3 price trust: follow-up card, see below.

Price trust (M3) stays a follow-up: server-side price lookup needs items to carry an `id`, which changes the order contract (`POST /orders`, `Order.toJson()`, validation, stored `items_json`, both apps). With the menu in the table it becomes easy afterwards, but it is its own contract-first card. Until then the price is whatever the browser posts, as today.
