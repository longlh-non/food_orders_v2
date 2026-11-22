---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: [backend-menu-image-file-serving]
securityReview: required
---

# Flutter side of the contract: `MenuItem.image` and the picture URL

No visible UI change. Invariant 3: after the table and the backend, the model and `OrderApiClient`.

## Why

The customer grid (and later the restaurant menu screen) needs to know which picture belongs to an item and where to load it from. Both apps use `MenuItem`, so it lives in `lib/shared/` (invariant 2).

## Sources

`lib/shared/models/menu_item.dart`, `lib/shared/api/order_api_client.dart` (`_baseUrl = '/api'`, `fetchMenu`), the two backend image cards, `CLAUDE.md`.

## Ordering note

`shared-order-and-menu-models-toppings` also adds a field to `MenuItem` (`category`). The two cards do not depend on each other; whichever runs second adds its field next to the other's and keeps both sets of tests. Equality stays by id.

## Goal

1. `MenuItem` gets `final String? image` (constructor default `null`, so existing const items and tests compile). Equality stays by id.
2. `fromJson`: key missing or `null` -> `null` (old backend, or no photo). A string must match the same pattern as the backend, `^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$`; anything else (wrong type, or a string that does not match) throws a `FormatException` naming the field, like the other fields. The value is never used for anything except building the picture URL below.
3. `OrderApiClient` gets a small way to turn the stored name into the URL: `String imageUrl(String image)` returning `'$_baseUrl/images/$image'` (a relative path, so it stays same-origin through Caddy and in deploy). It does not accept free-form text: it asserts the pattern again (or only takes a `MenuItem` and returns `null` when `image` is `null`; the executor picks the smaller shape and notes it).
4. Update the `MenuItem` doc comment (image is optional; null means placeholder).

## Non-goals

UI, caching, preloading, `Image` widgets, a restaurant change, `category` or toppings (other card), staff editing of the image.

## Tests written with the change

In `test/` with `MockClient` (no network):
- `MenuItem.fromJson`: image missing -> null; `null` -> null; `'burger.webp'` valid; for each of jpg, jpeg, png, webp; rejected: a number, a list, `''`, `'../x.png'`, `'http://evil.example/x.png'`, `'a/b.png'`, `'Burger.PNG'`, `'x.gif'`, a 100-character name; existing tests pass; equality by id unchanged;
- `fetchMenu` with a mixed reply (one item with an image, one with `null`) returns both; a reply with one bad image name fails the whole call with the same error style as other bad fields;
- the URL helper returns `/api/images/burger.webp` and refuses or returns null for bad input.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Parsing behaves as listed; old JSON without `image` still parses | `make test` (gate) |
| Only a validated name can reach the URL | `make test` (gate) + `security-reviewer` (review; JSON parsing trigger) |
| `shared/` imports neither app | `make boundaries` (gate) |
| Analyzer, format clean, no new dependency | `make analyze`, `make format-check` (gates) + empty `pubspec.yaml` diff (code-reviewer) |
| `make check` green | `make check` exit 0 (gate) |

## Environment limits

None; no browser step.

## Open point for the owner (IMG3b)

Recommendation above: a bad `image` value makes the menu fail to load, like any other bad field. This is almost unreachable, because the database refuses bad names and the backend sends `null` for odd ones. The alternative (treat a bad value as "no photo", menu still loads) is friendlier but hides backend mistakes. Say if you prefer it.
