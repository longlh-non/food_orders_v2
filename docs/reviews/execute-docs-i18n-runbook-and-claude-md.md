---
task: docs-i18n-runbook-and-claude-md
status: passed
p0: 0
p1: 0
---

# Review: docs-i18n-runbook-and-claude-md

Owner approved editing `CLAUDE.md` and `docs/runbook-local.md` for this task, and chose to close LANG5 as "ships as unverified" for the 8 machine-translated languages (answers to the pre-run question, 2026-11-23). Only those two files changed; the contract half of `CLAUDE.md` (from `# Engineering contract`) was diffed against HEAD by the orchestrator and is byte-identical.

## Gates

| Command | Exit | Notes |
|---|---|---|
| `make format-check` | 0 | |
| `make check` | 2 | stops at `make analyze` (28 baseline `deprecated_member_use` infos, unchanged: docs-only card touches no Dart). Test/backend gates were last run green on the previous card's candidate; this card changes no code. |

## Findings (code-reviewer): P0 0, P1 1 (fixed), P2 3

- P1 fixed: runbook step 4 for adding an 11th language missed `test/restaurant_l10n_test.dart` (`hasLength(10)` on `supportedLocales`). Added, plus "any other test that fails after step 2 pins the list".
- P2 fixed: the Lao check is now described as Material text only.
- P2 deferred: the owner's "ships as unverified" acceptance and the `vi` row's "owner-accepted" status are recorded from this session's answers and the earlier translation cards; there is no standalone decision file. The 2026-11-23 date is the doc date.
- P2 cosmetic: the log table row order differs from picker order.

All other claims (locale list/order/default, storage key, picker names and placement, `onGenerateTitle` keys, `l10n.yaml`, dependencies, `web/index.html`, CI Flutter 3.47.7, `arb_completeness_test` behaviour) were checked against the code and are correct. The 11-language procedure was not run end to end.

## Unverified

Wording of 9 of 10 languages (no fluent reviewer); CI regenerating identical l10n files on Flutter 3.47.7; picker and glyph rendering in a browser.

## Follow-ups noted

`lib/shared/l10n/README.md` could point to the review log; dead `OrderStatus.label` / `PaymentMethod.label` in `lib/shared/models/order.dart` (see `execute-restaurant-l10n-wiring.md`).

## Verdict

**Passed**, P0: 0, P1: 0.
