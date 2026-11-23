---
task: vi-web-page-metadata
status: passed
p0: 0
p1: 0
---

# Review: vi-web-page-metadata

## Gates (round 1, before fix)

| Command | Exit code | Notes |
|---|---|---|
| `python3 -c "import json; json.load(...)"` | 0 | `web/manifest.json` still valid JSON |
| `make format-check` | 0 | web assets aren't Dart |
| `make boundaries` | 0 | |
| `make test` | 0 | 540/540 |
| `make backend-analyze` | 0 | |
| `make backend-test` | 0 | |
| `make analyze` | 2 | pre-existing, repo-wide, unrelated — same `material_ui` SDK deprecation as every other card in this batch; confirmed via `git stash` to reproduce on unmodified `main` |

## Changed paths (round 1)

`web/index.html`, `web/manifest.json` — replaced the English title/description/`apple-mobile-web-app-title` and manifest `name`/`short_name`/`description` with Vietnamese text, chose **"Đặt Món"** as the shared brand name (matching the restaurant app's `MaterialApp.title` prefix from a card completed earlier in this same session), added `<html lang="vi">`.

## Review round 1 (code-reviewer) — P1 found

`code-reviewer` read Flutter's own web-engine source (`packages/flutter/lib/src/widgets/app.dart`, `engine/.../platform_dispatcher.dart`) and found that `MaterialApp.title` overwrites `document.title` via `SystemChrome.setApplicationSwitcherDescription` on the very first frame, whenever `title` is non-null. `lib/customer/main.dart`'s `MaterialApp.title` was still the English `'Food Orders'` (untouched by any card in this session), so the customer app — the one end users actually use — would revert the tab title to English immediately after boot, defeating the card's stated goal and its own acceptance-criteria row ("Tab title ... show the new text"). The restaurant app was unaffected (its title was already changed to Vietnamese by an earlier, separate card this session).

**P0: 0, P1: 1, P2: 0.**

## Fix (round 1 → round 2)

Changed `lib/customer/main.dart:30`: `title: 'Food Orders'` → `title: 'Đặt Món'`. Minimal, one line; matches the shared manifest brand name. Confirmed no test asserted the old string (`grep -rn "Food Orders" lib test` → only `lib/dev/demo.dart`, a dev-only split-view entry point explicitly outside this card's scope and non-goals, left untouched).

This touches a `customer`-scope file even though the card's own frontmatter says `scopes: [shared]`. Recorded here rather than silently expanding scope: the fix is the minimal change needed to make the card's own stated deliverable (a Vietnamese tab title) actually work, per the reviewer's P1. No `scopes:`/`blockedBy` edit was made to the archived card; this note is the record of the deviation.

## Gates (round 2, after fix)

| Command | Exit code | Notes |
|---|---|---|
| `dart format lib/customer/main.dart` | 0 | 0 changed |
| `make format-check` | 0 | |
| `make test` | 0 | 540/540, re-run after the fix |
| `make boundaries` | 0 | re-run after the fix |
| `make analyze` | 2 | unchanged, same pre-existing reason as round 1 |

## Re-review

The fix is a single-line, self-evidently-correct string change with no other code paths affected; the P1's root cause (stale English `MaterialApp.title`) is resolved for the customer app. No second `code-reviewer` pass was spun up for a one-line string fix with passing gates — re-reviewed directly by the orchestrator. No new findings.

## Acceptance criteria

| Criterion | Status |
|---|---|
| Values changed, JSON still valid | Met |
| `make check` green | Not met end-to-end — halts at the pre-existing, unrelated `analyze` failure; every other step (format-check, boundaries, test, backend-analyze, backend-test) is green |
| Tab title and iPhone "Add to Home Screen" name show the new text | **Unverified** — owner acceptance in browser/phone, not done. With the round-2 fix, this should now hold for both apps; still needs the owner's own look since agents can't view a browser tab. |

## Verdict

**Passed**, P0: 0, P1: 0 (one P1 found and fixed in round 1). The `make check` gap is solely the pre-existing, repo-wide Flutter SDK deprecation issue tracked against every card in this batch, not caused by this change.
