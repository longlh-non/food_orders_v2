---
executor: task-executor
scopes: [customer, docs]
workKinds: [flutter, quality-gate, documentation]
blockedBy: [customer-menu-page-uses-backend-menu, shared-menu-item-image-field, customer-menu-category-tabs]
---

# Customer menu grid: show the item's picture, with the placeholder as fallback

Last card of the "menu item images" set. Plain UI, so no `securityReview` (the URL comes only from the validated `MenuItem.image` and `OrderApiClient`).

## Why

The grid tiles already reserve a placeholder block (see `customer-menu-page-uses-backend-menu`). Now it shows the real picture when there is one.

## Sources

`lib/customer/pages/menu_page.dart` (the tile and its placeholder widget), `lib/shared/models/menu_item.dart`, `lib/shared/api/order_api_client.dart` (`imageUrl`), `docs/tasks/customer-menu-page-uses-backend-menu.md`.

## Goal

1. In the tile, where the placeholder block is: if `item.image` is null, keep the placeholder exactly as today. Otherwise show `Image.network(url, fit: BoxFit.cover)` filling the same fixed-height block (the tile height must not change), with:
   - `errorBuilder` returning the placeholder (broken file, 404, offline: the tile still looks complete);
   - a quiet `loadingBuilder` (the placeholder is fine while loading);
   - `cacheWidth` of about 2x the tile width so a big photo is not decoded at full size (the executor picks a sensible constant);
   - `semanticLabel` = the item name.
2. No other layout change; the Add button and text keep their places; no overflow at 360 px or at text scale 1.3.
3. Docs: in `CLAUDE.md` "How the Flutter side consumes it", one line that the menu tile loads pictures from `/api/images/<name>` and falls back to the placeholder (approval requested by this card). Point to the serving card's "Editing the menu" text for how to add a photo; do not duplicate it.

## Non-goals

Zoom or full-screen view, lazy preloading, image on the topping sheet or cart, restaurant app changes, upload.

## Tests written with the change

Widget tests (inject a `MenuState` as in the page card; no real network):
- item with `image: null` shows the placeholder and no `Image` widget;
- item with an image builds an `Image` whose provider URL is `/api/images/<name>`; in the test environment the load fails, and the tile shows the placeholder (this covers the `errorBuilder` path; assert no exception is reported and the tile size is the same as the null case);
- a grid mixing both kinds at 360 px: two tiles per row, no overflow (also at `textScaler` 1.3).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Placeholder when image is null or fails; same tile size | `make test` (widget tests) |
| No overflow at 360 px / 1.3 text scale | `make test` |
| Boundaries, analyzer, format | `make boundaries`, `make analyze`, `make format-check` (gates) |
| Docs match behaviour | `code-reviewer` (review) |
| `make check` green | `make check` exit 0 (gate) |
| Owner copies a real photo into `backend/data/images/`, runs the `sqlite3` UPDATE, reloads `http://customer.local`: the photo shows in the tile; an item with no photo or a name whose file is missing still shows the placeholder | owner acceptance in the real environment, "unverified" until done |
| Same on iPhone Safari over `http://customer.local` (photo sharp, tile not clipped) | owner acceptance on the phone |
| A photo edit of a name used before can look stale for up to 5 minutes (cache); using a new file name shows immediately | owner acceptance (expected behaviour, documented) |

## Environment limits

Agents cannot load real pictures in a browser or on the phone; the owner does.

## Order change (owner, 2026-11-11)

Now blocked by `customer-menu-category-tabs`: both cards edit the menu page, and the tabs card restructures it. Run this one after it, so it adds photos to the tab grids.

## Owner approval and executor notes (2026-11-13)

- **Owner approval:** the owner approved the one-line `CLAUDE.md` edit for this card.
- **Helper name:** the card's Sources say `imageUrl`. The shared card shipped it as `static OrderApiClient.imageUrlFor(MenuItem)`, which this card uses.
- **Decode width:** `cacheWidth` is 480. Tiles are at most 220 px wide, so that's about twice the tile width.
- **Failed-load test:** it waits on real time (`runAsync`) for the test environment's network error, then checks the placeholder. Removing `errorBuilder` makes that test fail, so it really covers the error path.
