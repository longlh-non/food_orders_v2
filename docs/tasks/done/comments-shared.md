---
executor: task-executor
scopes: [shared]
workKinds: [documentation, flutter, quality-gate]
blockedBy: []
---

# Code comments: lib/shared (also defines the comment bar for all comment cards)

## Why

The owner is new to Flutter and wants a short comment above every function and widget, to learn and follow the code. This card goes first because it defines "the bar" (below). The other three comment cards (`comments-customer`, `comments-restaurant-and-dev`, `comments-backend`) point back here.

## Sources

All `.dart` files under `lib/shared/` (models, api, `money.dart`, `theme.dart`, `chime*.dart`). Style reference: the existing `///` comments in `lib/customer/pages/menu_page.dart` and `backend/lib/staff_gate.dart`.

## Goal

Every in-scope declaration has a plain-English `///` doc comment that follows the bar.

## Non-goals

No logic change, no rename, no moved code, no reformatting beyond `dart format`. No new dependency. No `analysis_options.yaml` change (see open decision L1 in the plan). No test files, no generated files, no `pubspec.*`. No `securityReview` (comment-only).

## The bar (applies to all four comment cards)

What gets a comment (`///`, directly above the declaration):
- Every class, mixin, enum, extension, typedef, and every Flutter widget (`StatelessWidget` / `StatefulWidget` and its `State`): one comment saying what it is and where it is used.
- Every function and method, public or private, top-level or inside a class, including constructors that do something non-obvious (for example `fromJson` / `toJson` / factory).
- `build` methods: one line on what the screen or piece of UI looks like and what it watches (for example "rebuilds when the cart changes").
- Lifecycle overrides (`initState`, `dispose`, `didChangeDependencies`): one short line on what is set up or released and why. This teaches the pattern to a Flutter beginner.
- Skipped on purpose: trivial getters/setters and plain fields whose name already says it, `main` wrappers that only call `runApp` (one line is still fine), `@override` of `toString`/`==`/`hashCode` (comment only if non-standard), local functions of 1-2 lines. Fields get a comment only when the unit, format, or meaning is not obvious (for example "VND, whole number").
- Closures passed as arguments (`onPressed: () {...}`) get a comment only if long or surprising.

What a good comment says:
- Why and what, not a restatement of the code. "Adds one to quantity" above `quantity + 1` is useless; "Merges lines with the same dish and toppings so the cart shows one row" is good.
- Mention side effects (notifies listeners, network call, SSE reconnect, writes to the database) and anything that is easy to get wrong (timezones, VND whole numbers, "base price excludes toppings").
- Explain Flutter ideas in one clause the first time they matter in a file (for example "ListenableBuilder rebuilds this part when the notifier calls notifyListeners"), but do not write tutorials.
- Length: 1 line for simple things, 2-4 lines normally, never more than about 6. First sentence stands alone as a summary and ends with a period.
- English, plain words, short sentences. No emojis.

Existing comments:
- Keep correct ones as they are. Do not reword for taste, do not duplicate them.
- Fix wrong or stale ones (compare against the code and `CLAUDE.md`), and list each fix in the review so the reviewer can check it.
- Convert a plain `//` comment directly above a declaration to `///` only when it describes that declaration.
- Leave `// ignore:` and `// TODO` lines untouched.

Never put secrets, tokens, real customer names, phone numbers, or real order data in comments or examples. Use obviously fake values (`'Alice'`, `25000`).

## Requirements

1. Add or fix comments per the bar in every `.dart` file under `lib/shared/`.
2. Do not touch code tokens. The diff, with comment lines and blank lines removed, must equal the original diff-free code.
3. Active cards edit some of these files (`vi-translate-shared-and-restaurant-ui`, `vi-web-page-metadata`, `shared-menu-item-image-field`, `menu-item-available-and-staff-client`). Rebase onto whatever is merged; if a conflict happens, redo the comments on the new code (cheap), do not resolve by editing code.

## Tests written with the change

None new. Comment-only. The existing suite passing is the proof that behaviour is unchanged.

## Acceptance criteria and verification

- `make format-check` exit 0 (run `make format` first if needed; it must change only comment layout).
- `make analyze` exit 0.
- `make test` exit 0.
- `make boundaries` exit 0.
- Comment-only: reviewer checks the diff (for example `git diff -w` ignoring `///` lines) shows no code token changed. Verified by `code-reviewer`.
- Accuracy: reviewer spot-checks every comment against the code; any wrong comment is P1.
- Coverage: every in-scope declaration has a comment or is covered by a "skipped on purpose" rule. Missing comments on a public class or widget are P2, not a blocker.
- Owner acceptance (not CI): the owner reads a few files and finds the comments helpful. Mark "unverified" until the owner says so.

## Environment limits

Agents do not run `sudo` and do not commit. `make` targets only.

## Decided by the owner (2026-11-12)

Every recommendation was accepted. These apply to all four comment cards:
- **L1:** no `public_member_api_docs` lint; `analysis_options.yaml` stays unchanged.
- **L2:** no comments in `test/` or `backend/test/`.
- **L3:** no generated files and no `pubspec.*`.
- **L4:** skip trivial getters and obvious fields. A field gets a comment only for a unit or format.
- **L5:** comments are in English.
- **L6:** explain a Flutter idea with one short clause, the first time it matters in a file. No tutorials.
- **L7:** no `blockedBy` on feature cards. Run each comment card when no other active card is editing its files. On a clash, redo the comments on the new code; never resolve a clash by editing code.
