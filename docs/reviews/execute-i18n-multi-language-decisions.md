---
task: i18n-multi-language-decisions
status: passed
p0: 0
p1: 0
---

# Review: i18n-multi-language-decisions

A decision card with no code: it is done when every LANG item has a dated, recorded owner answer. Run on the owner's request `/execute-tasks i19n-multi-language-decisions` (a typo; the card is `i18n-multi-language-decisions`).

## Gates

| Command | Exit code | Notes |
|---|---|---|
| `make format-check` | 0 | no Dart touched |
| `make check` | 2 | stops at `analyze`: 22 infos, all `deprecated_member_use` on the `package:flutter/material.dart` import (known `material_ui` SDK issue); no code changed in this card |

## Changed paths

`docs/tasks/i18n-multi-language-decisions.md` only (the `## Decided (owner, 2026-11-23)` section and a "Web page files" subsection were appended before archiving). Nothing else; the downstream cards were not edited.

## Owner answers recorded (2026-11-23, given interactively)

LANG1 reverse VI1/VI2: yes. LANG2 runtime switching: yes. LANG3 `intl` + `flutter_localizations` + ARB approved, `shared_preferences` not approved, for this card set only. LANG4 `en, vi, zh` (Simplified), `lo, es, fr, ru, de, ko, ja`, default `vi`, Vietnamese and English first then alphabetical by native name. LANG5 the agent drafts all strings, wording unverified until a fluent speaker confirms. LANG6 backend text out of scope. LANG7 moot (`vi-translate-customer-ui` already archived). LANG8 `localStorage` conditional-import shim. Web files: `web/index.html` and `web/manifest.json` stay Vietnamese; the tab title follows the picker at runtime via `MaterialApp.onGenerateTitle` (confirmed by the owner).

## Findings (code-reviewer): P0 0, P1 1, P2 4

**P1 (fixed):** the Decided section said the web page files must move behind the translation mechanism (LANG1), but no downstream card owned them, and static HTML can't read ARB files. Fixed: LANG1's entry no longer lists them; a "Web page files" subsection records the owner-confirmed decision above, and tells the wiring cards not to touch `web/**`. Not re-sent to a reviewer: a wording change recording an answer the owner then gave.

**P2:** "Every answer is the card's own recommendation" was imprecise (LANG1 a confirmation, LANG7 moot): reworded (fixed). Deferred follow-ups for whoever runs the downstream cards:
1. `customer-l10n-wiring.md` lines 14-19, 25, 31 still describe `vi-translate-customer-ui` as "still active, not yet run" and carry an "if it has not run" fork; only the "has run" fork applies now (tidy when that card starts). Both forks are described, so an executor is not misled.
2. `wiring cards` should add `MaterialApp.onGenerateTitle` for the tab title (web decision above); `web/**` stays untouched.
3. VI1/VI2 are described as "recorded" in `vi-translate-shared-and-restaurant-ui.md`, which only has a `## Decided` entry for VI3 (VI1/VI2 appear as assumptions); substance holds.
4. The old English strings are only partly recoverable (one commit in git, much uncommitted); `shared-l10n-infrastructure.md` already covers this with a "redrafted-not-restored" flag.

## Still open (not decided by this card)

Editing `CLAUDE.md` for the l10n work needs the owner's explicit approval for that task when `docs-i18n-runbook-and-claude-md` runs. Whether Flutter's built-in `MaterialLocalizations` covers Lao is checked in `shared-l10n-infrastructure`.

## Verdict

**Passed**, P0: 0, P1: 0.
