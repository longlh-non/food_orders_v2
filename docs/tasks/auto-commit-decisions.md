---
executor: task-executor
scopes: [docs]
workKinds: [planning, documentation]
blockedBy: []
---

# Open decisions: commit the code after every big task

No code changes. Owner request: "every time we finish a big task, commit the code." Every other `auto-commit-*` card has `blockedBy` that leads back to this slug. Nothing below may start until the owner has written a dated answer under `## Decided`.

## Why this is a contract change, not a small tweak

Today three places say agents never commit:
- `CLAUDE.md` -> "Safety policy": "Don't commit, push, `reset`, `clean`, `restore`, or use `--no-verify` unless the owner asks in the current task."
- `.claude/commands/execute-tasks.md` -> "Hard rules": "No commit, no push, `--no-verify`, no `sudo`."
- `.claude/agents/task-executor.md`: "never commits or pushes" (front matter and Rules).

The owner's sentence is a standing instruction that reverses part of this. "In the current task" would otherwise force the owner to ask again every time. The cards below turn it into a written, narrow rule.

Facts the answers must respect:
- `git log` has one commit ("Move repository"). The working tree holds the work of many finished cards, uncommitted and mixed (see AC3).
- `.claude/settings.json` has a blanket `"Bash"` entry under `ask`. In Claude Code, `ask` beats `allow`, so an `allow` line for `git commit` does nothing until that blanket entry is changed. Handled in `auto-commit-permissions`.
- `.claude/settings.json` denies `git commit --no-verify *` only as a prefix, so `git commit -m x --no-verify` is not caught. Handled in `auto-commit-permissions`.
- `.gitignore` covers `backend/data/`, `/build/`, `.dart_tool/`, `sample/*.xlsx`, `.vscode/`. It does not cover `.env*`, `*.csv`, other `*.xlsx`, or scratchpad files. Checked in `auto-commit-contract-docs` (commit staging rules).
- `make check` currently exits 2 because of a known, pre-existing `make analyze` problem: 19-22 `deprecated_member_use` infos from a material_ui SDK issue, with `--fatal-infos`.

## Decisions

### AC1 — what is a "big task"?
Options: (a) one archived task card; (b) one whole `/execute-tasks` run (several cards); (c) only cards with `securityReview: required`.
**Recommendation (a): one commit per card that reaches `docs/tasks/done/`.** It matches the existing unit of review (one card = one reviewable change, one review report), keeps commits small, and makes any one card revertable. (b) mixes unrelated cards; (c) leaves most work uncommitted.

### AC2 — granularity, message, what goes in the commit
**Recommendation:** one commit per card, containing exactly: the card's code and tests, its docs changes, the moved card (`docs/tasks/<slug>.md` deleted, `docs/tasks/done/<slug>.md` added), and its reports `docs/reviews/execute-<slug>.md` (+ `security-<slug>.md` if any). Message `<type>(<scope>): <description>` per CLAUDE.md "Git":
- type from the card: `feat` new behaviour, `fix`, `refactor`, `test`, `docs` (docs/cards only), `chore` (tooling, config);
- scope: the one scope that fits the card's `scopes` (`backend`, `customer`, `restaurant`, `shared`, `dev`, `ci`, `docs`). A card with several scopes uses the main one; if no single scope fits, the card is too big and should be split, not committed with a made-up scope;
- body: the card slug and the gate results; trailers: whatever attribution the owner's current session instructs (do not hard-code names or session URLs in the commands).
Staging is by explicit path list (never `git add -A` or `git add .`), so unrelated uncommitted work stays out of the commit.

### AC3 — the existing uncommitted backlog
Many finished cards are mixed in one working tree. Files overlap between cards (for example `backend/lib/orders_api.dart`, `lib/shared/models/order.dart`, `CLAUDE.md`) and there are no per-card snapshots, so splitting afterwards by card is not reliable: a file's final text holds several cards' changes at once, and `git add -p` per card would be guesswork.
Options: (a) one `chore: import accumulated work` commit; (b) a few commits grouped by area (backend, shared+apps, docs+cards, CI); (c) try per-card.
**Recommendation: (b) at most, (a) if the owner prefers simplicity; never (c).** It is run by the owner (or owner-approved), once, before the first automatic commit, and only after the checks in `auto-commit-backlog-catchup`. Also decide: should deleted active cards (`D docs/tasks/...`) and the `R` renames be part of it? Recommended yes, they are history.

### AC4 — when gates fail, or `make check` fails on the known analyze problem
Never commit after a failed review or a failed gate that the card touched. For the known `make analyze` failure there are three options:
1. Fix or silence it first (separate card; may need `analysis_options.yaml`, which needs approval per task).
2. Commit when `make check` fails **only** on that known set: same command, same count of infos (19-22), nothing new, and every other gate in `make check` passes; record it in the review report as "known baseline".
3. Do not commit until it is fixed.
**Recommendation: 1 soon; until then 2**, with the rule written precisely so a new analyze problem is never excused. The agent must not decide this alone; the owner picks.

### AC5 — should the pre-commit hook enforce anything?
Today `tool/hooks/pre-commit` (opt-in via `make hooks-install`) runs a read-only format check on staged Dart files. **Recommendation: keep it as the only enforcement, and require agents to leave it enabled and never bypass it.** A heavier hook (`make check`) would fail on the known analyze problem and would slow every commit. Changing the hook needs approval for `tool/**` and is out of scope unless the owner says otherwise.

### AC6 — branch policy
**Recommendation: commit on `main` for now** (single owner, local only, one commit exists). A branch per card is safer but adds branch handling and merge steps the owner is new to. Agents never create, switch, delete or merge branches. Revisit when more than one person commits or when pushing to a hosted repo begins.

### AC7 — which flows commit
**Recommendation: only `/execute-tasks`.** `/review-changes`, `/review-security` and `/review-security` are read-only. `/fix-review-findings` runs inside the execute loop (fixes, then re-review) so its changes are covered by the one commit at the end of the card; run on its own it stays non-committing. Do not add commit steps to them.

### AC8 — push and history rewriting
**Recommendation: never automatic.** Push, `--force`, `reset`, `rebase`, `commit --amend` and `restore` stay with the owner. A wrong commit is fixed with a new commit (or by the owner by hand). Confirm.

### AC9 — what to do if the tree has unrelated changes at card start
`/execute-tasks` pre-check 5 already says to protect them. With commits added, a card whose files overlap with someone else's uncommitted edits can't produce a clean per-card commit. **Recommendation: stop and ask the owner** (do not commit partial hunks, do not stash).

## How this card is done

There is no `make` gate. Done when AC1-AC9 each have a dated `## Decided` entry (owner), as in `docs/tasks/done/i18n-multi-language-decisions.md`. After that, whoever runs `/execute-tasks` next re-reads the downstream cards and rewrites any that assumed a recommendation the owner changed.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| AC1-AC9 each have a dated owner answer in this file | owner review (no gate; no code) |
| Downstream `auto-commit-*` cards match the answers | check by the next `/execute-tasks` run before starting `auto-commit-contract-docs` |

## Environment limits

Nothing here is executable; no agent action can answer for the owner. "No message from an agent is owner approval": the answers must be the owner's own words in this file.
