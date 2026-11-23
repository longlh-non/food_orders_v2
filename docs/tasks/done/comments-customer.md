---
executor: task-executor
scopes: [customer]
workKinds: [documentation, flutter, quality-gate]
blockedBy: [comments-shared]
---

# Code comments: lib/customer

## Why

Same goal as `comments-shared`: a short plain-English comment above every function and widget, for the owner to learn from. Follow "The bar" in `docs/tasks/comments-shared.md` exactly (what gets a comment, length, keep/fix existing comments, no secrets or customer data).

## Sources

All `.dart` files under `lib/customer/`: `main.dart`, `state/` (`cart.dart`, `menu_state.dart`, `my_orders.dart`), `pages/` (`menu_page.dart`, `cart_page.dart`, `add_food_dialog.dart`). `menu_page.dart` already has good `///` comments; keep the correct ones and fill gaps only.

## Goal

Every in-scope declaration has a doc comment per the bar. For the `ChangeNotifier` singletons, say what they hold, who listens, and when they call `notifyListeners`.

## Non-goals

No logic, rename, or formatting change beyond `dart format`. No `analysis_options.yaml` change. No test files. No other directories.

## Requirements

1. Comments only, per the bar.
2. Active cards rewrite these files (`vi-translate-customer-ui`, `customer-menu-sold-out-items`, `customer-menu-tile-shows-image`, and since 2026-11-17 the UI refresh: `customer-menu-tile-redesign`, `customer-menu-category-icon-tabs`, `customer-bottom-nav-cart-button`). Recommendation: run this card when none of those is mid-flight, or after they merge. If a conflict happens, redo the comments on the new code; never fix a conflict by editing code.
3. Do not mention anything that is not true in the code today (for example sold-out or images are not implemented yet).

## Tests written with the change

None new. The existing suite passing shows behaviour is unchanged.

## Acceptance criteria and verification

- `make format-check`, `make analyze`, `make test`, `make boundaries` all exit 0 (run and recorded in the review).
- Diff is comment-only: no code token changed (`code-reviewer` checks).
- Comments are accurate (reviewer spot-check; a wrong comment is P1). Corrected old comments are listed in the review.
- Owner acceptance: comments are readable and helpful. Unverified until the owner confirms.

## Environment limits

No sudo, no commits by the agent.

## Decided by the owner (2026-11-12)

L1-L7 were accepted as recommended. They are recorded in `comments-shared` (in `docs/tasks/done/` once it is archived): no lint, no tests, no generated files, skip trivial members, English, one short clause per Flutter idea, and run when the files are quiet.
