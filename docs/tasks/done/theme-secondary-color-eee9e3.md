---
executor: task-executor
scopes: [shared]
workKinds: [flutter, quality-gate]
blockedBy: []
---

# Add the second brand colour #EEE9E3 (cream app background)

## Why

Owner request: "change the second major color to #eee9e3" (a very light warm beige). The first colour, #7E1109, was set by `docs/tasks/done/theme-primary-color-7e1109.md`. Same shape of change. The request does not say which Material 3 role "second colour" means, so see SEC1: the card assumes the recommended answer.

## Sources

- `lib/shared/theme.dart`: `_brand`, `_brandScheme()` = `fromSeed(...).copyWith(primary: _brand, onPrimary: Colors.white)`, shared by `customerTheme()` and `restaurantTheme()`.
- `test/theme_test.dart`: `contrast()` helper, brand and contrast assertions per theme.
- Colour roles in use (planner's search of `lib/`): no widget hard-codes a colour; all use `colorScheme` roles.
  - `Scaffold` background (menu, cart, orders, demo) = `surface`.
  - `Card` (menu tile `menu_page.dart:368`, cart `cart_page.dart:111`, orders `orders_page.dart:145`) = default M3 card colour `surfaceContainerLow`.
  - "Your orders" banner `menu_page.dart:307` = `primaryContainer` with `onPrimaryContainer` text.
  - Tile image placeholder `menu_page.dart:514` = `secondaryContainer` with `onSecondaryContainer` icon.
  - `FilledButton.tonal` (tile Add button, `menu_page.dart:412`) = `secondaryContainer`.
  - `Chip` in `orders_page.dart:159` = default chip colours (surface-based outline).
  - Error line `cart_page.dart:192` = `error`.
- `web/manifest.json`: `background_color` and `theme_color` are both `#7E1109`.

## What "second major colour" can mean (plain words)

#EEE9E3 is a pale cream. It is about 14:1 lighter than dark text, so it can only be a background, never text, an icon, or a filled button (white text on it would be unreadable, about 1.2:1).

- (a) `secondary` itself. Rejected. `secondary` is used for text and icons that must stand out on light backgrounds. Cream would be nearly invisible (about 1.2:1 against white). Nothing in the app would visibly use it well.
- (b) `secondaryContainer` only. What changes: the tile image placeholders and the tonal "Add" buttons turn cream. Everything else stays white/pink-grey. Small, safe change, but the cream shows up only as little patches, so it would not feel like a "major" colour. On a white card the cream button is faint (cream on white is about 1.2:1; the button needs its text to carry it, which dark text does).
- (c) page background `surface` (plus cards pinned to white). What changes: every screen of both apps gets a warm cream background behind the white cards, with dark-red app bar and buttons. This is the usual meaning of a brand's second colour (dark red plus cream), and it is the only option where the cream is clearly visible. Banner stays pink, buttons stay red.
- (d) both (b) and (c). More change, and cream-on-cream on the tonal button would disappear against the cream page (the Add button sits on a white card, but the placeholder box would look washed out). Not recommended.

**Recommendation: (c).** Reason: it makes cream the second colour the owner will actually see, and it needs only two pinned values in one file. `secondaryContainer` stays as Material derives it, so the tonal Add buttons and placeholders keep their current look.

## Goal (recommended answers SEC1-SEC4 assumed)

1. In `theme.dart`, add `const _cream = Color(0xFFEEE9E3);` with a doc comment (name the hex and the contrast numbers below).
2. `_brandScheme()` keeps `fromSeed(...)` and `copyWith`, now also `surface: _cream` and `surfaceContainerLow: Colors.white` (cards).
3. Do not set `onSurface`. Material's derived `onSurface` (a near-black warm grey) is kept; the test checks it.
4. Do not change `secondary`, `secondaryContainer`, `primaryContainer`, `error`, or any widget.
5. SEC3: set `web/manifest.json` `background_color` to `#EEE9E3` (the splash shown while the app loads becomes cream). Leave `theme_color` at `#7E1109` (the browser bar matches the app bar). No other manifest key.

## Non-goals

No dark theme, no new dependency, no widget changes, no fonts or shapes, no icon image changes, no `CLAUDE.md` edit, no separate palette per app.

## Contrast (planner's hand calculation, WCAG)

- #EEE9E3 luminance is about 0.82.
- `onSurface` (about #1F1B1A, luminance about 0.012) on cream: about **14:1**. Passes AAA.
- `onSurfaceVariant` (secondary body text, tone ~30) on cream: about 7-8:1. Passes AA.
- Pink `primaryContainer` (tone ~90, luminance about 0.78) sits slightly darker than cream; the banner reads as a soft pink strip with dark red text on a cream page. The banner's own text contrast is already tested (at least 4.5).
- White cards on cream: the card edge is subtle (about 1.2:1 between the two), so it is a soft separation, as intended. If Card has no elevation tint in M3 (surfaceTint is off by default in recent Flutter), the card stays pure white. If the owner wants a clearer edge, a later card can add a thin outline.
- If the cards were left on the derived `surfaceContainerLow` (a slightly pink-grey tone) they would look dingy next to cream. That is why the card pins it to white (SEC2).

## Tests written with the change

Update `test/theme_test.dart` (no new dependency; reuse `contrast()`):

- Add `const cream = Color(0xFFEEE9E3);`. Per theme (inside the existing loop): `surface` equals cream exactly; `surfaceContainerLow` equals white.
- Per theme: `contrast(onSurface, surface)` is at least 4.5; `contrast(onSurfaceVariant, surface)` is at least 4.5; `contrast(onSecondaryContainer, secondaryContainer)` is at least 4.5 (keeps the tonal buttons and placeholder honest).
- Keep all existing assertions (primary, onPrimary, contrast, Material 3, shared scheme). The `primaryContainer` pair stays.
- Not tested: the manifest (JSON asset, reviewer and owner check it) and how it looks.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Both themes: `surface` exactly #EEE9E3, cards white, primary still #7E1109 | `test/theme_test.dart` via `make test` (gate) |
| onSurface, onSurfaceVariant on cream and onSecondaryContainer on secondaryContainer are each at least 4.5:1 | same test file (gate) |
| `make check` green (format, analyze, test, backend gates, boundaries) | `make check` exit 0 (gate) |
| Only `theme.dart`, `theme_test.dart`, `web/manifest.json` changed; no widget touched; manifest `background_color` is `#EEE9E3`, `theme_color` unchanged | `code-reviewer` (review) |
| Cream page, white cards, pink banner, red buttons look coherent in both apps; cart error line readable; splash colour; phone bar | owner acceptance in the browser and on the iPhone: "unverified" until done |

## Environment limits

Agents cannot see rendered colours, the splash, or the iPhone (iOS Safari mostly ignores manifest colours, so no change may show there). Contrast numbers above are hand-computed; the tests are the real check. The card shade on cream is a visual judgement for the owner.

## Ordering

Independent; touches `theme.dart`, `theme_test.dart`, `web/manifest.json` only. `vi-web-page-metadata` also edits `web/manifest.json` (different keys), so whichever lands second just rebases a line. Run this one now.

## Open decisions (owner)

- **SEC1: which role is the "second colour"?** Recommend (c), cream page background with white cards. Say (b) if you only want the little Add buttons and image boxes cream, or (d) for both.
- **SEC2: cards white or derived?** Recommend white (pinned `surfaceContainerLow`). Alternative: leave Material's derived card tone (a faint pink-grey), which gives less of a clean look on cream.
- **SEC3: splash colour in `web/manifest.json`?** Recommend yes: `background_color` cream, `theme_color` stays dark red. Say no and drop requirement 5 to keep the card to `theme.dart` only.
- **SEC4: both apps or only one?** Recommend both (one brand, as before). Only-one would mean splitting `_brandScheme()`.

## Decided by the owner (2026-11-17)

Every recommendation was accepted:
- **SEC1 = (c):** #EEE9E3 is the page background (`surface`).
- **SEC2:** cards are pinned to white.
- **SEC3:** the manifest `background_color` becomes #EEE9E3, and `theme_color` stays #7E1109.
- **SEC4:** both apps.

The owner's reference design, `design/red-1.jpg`, confirms it: cream page, white rounded cards, dark-red accents. That image is a third-party brand mockup, used as **style inspiration only**. Never copy its logo, names or slogans.
