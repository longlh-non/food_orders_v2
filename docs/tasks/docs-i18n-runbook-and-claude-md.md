---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [restaurant-l10n-wiring, customer-l10n-wiring]
---

# Docs: record the multi-language setup in `CLAUDE.md`, close out translation-quality review

## Why

Every card before this one changed code and left wording-quality for 8 of the 10 languages explicitly "unverified" (LANG5). This card is where that gets closed out and where the permanent record of how the system works gets written, mirroring how `docs-owner-runbook-local.md` and `docs-payment-and-reports.md` closed out earlier features.

**Editing `CLAUDE.md` needs the owner's explicit approval for this specific task** — per the Safety policy, approval for the earlier cards in this set (LANG1/LANG3 etc.) does not carry over to editing `CLAUDE.md` itself. Ask before starting the `CLAUDE.md` part of this card, even if the owner approved everything else already.

## Sources

`CLAUDE.md` ("Layout" section — add `lib/shared/l10n/` and the locale controller/picker to the file tree; "State management" section — note the one approved dependency pair and why it's an exception to "no new dependency without approval"; a new short subsection analogous to "Notifications" or "Mobile access" describing how language switching works, where it's stored, and the default), `docs/runbook-local.md` (owner's step-by-step doc — add "how to change the app's language" and, if LANG5 left any language's wording flagged unverified, "how to review/update one language's wording" as an owner task, similar to how staff ID/password steps are documented there).

## Goal

1. Update `CLAUDE.md` as scoped above. Keep it factual and current-state, matching the file's existing terse style — no speculative "future language" language, just what exists after this card set lands.
2. Update `docs/runbook-local.md` with the owner-facing steps: how to open the language picker, how to add an 11th language later (which files to touch: one more ARB file per locale, one more entry in `LocaleController`'s supported list, one more native-name entry in the picker, re-run `test/shared/arb_completeness_test.dart`), and how to flag a specific language's wording as reviewed-and-approved (since this card is where that review should land per language, record it the same way `vi-translate-shared-and-restaurant-ui.md` recorded VI1–VI3: a dated `## Decided` / `## Reviewed` entry per language, in this card or a successor).
3. Resolve the "unverified" flags left by `shared-l10n-infrastructure`, `restaurant-l10n-wiring`, and `customer-l10n-wiring` for the 8 non-Vietnamese, non-English languages: either a fluent/native reviewer confirms each one's wording (recorded here with date and reviewer), or the owner explicitly accepts shipping some languages as machine-translated drafts with a documented caveat visible to whoever maintains this later (e.g. a short note in `CLAUDE.md`'s new subsection: "Chinese/Lao/Spanish/French/Russian/German/Korean/Japanese wording was machine-translated and has not been confirmed by a fluent speaker as of <date>").

## Non-goals

No code changes (this is a docs-only card; if a code gap is found while writing docs, file a new card instead of fixing it here). No backend documentation changes beyond what LANG6 already settled as out of scope.

## Tests written with the change

None — this card produces no code. (If LANG6 was decided "in scope" by the time this card runs, that decision implies at least one more code card exists upstream of this one; this card does not retroactively create it.)

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| `CLAUDE.md` accurately describes the shipped localisation setup (files, dependency, default, storage) | owner review (owner must explicitly approve this specific edit to `CLAUDE.md` per the Safety policy) |
| `docs/runbook-local.md` has clear, followable steps for changing language and adding a future one | owner review |
| Every one of the 8 machine-translated languages has either a recorded reviewer sign-off or an explicit owner-accepted "ships as unverified" note | owner review — this is the actual closeout of LANG5, not a rubber stamp |
| No code, config, or `pubspec.yaml` touched by this card | `git diff --stat` shows only `CLAUDE.md` and `docs/**` (review) |

## Environment limits

This card cannot itself verify translation quality — the sign-offs it records come from people, not from running anything. If no reviewer is available for a language, the card's job is to make that gap visible in writing, not to paper over it.
