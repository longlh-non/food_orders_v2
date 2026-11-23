---
task: comments-shared
status: passed
p0: 0
p1: 0
---

# Review: comments-shared

## Gates (round 1)

| Command | Exit code | Notes |
|---|---|---|
| `dart format <touched files>` | 0 | 0 changed |
| `make format-check` | 0 | |
| `make boundaries` | 0 | |
| `make test` | 0 | 540/540 |
| `make analyze` | 2 | pre-existing, repo-wide, unrelated — same `material_ui` SDK deprecation tracked against every card in this batch |
| `make backend-analyze` / `make backend-test` | not run | no backend files touched |

## Changed paths (round 1)

`lib/shared/models/order.dart` (comment additions only; its diff also contains an already-reviewed-and-passed Vietnamese-translation hunk from a separate card, excluded from this review), `lib/shared/models/menu_item.dart`, `lib/shared/theme.dart`, `lib/shared/api/order_repository.dart`, `lib/shared/chime_web.dart`.

Most of `lib/shared/` was already compliant with "the bar" from earlier cards; this card filled genuine gaps: `OrderTopping.toJson`/`fromJson`, `Order.toJson`/`fromJson`, `restaurantTheme()`, `OrderRepository.dispose()`, `chime_web.dart`'s `_context()`, plus one `//`→`///` marker conversion each in `menu_item.dart` and `chime_web.dart`.

## Review round 1 (code-reviewer) — P1 found

Independent audit of all 11 files under `lib/shared/` confirmed the implementer's claim that most were already compliant, and found zero code-token changes beyond comment lines (translation hunk correctly excluded). One real defect: `lib/shared/models/menu_item.dart`'s `operator==` comment (pre-existing text, this diff only converted `//`→`///`) was factually wrong — it claims `Cart` uses `MenuItem` as a Map key, but `Cart._lines` is keyed by `CartLine` (which has its own id-based equality), not `MenuItem`; the only place `MenuItem`'s equality is actually exercised as a Map key is a test. The card's own rule ("fix wrong or stale [comments]... any wrong comment is P1") was not followed before this diff touched that exact line.

Three P2s: a new `restaurantTheme()` comment that duplicated (rather than pointed back to) `customerTheme()`'s existing comment; four `price` fields (`OrderTopping`, `OrderItem`, `Topping`, `MenuItem`) missing the unit/format note that the bar's own L4 rule gives as the canonical example ("VND, whole number"); and an `OrderRepository.dispose()` comment that mildly overclaimed test coverage ("exists for correctness and for tests" — grep found no test calls it).

**P0: 0, P1: 1, P2: 3.**

## Fix (round 1 → round 2)

All four findings fixed in one batch, each a pure comment edit (no code tokens touched, verified by `git diff -U0` on every touched file):
- `menu_item.dart` — reworded the `operator==` comment to the reviewer's suggested, accurate text; also added the missing `price` unit comment (P2).
- `order.dart` — added the missing unit comment to `OrderTopping.price` and `OrderItem.price`.
- `models/topping.dart` — added the missing unit comment to `Topping.price` (file wasn't in round 1's touched-file list; this is a one-line addition to close the same P2 class of finding there too).
- `theme.dart` — shortened `restaurantTheme()`'s comment to point back at `customerTheme()` instead of restating it.
- `api/order_repository.dart` — softened the `dispose()` comment to "exists to satisfy ChangeNotifier's contract" instead of claiming test coverage.

## Gates (round 2, after fix)

| Command | Exit code | Notes |
|---|---|---|
| `dart format <touched files>` | 0 | 0 changed |
| `make format-check` | 0 | re-run |
| `make test` | 0 | 540/540, re-run |
| `make boundaries` | 0 | re-run |

## Re-review

All five edits are pure comment changes (confirmed via `git diff -U0`, no non-`///` line altered); the P1's factual content is now correct and the P2 fixes are the exact wording the reviewer proposed. No second `code-reviewer` pass was spun up for this small, mechanically-verified follow-up; re-reviewed directly by the orchestrator. No new findings.

## Acceptance criteria

| Criterion | Status |
|---|---|
| `make format-check` / `make analyze` / `make test` / `make boundaries` | format-check/test/boundaries: 0. `analyze`: 2, pre-existing/unrelated (see above). |
| Comment-only diff (code tokens unchanged) | Met, verified by hand both rounds |
| Accuracy (reviewer spot-checks) | Met after the round-1 fix |
| Coverage | Met for the 5 touched files; the rest of `lib/shared/` was already compliant per independent audit |
| Owner acceptance of comment helpfulness | **Unverified** — owner hasn't read them yet, per the card's own terms |

## Verdict

**Passed**, P0: 0, P1: 0 (one P1 found and fixed in round 1, three P2s found and fixed alongside it rather than deferred). The `make check`/`make analyze` gap is the same pre-existing, repo-wide Flutter SDK issue tracked against every card in this batch.
