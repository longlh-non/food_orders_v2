# `dart format --set-exit-if-changed` is not read-only

`dart format --set-exit-if-changed` still **rewrites** files; it just also exits non-zero when it did.

A read-only check needs `--output=none`:

```bash
dart format --output=none --set-exit-if-changed lib test backend
```

Only run `dart format <paths>` without `--output=none` when you actually mean to reformat. `make format-check`, the pre-commit hook, and CI must keep `--output=none` so a check never silently dirties the worktree.
