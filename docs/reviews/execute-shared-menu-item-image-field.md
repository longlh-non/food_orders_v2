---
task: shared-menu-item-image-field
status: passed
p0: 0
p1: 0
---

# Review: shared-menu-item-image-field

Independent reviewer: `code-reviewer` (read-only). The security review is in `security-shared-menu-item-image-field.md`.

## Candidate

- **`lib/shared/models/menu_item.dart`:**
  - top-level `menuImageName`, character-for-character the same regex as `backend/lib/menu_image.dart`;
  - `MenuItem.image` (`String?`, defaults to null), with an updated doc comment;
  - `fromJson`: missing or null gives null; a non-string or non-matching value throws `FormatException('menu item image must be null or a picture file name')`.
- **`lib/shared/api/order_api_client.dart`:** `static String? imageUrlFor(MenuItem item)` checks the name again and returns `/api/images/<name>`, or null.
  - It's static, so UI code needs no client.
  - It takes a `MenuItem` and returns null instead of asserting (the smaller of the card's two shapes, as Goal 3 allows).
- **`test/menu_item_test.dart`:** new groups `image`, `OrderApiClient.imageUrlFor` and `fetchMenu with pictures` (29 tests).

**Owner point IMG3b, not yet answered:** the card's recommendation is implemented. A bad picture name fails the whole menu load, like any other bad field, and the code comment records this. It has been flagged to the owner.

## Round 1: passed. P0 0, P1 0, P2 2

- **P2-1:** the regex is hand-copied in `lib/shared/models/menu_item.dart` and `backend/lib/menu_image.dart`, and nothing enforces that they match.
- **P2-2:** the bad-name `fetchMenu` test only checks `isA<FormatException>()`; it could also check the message mentions `image`.

Checked and correct:
- Goals 1–4;
- equality is still by id only;
- `Cart.refreshItems` and `MenuState` keep the fresh parsed items, so `image` isn't dropped;
- all existing call sites compile;
- every case on the card's test list is present, plus extras (`//evil`, `.hidden.png`, `a..b.png`, a trailing newline, `x.svg`);
- the tests aren't vacuous;
- the static choice is fine.

## Deferred follow-ups

- **P2-1 / security P2:**
  - Add a comment in `backend/lib/menu_image.dart` pointing to the Flutter copy.
  - Optionally, a test in each package that runs the same list of accepted and rejected names.
  - Backend scope, so not in this shared card. Until then, a change to one copy must be made in the other by hand, like the order status list in `CLAUDE.md`.
- **P2-2:** tighten that one test's assertion to the message.

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` | 0 |
| `make test` (237 tests) | 0 |
| `make format-check` | 0 |
| `make boundaries` | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (237 app + 249 backend tests) | 0 |

## Unverified

No browser step in this card. The first `Image.network('/api/images/...')`, in `customer-menu-tile-shows-image`, should be checked through Caddy by the owner.
