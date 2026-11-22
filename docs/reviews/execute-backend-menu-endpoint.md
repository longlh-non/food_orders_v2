---
task: backend-menu-endpoint
status: passed
p0: 0
p1: 0
---

# Execute review — backend-menu-endpoint

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-09. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-menu-endpoint.md`.

Owner decisions applied: MENU-DB1 (keep `orders.db` / `ORDERS_DB`) and MENU-DB2 (menu edited with the `sqlite3` CLI).

## Implementation notes

- **Contract first:** `CLAUDE.md` got the `GET /menu` row in the API table, plus Backend prose: two tables, a seed that runs once, and a CLI editing section.
- **`database.dart`:** schema step 2 creates `menu_items` and fills it from `seedMenu` (5 items copied from `sample_menu.dart`) in one transaction. Step 1 is untouched.
- **New `menu_api.dart`:** `MenuApi(Database)` serves read-only `GET /menu`, ordered by `rowid` and read on every request.
- **Ownership:** the database handle is opened and closed only by its opener. `OrdersApi.close()` now closes just the event stream.
- **`server.dart`:** one `Cascade` combines both APIs.
- **Test change the card asked for:** the order tests' "user_version 1" checks now expect 2.

## Gates — first candidate

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (65 tests: 51 + 14 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` | 0 |

**Runtime check** (real server, `ORDERS_DB` pointing at a scratch file; the owner's `backend/data/orders.db` was not touched): `GET /menu` → 200 with the 5 seeded items; `POST /menu` → 404; `GET /orders` → 200.

## Findings (first pass): P0 0 · P1 0 · P2 2

- **P2-1** `backend/bin/server.dart:27`: with Orders first in the `Cascade`, an unknown order's 404 fell through to the menu router, so its body changed from "Order not found" to "Route not found". The status was unchanged. Confirmed at runtime. **Fixed:** MenuApi is now first and OrdersApi last, so Orders' 404 is the one returned.
- **P2-2** `backend/test/menu_api_test.dart:95`: SSE and `POST /orders` weren't checked through the combined server. **Fixed:**
  - runtime check: `curl -N /orders/stream` received the posted order;
  - new tests: an order POST through the combined handler, and the exact "Order not found" body.

**Checked with no issues found:**
- The v2 step works for a fresh database and for an existing v1 database. Re-running is a no-op.
- The seed matches `sample_menu.dart` exactly.
- No route overlap. Write methods on `/menu` get 404.
- No leaked or double-closed database handles.
- `price` is `REAL`, so it serialises as a double (noted for the next card).
- The docs match the code, and every acceptance row is covered.

## Fix round 1

One batch covering code P2-1, code P2-2, and security P2-1/P2-2 (see the security report):

- Cascade reordered.
- Two combined-handler tests added.
- `menu_items` CHECK constraints added: prices must be numeric, between 0 and 1e9 (this blocks Infinity), and names/descriptions can't be binary.
- `PRAGMA busy_timeout = 2000`.
- CLI docs: back-up tip, the same-file warning, and what the table refuses.

**Editing step 2 was safe:** it had only ever run on scratch, temp or in-memory databases, never the owner's real file.

| Command | Exit |
|---|---|
| `make backend-test` | **2** on the first attempt. The new case "table refuses a numeric name" failed: `TEXT` affinity stores `5` as the text `'5'`, which is harmless. Replaced with a binary-name case. |
| `make backend-analyze` | 0 |
| `make backend-test` (72 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` | 0 |

**Runtime re-check:** `GET /menu` 200; `POST /menu` 404; `POST /orders` 200; `PATCH /orders/nope` → "Order not found" 404; SSE delivered the posted order.

**Re-review 1 (code-reviewer):** P2-1 and P2-2 are resolved. The CHECK constraints, `busy_timeout` placement and Cascade order are correct. No new findings. The reviewer didn't re-read the tests or `CLAUDE.md` this round.

## Re-review 2 (code-reviewer, docs only)

Asked for because the docs weren't re-read in round 1. The caller had first corrected one bullet: numbers in a name are stored as text, and only binary data is refused.

**Result:** the "Storage" section matches `database.dart` and `menu_api.dart`. It raised two P2 wording nits:
- the "Keep ids stable" label sat on a bullet about constraints;
- the back-up tip should say to stop the backend first.

Both were applied exactly as suggested. No meaning changed, so there was no further review round.

## Final candidate

`make check` → **exit 0** (format, boundaries, analyze, 2 app tests, backend analyze, 72 backend tests).

## Unverified (owner acceptance)

- Restart the backend, then `curl http://customer.local/api/menu` still returns the menu (through Caddy).
- Change a price with the documented `sqlite3` command, without a restart: `curl` shows the new price. This needs the `sqlite3` CLI, which the owner installs.

**Note:** the owner's real `backend/data/orders.db` is still at schema version 1. It will move to version 2, with the menu, the next time the backend starts.
