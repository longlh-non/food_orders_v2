---
task: backend-orders-validate-input
status: passed
p0: 0
p1: 0
---

# Execute review — backend-orders-validate-input

Independent first-pass review by `code-reviewer` (tool-restricted, read-only), 2026-11-09. It ran in parallel with `security-reviewer` on the same frozen candidate, and neither saw the other's conclusions. Security report: `docs/reviews/security-backend-orders-validate-input.md`.

## Pre-check (DB5 safeguard)

The cart cannot send an empty order: `lib/customer/pages/cart_page.dart:38` returns early when the cart is empty. Rejecting empty `items` is therefore safe.

## Gates — first candidate

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (40 tests: 15 existing + 25 new) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` (2 tests) | 0 |

No test fixtures were adjusted. The existing `sampleOrder` was already valid.

## Findings (first pass): P0 0 · P1 0 · P2 4

- **P2-1** `backend/test/orders_api_test.dart:185`: the test name "merges the body…" was stale, because PATCH no longer merges. **Fixed.**
- **P2-2**: nothing pinned the order "400 for a bad status before 404 for an unknown id". **Fixed** by adding a test.
- **P2-3** `backend/lib/orders_api.dart:165`: `DateTime.tryParse` accepts `"2026"` and `"20261030"`. **Fixed**: `placedAt` must now start `YYYY-MM-DDT`.
- **P2-4** `backend/lib/orders_api.dart:43`: two customers placing orders in the same millisecond get a silent 409, because `OrderApiClient` ignores status codes. **Deferred** (a non-goal on the card). Follow-up: a client card that checks error statuses, and later server-generated ids (DB7).

**Checked with no issues found:**
- The real client's `Order.toJson()` output passes validation: `placedAt` without a `Z`, double prices, int quantities.
- `orderStatuses` matches the `OrderStatus` enum one to one.
- The `CLAUDE.md` table and "Order rules" match the code.
- There is no `await` between the duplicate check and the insert, so no race.
- Error messages are fixed strings.

## Fix round 1

Triggered by the security P1 (non-finite price; see the security report). I fixed it together with code P2-1, P2-2 and P2-3 in one batch.

**⚠ Beyond the owner's recorded decisions:** item `quantity` must be at least 1, and `price` must be a finite number of at least 0. These limits are crash hardening for the same class of input as the P1. The reviewer checked that no valid app order breaks them: the cart drops an item when its quantity reaches 0, and menu prices are positive. `CLAUDE.md` "Order rules" documents them. The owner can ask to revert.

**Invalidation:**
- Both reviewers re-ran, because their findings were fixed and the files they reviewed changed.
- All gates re-ran.
- The code reviewer re-read only the changed code in `orders_api.dart` (and `cart.dart` for context). For the new tests and the `CLAUDE.md` wording it relied on the caller's report and the green gates.

| Command | Exit |
|---|---|
| `make backend-analyze` | 0 |
| `make backend-test` (46 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `make analyze` | 0 |
| `make test` | 0 |

**Re-review 1 (code-reviewer):** P2-1, P2-2 and P2-3 are resolved. P2-4 stays a follow-up. No new findings. **P0 0 · P1 0 · P2 0 open** (1 deferred).

## Final candidate

`make check` → **exit 0** (format, boundaries, analyze, 2 app tests, backend analyze, 46 backend tests).

## Unverified

Owner acceptance: placing and accepting an order in the browser through Caddy still works with the stricter backend. Not done in this session.
