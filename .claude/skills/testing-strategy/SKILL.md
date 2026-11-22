---
name: testing-strategy
description: How to test food_orders — widget tests for the customer/restaurant apps and handler/SSE tests for the shelf backend. Use when adding or changing tests, or when a task card asks "what tests go with this". Not for running the app in a browser (that's owner acceptance) or for CI setup. Keywords: test, widget test, flutter_test, dart test, shelf handler, SSE test, coverage.
paths:
  - "test/**"
  - "backend/test/**"
  - "lib/**"
  - "backend/lib/**"
  - "backend/bin/**"
---

# Testing strategy

Two packages, two test runners:

| Package | Runner | Gate |
|---|---|---|
| Flutter apps (`lib/`, `test/`) | `flutter test` | `make test` |
| Backend (`backend/lib`, `backend/test`) | `dart test` | `make backend-test` |

## Backend

- Keep the router and state in `backend/lib/` and `bin/server.dart` thin, so tests build a fresh handler with its own in-memory state for each test. No shared globals between tests.
- Plain HTTP handlers: call the shelf `Handler` directly with `Request('POST', Uri.parse('http://localhost/orders'), body: ...)`. No socket, no port.
- SSE uses `request.hijack()`, which an in-memory request can't do. Test it with `shelf_io.serve(handler, InternetAddress.loopbackIPv4, 0)` (port 0 = any free port) and `dart:io` `HttpClient`. Always `server.close(force: true)` in `tearDown` and put a `timeout` on every stream read.
- Test the contract, not the implementation: status codes, JSON shape (`Order.toJson()`), ordering (`GET /orders` is newest first), and that bad input leaves the stored state unchanged.

## Flutter apps

- Widget tests pump `CustomerApp` / `RestaurantApp` or a single page. Don't let a test reach the real backend: `OrderRepository.init()` is called from `main()`, not from the widgets, so keep it that way or inject a fake client.
- Assert what the user sees (`find.text`, `find.byType`), and tap through flows with `tester.tap` + `pump`.
- `chime.dart` uses conditional imports, so tests on the Dart VM get the stub — don't import `chime_web.dart` directly.

## Not covered by automation

Live SSE in Chrome, the audio chime, Caddy/nginx routing, and iOS over mDNS. Those are owner acceptance in the real environment; report them as unverified unless the owner confirms.

## Related plugin skills

`dart-flutter:dart-add-unit-test`, `dart-flutter:flutter-add-widget-test` — use them for the mechanics; this file decides *what* to test here.
