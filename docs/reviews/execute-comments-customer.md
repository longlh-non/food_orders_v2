---
task: comments-customer
status: passed
p0: 0
p1: 0
---

# Review: comments-customer

## Gates (final candidate)

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | |
| `make analyze` / `make check` | 2 | 19 pre-existing `deprecated_member_use` infos (`material_ui` SDK issue); count unchanged, nothing new from these files |

Comment-only proof: the sorted set of non-comment `+/-` lines in `git diff -U0 lib/customer` is identical before and after the fix round (implementer, 65 lines) and identical to the earlier translation candidate for `pages/` and `state/` (orchestrator check).

## Changed paths (comments only)

`lib/customer/main.dart`, `state/cart.dart`, `state/menu_state.dart`, `state/my_orders.dart`, `pages/menu_page.dart`, `pages/cart_page.dart`, `pages/add_food_dialog.dart`. Not in the card's Sources, deliberately left alone: `pages/payment_qr_page.dart`, `api/payment_client.dart` (partly commented already).

## Round 1 (code-reviewer): FAIL — P0 0, P1 2, P2 ~12

P1: `Cart.itemCount` comment said "AppBar badge" (it is the round cart button's badge); `AddItemButton` comment described unimplemented sold-out handling. P2: the first attempt had only corrected quoted labels; singleton comments (holds / listeners / notify points), lifecycle comments, `build` comments and the rest of the bar were missing.

## Fix round 1

Both P1 fixed; all listed gaps filled (singletons, `main.dart`, menu/cart pages, add-food dialog, `initState`/`dispose` listener lists, `_placeOrder` flow, banner wording).

## Re-review 1 (code-reviewer): PASS — P0 0, P1 0, P2 2

Every new comment was checked against the code and found true. Deferred P2s:
1. `cart_page.dart:52` `PaymentClient? _ownClient` has no comment (created lazily, closed in `dispose`).
2. Two comment lines past 80 columns (`cart.dart:74`, `menu_page.dart:620`); `dart format` doesn't wrap comments.

## Unverified

Owner acceptance that the comments are readable and helpful.

## Verdict

**Passed**, P0: 0, P1: 0.
