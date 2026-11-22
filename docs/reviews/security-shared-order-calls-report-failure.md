---
task: shared-order-calls-report-failure
status: passed
p0: 0
p1: 0
---

# Security review: shared-order-calls-report-failure

Independent reviewer: `security-reviewer` (read-only). It reviewed the same candidate as `execute-shared-order-calls-report-failure.md`.

- **Assets:** the order cache, the strings shown in the UI, and the app process.
- **Attacker inputs:** the HTTP status and body of `/api` responses, and order ids and text posted by other clients.

## Round 1: changes requested. P0 0, P1 1, P2 2

- **P1:** `Order.fromJson` throws `ArgumentError` for an unknown status, and `_orderCall` didn't convert it. A caller catching only `OrderRequestException` would get an unhandled error again, a narrower form of the original "nobody was told" bug. It's a contract gap, not an exploit.
- **P2:** `updateStatus` put the raw order id into the URL. Any LAN client can post an order with an id like `../menu`, `x?y` or `a/b`, and when staff press Accept, that id changes the request path or query. It's still a status-only PATCH through the same-origin proxy. Separately, `Uri.parse` could throw a raw `FormatException` for some ids.
- **P2:** 3xx and 2xx-with-empty-body (204) are reported as failures. That's safe; no change.

Checked and clean:
- messages are built only from a fixed label and the integer status, never the response body or a caught exception's text (tested);
- catches are narrow;
- nothing is merged or notified unless the 2xx parse succeeds, and `Order.fromJson` still validates types and runs `displayText` on names;
- the `_api` seam is `@visibleForTesting` with `--fatal-infos`;
- tests reset the seam;
- no new dependency (`http/testing` ships with `http`).

## Fix round 1

- **P1:** `ArgumentError` is caught and mapped to `OrderRequestException`. Tested.
- **P2 (id in URL):** the URL is built with `Uri(path: ...)` and `Uri.encodeComponent(id)`, so `Uri.parse` no longer runs on the id. Tested with `../menu?x=1%zz`.

## Re-review 1: passed. P0 0, P1 0

Remaining P2, deferred (written down in the execute report's follow-ups):
- **Ids `.` and `..`:** `encodeComponent` leaves an id of exactly `.` or `..` unchanged, and a browser may normalise `/api/orders/..`. The worst case is a PATCH to a non-order route, which answers 404/405 and is reported as `OrderRequestException`. Nothing is exploitable.
- **Fix:** reject such ids at `POST /orders`, or decode ids on the backend (backend follow-up).

## Gates

See `execute-shared-order-calls-report-failure.md`. `make check` exits 0 on the final candidate.

## Needs confirmation in the real environment

- How the proxy and browser handle odd ids such as `..`.
- The browser end-to-end failure path, checked in `customer-cart-place-order-shows-failure`.
