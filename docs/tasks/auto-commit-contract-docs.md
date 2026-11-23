---
executor: task-executor
scopes: [harness, docs]
workKinds: [harness, documentation]
blockedBy: [auto-commit-decisions]
securityReview: required
---

# Contract: agents commit once per finished card (docs and commands only)

**Owner approval needed for this specific task, not assumed:** this card edits `CLAUDE.md`, `.claude/commands/execute-tasks.md` and `.claude/agents/task-executor.md`. Per "Safety policy", each needs explicit owner approval for this task; approval for `auto-commit-decisions` does not carry over. The executor must ask before the first edit to each of these files and stop if not given. Not edited here: `.claude/settings.json` (card `auto-commit-permissions`), `Makefile`, `tool/**`, `.github/**`, `dev/**`, and the other commands and agents.

`securityReview: required` because the change touches agent permissions policy (`.claude/`) and the Safety policy.

## Goal

Write the owner's answers AC1-AC9 from `auto-commit-decisions` into the contract. Wording below follows the recommendations; **rewrite it to match whatever the owner decided.**

1. `CLAUDE.md` -> "Safety policy": replace the "Don't commit..." bullet with: agents may make **one local commit per archived card**, only in `/execute-tasks`, only under the conditions in "Git". Still never, unless the owner asks in the current task: push, `--force`, `reset`, `clean`, `restore`, `rebase`, `commit --amend`, `--no-verify`, branch creation or switching, `git add -A` / `git add .`, `git stash`.
2. `CLAUDE.md` -> "Git": add a subsection "Automatic commit after a task" with:
   - when: after step 9 (card moved to `done/`) and only if the reviews say `passed`, `p0: 0`, `p1: 0` and the gates the card touches exited 0;
   - `make check` rule: per the owner's AC4 answer (the known `make analyze` baseline of `deprecated_member_use` infos). Write it as an exact, checkable condition, or as "do not commit" if the owner chose option 3;
   - what goes in: code, tests, docs, the moved card, the review reports; staged by explicit path list taken from `git status --short`, reviewed with `git diff --cached --stat` before committing;
   - never staged, whatever `git status` shows: `.env*`, `backend/data/**` (database, images), `build/`, `.dart_tool/`, `sample/`, any `*.csv` / `*.xlsx` export, scratchpad or `/tmp` files, `.claude/settings.local.json`. If any appears in the staging list, stop and tell the owner (also check the `.gitignore` gap noted in `auto-commit-decisions`);
   - message: `<type>(<scope>): <description>`, with the type/scope mapping from AC2; body names the card slug and the gate results; trailers follow whatever attribution the owner's session instructs;
   - commits are local; pushing is the owner's separate decision;
   - the pre-commit hook is never bypassed; if it rejects the commit, fix the cause (read-only format check: run `dart format` on the touched files) and make a new commit attempt, never `--no-verify`;
   - the working tree has unrelated changes overlapping the card's files: stop and ask (AC9).
3. `.claude/commands/execute-tasks.md`: change Hard rules to "No push, no `--no-verify`, no `sudo`, no history rewriting. Commit only as in step 10." Add per-card step 10: "Commit" following the CLAUDE.md "Git" subsection; add the commit hash (or "not committed: <reason>") to the Report. Pre-check 5 gains the AC9 stop condition.
4. `.claude/agents/task-executor.md`: keep "never commits or pushes" true for the executor agent itself **unless the owner decides the executor, not the orchestrating command, makes the commit.** Recommendation: the `/execute-tasks` orchestrator commits after the independent review; the executor agent still doesn't, so the commit never happens before review. Only edit this file to say so.

## Non-goals

No change to `.claude/settings.json` (separate card), the other commands (AC7: they stay non-committing), the hook, CI, or any code. No retroactive commits (that is `auto-commit-backlog-catchup`).

## Tests written with the change

None possible as code. The change is checked by reading and by a trial run (see table).

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Owner approval for each of the three files is recorded in the review report before editing | independent review (`code-reviewer` checks the report); owner |
| `CLAUDE.md`, the command and the agent file agree with each other and with the owner's AC1-AC9 answers, with no leftover "no commit" sentence that contradicts them | independent review reading all three files; grep for `commit` |
| The "never stage" list covers every item in the Environment section and `.gitignore` gaps are either closed (separate approved edit) or listed as owner follow-up | independent review |
| The wording forbids push, reset, clean, restore, rebase, amend, `--no-verify`, `git add -A` | independent review; `securityReview` report |
| Nothing else changed | `git diff --stat` shows only the three files plus card and reports |
| `make format-check` and `make boundaries` still exit 0 (no code touched) | gate run, exit codes recorded |
| A real card ends with a correct commit | **unverified until the first real run**; owner acceptance after `auto-commit-permissions` lands |

## Environment limits

- The agents cannot make the first commit themselves until `auto-commit-permissions` lands; this card must not try to run `git commit`. **This card itself is committed by the owner by hand** (or left for the catch-up commit): it is the card that creates the rule.
- The documents describe a rule; nothing machine-checks that later agents follow it (the repo says reviewers and the owner check by hand). A commit is local and reversible only by the owner, so what a run does can be checked afterwards with `git log` and `git show --stat`.
