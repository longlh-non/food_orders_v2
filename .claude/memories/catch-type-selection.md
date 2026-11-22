# Choosing a catch type in Dart

`on Exception` does not catch Dart `Error`s such as `TypeError` — and `json['x'] as String` throws a `TypeError` on bad input.

| Situation | Catch |
|---|---|
| API, network, business code | The narrowest documented `Exception` (e.g. `http.ClientException`, `SocketException`) |
| Parse boundaries (request bodies, SSE lines) | `FormatException` for bad JSON, **plus** `TypeError` when casting decoded values |
| UI or server boundary that must not crash | `on Object catch (e, st)`, with logging and a clear fallback |
| Tests for invalid input | Only use `on Object` if the contract promises a catch-all |

Don't turn every catch into `on Object` — that hides programming errors. Catch broadly only at a deliberate fallback boundary, and keep the stack trace.
