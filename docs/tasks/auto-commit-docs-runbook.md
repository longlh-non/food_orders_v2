---
executor: task-executor
scopes: [docs]
workKinds: [documentation]
blockedBy: [auto-commit-contract-docs, auto-commit-permissions, auto-commit-backlog-catchup]
---

# Docs: tell the owner how automatic commits work and how to undo one

**Owner approval needed for this specific task, not assumed, if `CLAUDE.md` is edited.** The `CLAUDE.md` rule itself was written in `auto-commit-contract-docs`; this card should only edit `docs/runbook-local.md`. If a `CLAUDE.md` pointer is wanted, ask the owner first for this task.

## Goal

Add a short section to `docs/runbook-local.md` (owner's step-by-step doc, near "6. Checks"), plain words, for someone new to Git and Flutter:

1. What happens: after each finished task card, the agent makes one local commit with a `type(scope): description` message. Nothing leaves the machine; no push.
2. How to look at it: `git log --oneline`, `git show --stat <hash>`, `git status --short` (should be empty after a card).
3. How to undo the last agent commit: with the owner's own command, which one depends on whether they want to keep the changes (`git reset --soft HEAD~1` keeps them staged; `git revert <hash>` is the safe one that adds a new commit). Say plainly that agents are not allowed to run these, and that `reset` needs care.
4. How to push when the owner chooses to (`git push`), and that it is never automatic.
5. What is never committed (data folder, `.env*`, exports) and what to do if the agent stops with "unexpected file staged".
6. What "known `make check` baseline" means for commits (per AC4) and where to see it, if the owner chose option 2; if the analyze problem has been fixed, delete this item.
7. The pre-commit hook: `make hooks-install` / `make hooks-uninstall`, what it checks (format of staged Dart files).

## Non-goals

No code, config, or other docs. No new rules (they live in `CLAUDE.md`).

## Tests written with the change

None. Command snippets in the doc must be copied from commands that exist (`git log --oneline` etc.); the executor does not run reset/revert.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Items 1-7 are present, in plain words, matching `CLAUDE.md` "Git" and the owner's AC answers | independent review |
| No command in the doc tells the agent to push, reset or amend | independent review |
| Only `docs/runbook-local.md` (and the card and reports) changed | `git diff --stat` |
| `make format-check` and `make boundaries` exit 0 | gate run |
| The owner can follow the undo steps on a throwaway commit | **owner acceptance** (unverified by agents) |

## Environment limits

The doc describes owner-run commands. Agents can't verify them end to end.

This card is the first one that can be committed automatically, if `auto-commit-permissions` is in place and the owner has approved it. Report "commit: not made" with the reason if permissions are not yet active.
