---
task: shared-order-calls-report-failure
status: passed
p0: 0
p1: 0
---

# Review: shared-order-calls-report-failure

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-shared-order-calls-report-failure.md`.

## Candidate

- **`lib/shared/api/order_api_client.dart`.** `placeOrder` and `updateStatus` go through `_orderCall`:
  - an `http.ClientException` becomes `OrderRequestException` with `statusCode` null;
  - a non-2xx answer becomes one with that status;
  - a 2xx whose body isn't a valid order becomes one with the 2xx status.
  - The new `OrderRequestException` (`message`, `int? statusCode`) never includes the response body.
- **`lib/shared/api/order_repository.dart`.**
  - `_api` is no longer final, and a `@visibleForTesting setApiForTest` sets it.
  - The doc comments say both calls throw and leave the cache unchanged.
  - The `_merge` doc comment is back on `_merge`. An earlier card had inserted `setOrdersForTest` between them.
- **`test/order_calls_test.dart`** (new): 18 tests.

## Round 1: changes requested. P0 0, P1 1, P2 2

- **P1:** a 2xx body with an unknown `status` makes `OrderStatus.values.byName` throw an `ArgumentError`, which escaped `_orderCall`. That breaks "UI code catches only one type".
- **P2:** the two catch blocks had duplicate bodies.
- **P2:** the successful repository `placeOrder` test didn't check that listeners were notified.

Confirmed in round 1:
- all five goals (except the P1);
- catch types follow `.claude/memories/catch-type-selection.md`, with no `on Object`;
- no new regression at the unawaited call sites (`CartPage`, `OrdersPage`); before this card they already threw unawaited `FormatException`s, and the follow-up cards fix them;
- a non-2xx with a valid order body is no longer merged by mistake;
- the tests aren't vacuous, and singleton state is reset;
- only `lib/shared/` and tests changed, with no new dependency.

## Fix round 1

- **P1:** `_orderCall` also catches `ArgumentError`. All three parse failures map to one local `invalid()` builder, which also fixes the duplication. Still no `on Object`. Test added: a 200 body with `status: "bogus"`.
- **P2 (test):** the successful `placeOrder` repository test asserts exactly one notification.
- **Security P2:** `updateStatus` builds its URL with `Uri(path: '/api/orders/${Uri.encodeComponent(id)}')`. Test added: an id of `../menu?x=1%zz` stays one path segment with no query.

## Re-review 1: passed. P0 0, P1 0, P2 0

## Deferred follow-ups

- **Backend id decoding:** `shelf_router` 1.1.5 matches on the encoded `request.url.path` and doesn't decode `<id>`. An order whose id contains `/`, `?`, `%` or a space can't be found by `PATCH /orders/{id}` and gets 404. The client side is now safe, and real ids are digit timestamps, so nothing breaks today.
  - Fix in a backend card: decode the id in the handler, or reject such ids at `POST /orders` (this also covers the ids `.` and `..`, see the security report).

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after fixes) | 0 |
| `make test` (197 tests, then 199 after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 199 app + 186 backend tests) | 0 |

## Unverified

Network errors in the browser surface as `http.ClientException` from `BrowserClient`. That's the documented behaviour, but it's checked end to end only in `customer-cart-place-order-shows-failure`, by the owner.
