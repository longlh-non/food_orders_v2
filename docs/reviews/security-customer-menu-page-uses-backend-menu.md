---
task: customer-menu-page-uses-backend-menu
status: passed
p0: 0
p1: 0
reviewedFiles:
  - lib/customer/pages/menu_page.dart
  - lib/customer/state/cart.dart
  - lib/customer/state/menu_state.dart
  - lib/shared/models/menu_item.dart
  - lib/shared/api/order_api_client.dart
---

# Security review — customer-menu-page-uses-backend-menu

Independent first-pass review by `security-reviewer` (tool-restricted, read-only), 2026-11-10. `securityReview: required` was added during execution, because the diff changes JSON parsing (duplicate-id rejection) and logging (`kDebugMode`).

## Scope

- **Asset:** what the customer believes they're buying and paying for.
- **Input:** the `/api/menu` JSON (name, description, price, id). The owner edits it, and anyone on the LAN can reach it.
- **New capability:** menu text now reaches the UI, and through `Cart.refreshItems` it reaches cart lines.

## Checked with no issues found

- **Plain text only:** all menu text uses plain `Text`. There's no `RichText`, `SelectableText`, markdown, HTML, links or URL launching.
- **No leaked details:** the error state is a constant string, and a test checks that a 502 body isn't shown. Snackbars show counts only.
- **Already handled:** duplicate ids are rejected, and `kDebugMode` gates the logging.
- **Listeners:** added and removed in balance, with a `mounted` guard.

## Findings (first pass): P0 0 · P1 0 · P2 3

- **P2-1** `cart.dart:50`, `menu_page.dart:67`: a price change was applied to cart lines silently, and only removals were announced. **Fixed:** `refreshItems` also returns `repriced`, and the snackbar says "The price of 1 item in your cart changed" or "Prices of N items in your cart changed".
- **P2-2** `menu_page.dart:323`: a name can fake a price or button. `"Burger\n$0.01"` renders a second line that looks like a price, and bidi or zero-width characters can reorder or hide text. **Fixed** in `MenuItem.fromJson`: line breaks become spaces, and control, zero-width and bidi characters are removed.
- **P2-3**: huge strings or many items could make the client freeze the tab. **Deferred:** this is the already-tracked unbounded-size item on `backend-request-body-limit`.

Also noted, but outside this card's diff: `_shortId` throws a `RangeError` for an order id shorter than 4 characters. It's on the order path and predates this change.

## Re-review 1

P2-1 is fixed. P2-2 was only partly closed: U+2028 and U+2029 (line and paragraph separators, which Flutter renders as line breaks) and U+061C and U+180E were missing.

## Re-review 2

**Still passed.** The residual is fixed:
- U+2028, U+2029 and U+0085 now become spaces;
- U+061C and U+180E are stripped;
- the code reviewer asked to keep the joiners U+200C and U+200D, which is acceptable, since they can't reorder text or add line breaks;
- a name that's empty after cleanup is rejected;
- the source is pure ASCII.

No new findings.

**Counts:** P0 0 · P1 0 · P2 1 open (P2-3, deferred to `backend-request-body-limit`).
