---
task: customer-menu-tile-shows-image
status: passed
p0: 0
p1: 0
---

# Review: customer-menu-tile-shows-image

Independent reviewer: `code-reviewer` (read-only). No security review: plain UI, and the URL comes only from the validated `MenuItem.image` through `OrderApiClient.imageUrlFor` (reviewed in `shared-menu-item-image-field`). The card has no `securityReview`.

## Candidate

- **`lib/customer/pages/menu_page.dart`:** the tile uses a new `_TileImage(item, height: 96)`.
  - **No picture:** if `imageUrlFor` returns null, the placeholder shows exactly as before.
  - **With a picture:** `SizedBox(height: 96, width: infinity)` holds `Image.network(url, fit: cover, cacheWidth: 480, semanticLabel: item.name)`.
    - `frameBuilder` shows the placeholder until the first frame; a cached picture shows at once.
    - `errorBuilder` shows the placeholder.
- **`test/menu_page_test.dart`:** new group "tile pictures":
  - no picture: the placeholder and no `Image`;
  - with a picture: the provider is `ResizeImage(NetworkImage('/api/images/xoi-thit.webp'))`. After the test environment's network error there is no exception, the placeholder shows, and the card is the same size as one without a picture;
  - a mixed grid at 360 px, text ×1.0 and ×1.3: 2 per row, no exception.
  - The failed-load test was proven not vacuous (removing `errorBuilder` makes it fail), first in round 1 and again after the fixes.
- **`CLAUDE.md` (owner-approved):** one bullet under "How the Flutter side consumes it".

## Round 1: passed. P0 0, P1 0, P2 3

- **P2-1:** `loadingBuilder` with `progress == null ? child : placeholder` could leave the tile blank before the first chunk event.
- **P2-2:** `cacheWidth: 480` is a constant. That's fine for phone tiles (about 170 px wide) up to 3× pixel density, and slightly soft for a 220 px tile at 3×.
- **P2-3:** the test waited a fixed 100 ms of real time.

Checked and correct:
- Goals 1–3;
- the tile height is unchanged (tight constraints, `Clip.antiAlias`);
- the docs match the behaviour;
- boundaries;
- no test is vacuous.

## Fixes

- **P2-1:** `frameBuilder: wasSynchronouslyLoaded || frame != null ? child : placeholder` replaces `loadingBuilder`. The tile is never blank.
- **P2-2:** the comment explains the 480 px choice; the constant is kept.
- **P2-3:** a `settleImages` helper waits in short real-time steps. The re-review noted that with `frameBuilder` the placeholder shows from the start, so there's no signal to poll for. The helper is now an honestly documented fixed wait of about 100 ms. The failed-load test still fails without `errorBuilder`, so the error does arrive within the wait.

## Re-review 1: passed. P0 0, P1 0

## Deferred / notes

- **Test wait:** a fully deterministic version would inject a failing `HttpClient` through `HttpOverrides` instead of waiting on real time. The risk is low: the test environment's error is immediate.
- **Screen readers:** `semanticLabel` repeats the visible name, so a screen reader may read the name twice. The card requires the label. If it bothers screen-reader users, wrap the image in `ExcludeSemantics` (a card change).

## Gates (this session)

| Command | Exit code |
|---|---|
| `make analyze` (round 1 and after fixes) | 0 |
| `make test` (241 tests, round 1 and after fixes) | 0 |
| `make format-check` (round 1 and after fixes) | 0 |
| `make boundaries` (round 1 and after fixes) | 0 |
| `git diff --stat pubspec.yaml` (empty) | 0 |
| `make check` (final candidate; 241 app + 249 backend tests) | 0 |

## Unverified (owner acceptance)

1. Copy a real photo into `backend/data/images/`, run the `sqlite3` UPDATE and reload `http://customer.local`. The photo should show in the tile.
2. An item with no photo, or with a name whose file is missing, should still show the placeholder.
3. On iPhone Safari, the photo should be sharp and the tile not clipped.
4. A changed photo under an old name can look stale for up to 5 minutes; a new file name shows at once.
