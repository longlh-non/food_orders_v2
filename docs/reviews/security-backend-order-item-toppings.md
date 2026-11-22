---
task: backend-order-item-toppings
status: passed
p0: 0
p1: 0
reviewedFiles:
  - backend/lib/orders_api.dart
  - CLAUDE.md
---

# Security review — backend-order-item-toppings

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-12.

## Scope

- **Assets:** the `orders` table (`items_json`), the live-stream broadcast to the kitchen, and process availability.
- **Attacker input:** the `POST /orders` body, specifically the new `item.id` and `item.toppings[]` (each topping's name, price and id).

## Checked with no issues found

- **Crash and encoding safety:** `_isValidPrice` rejects non-finite numbers for both item and topping prices, so `1e999` can't reach `jsonEncode` on the insert or live-stream path. JSON can't produce NaN, and oversized integer literals fail the `int` check on `quantity`.
- **Exact shape at every level:** toppings on toppings, extra nested keys, and non-map entries all get a 400. Name and id values must be plain strings, so no nested structures get through.
- **No echo:** every error is a fixed string, and the 409 body is fixed too.
- **SQL:** `?` placeholders only.
- **Client-trusted prices:** not materially worse. The base price was already set by the client, and toppings add one more client-set number. MENU-DB3's re-pricing by id will cover both.
- **Unchecked ids:** stored as sent, and nothing reads them yet. Keep them display-only until MENU-DB3 checks them against the menu.

## Findings: P0 0 · P1 0 · P2 1

- **P2-1:** `quantity` and prices have no upper bound (`9e18` passes), so `quantity × price` can overflow or display badly. This predates the card. **Deferred:** noted on `backend-request-body-limit`, to add maximums there or in MENU-DB3.

**Storage:** toppings are capped at 10 per line. The number of items and the string lengths are bounded only by the pending body-size limit (a proxy-based card).

## Needs real-environment confirmation

- **The proxy body limit** actually being enforced (pending card).
- **The Flutter apps tolerating `id` and `toppings`:** confirmed by the caller from the code (`OrderItem.fromJson` ignores extra keys).

**Counts:** P0 0 · P1 0 · P2 0 open (1 deferred).
