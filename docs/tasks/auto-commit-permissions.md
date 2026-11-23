---
executor: task-executor
scopes: [harness]
workKinds: [harness, quality-gate]
blockedBy: [auto-commit-contract-docs]
securityReview: required
---

# Permissions: let agents run only the git commands the commit step needs

**Owner approval needed for this specific task, not assumed:** `.claude/settings.json` is in the Safety policy approval list (`Edit(.claude/settings.json)` is under `ask`). The executor must stop and ask before editing it. Approval for the earlier cards does not carry over.

`securityReview: required` (agent permissions).

## Why

Agents currently cannot commit because (1) `settings.json` has a blanket `"Bash"` entry under `ask`, and `ask` beats `allow`, so a narrow `allow` for git commands would be ignored while it is there; (2) the deny rule `git commit --no-verify *` matches only that exact prefix. "Every shell command asks (strict mode)" is a deliberate choice recorded in `CLAUDE.md`; this card keeps it for everything except the commands listed below.

## Goal

Change `.claude/settings.json` so that, and only so that:

1. **Allowed without a prompt (read-only):** `git status`, `git status *`, `git diff`, `git diff *`, `git log`, `git log *`, `git show *`.
2. **Allowed (the commit step):** `git add <explicit paths>` and `git commit -m *` / `git commit -F *`. Because a glob like `git add *` also matches `git add -A` and `git add .`, add matching **deny** rules for `git add -A*`, `git add --all*`, `git add .`, `git add -u*`, `git add -f*`, `git add --force*`. Deny beats allow.
3. **Still denied, unchanged or tightened:** `sudo`, `rm -rf`, `git reset`, `git clean`, `git checkout --`, `git restore`, `git push` in every form (add plain `git push *`; today only force variants are denied), `git commit --amend*`, `git rebase*`, `git stash*`, `git branch -D*`, `git switch*`, `git checkout *`; and `--no-verify` anywhere in a commit or push (`Bash(git commit *--no-verify*)`, `Bash(git push *--no-verify*)`, and `-n`).
4. **Everything else in Bash keeps asking.** The executor must find out how to achieve this given that a blanket `"Bash"` ask beats allow: probably by replacing the blanket entry with a deliberate list (`make *`, `dart format *`, `dart *`, `flutter *`, the read-only git commands) under `allow` and leaving the rest to the default prompt. **This is a real design choice with a security effect: bring the exact proposed lists to the owner, and let the owner approve them, before editing.** Do not widen anything the owner did not approve (for example, no `Bash(git *)`).
5. Not touched: `Edit(...)` rules, `settings.local.json` (do not read or edit it; it is the owner's local file).

## Open decision for the owner

- **PERM1:** replace the blanket `"Bash"` ask, or keep strict mode and let the owner click "allow" on each `git add` / `git commit` prompt? Recommendation: keep the prompt on `git commit` (it shows the message and costs one click per card) and allow only the read-only commands without a prompt; that makes the commit a deliberate act the owner sees, at the price of one approval per card. If the owner wants full automation, allow `git add` and `git commit` too with the deny list above.
- **PERM2:** is the deny list for `git switch`, `git checkout *`, `git stash` OK? They protect the AC6 and AC9 rules; they may block benign use by the owner's own agent sessions.

## Non-goals

No change to `CLAUDE.md` text (done in `auto-commit-contract-docs`), the Makefile, hooks, or any other settings area. Push permissions are not granted.

## Tests written with the change

No unit tests; a permissions file has none. Verification is by the trial in the table.

## Acceptance criteria -> verification

| Criterion | Verified by |
|---|---|
| Owner approval of the exact rule lists recorded in the review before the edit | independent review; owner |
| `.claude/settings.json` is valid JSON | read by the reviewer; `python3 -m json.tool` or `dart` JSON parse if the owner approves running it |
| No rule permits `git push`, `reset`, `clean`, `restore`, `rebase`, `--amend`, `--no-verify`, `add -A`, `add .` | `security-reviewer` reads the final file and checks each rule against the deny list |
| Only the owner-approved commands are newly allowed; diff shows no other change | `git diff .claude/settings.json` |
| An agent session really: (a) can run `git status`; (b) can commit a one-file test change; (c) is refused `git push`, `git add -A`, `git commit --no-verify` | **owner acceptance in a real session**: agents cannot test their own permission rules reliably; report "unverified" until the owner confirms. Use a throwaway local change and undo it by hand |
| `make format-check` / `make boundaries` unchanged and exit 0 | gate run |

## Environment limits

- The executor cannot prove the permission matching rules (precedence, glob behaviour) from documents alone; the trial in the owner's session is the only proof.
- This card itself changes who can commit, so it is committed by the owner by hand.
- Agents must not run `git commit` while verifying this card.
