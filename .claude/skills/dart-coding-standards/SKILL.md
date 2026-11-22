---
name: dart-coding-standards
description: Dart/Flutter code conventions for food_orders — formatting, lints, imports, error handling, ChangeNotifier and stream lifecycle. Use when writing or reviewing any .dart file in lib/, test/, or backend/. Not for architecture decisions (see CLAUDE.md invariants) or test design (see testing-strategy). Keywords: dart style, lint, format, analyze, ChangeNotifier, dispose, StreamSubscription, catch.
paths:
  - "lib/**/*.dart"
  - "test/**/*.dart"
  - "backend/**/*.dart"
---

# Dart coding standards

- **Format:** `dart format <touched files>`. The gate is read-only: `make format-check` (see `.claude/memories/format-gate.md`).
- **Lints:** apps use `flutter_lints`, backend uses `lints/recommended`. `--fatal-infos` is on, so infos fail too. Fix the cause; `// ignore:` needs a reason in a comment.
- **Imports:** relative imports inside `lib/` match the existing code. Never import across `customer/` ↔ `restaurant/`.
- **State:** `ChangeNotifier` singletons + `ListenableBuilder`. Wrap only the subtree that reads the state. Anything you `listen` to, you `cancel`; anything you create with `addListener`, you remove in `dispose`.
- **Errors:** catch the narrowest documented type (`FormatException` at parse boundaries, `http.ClientException` for network). `on Object` only at a deliberate fallback boundary, with logging (see `.claude/memories/catch-type-selection.md`).
- **JSON:** `toJson`/`fromJson` live with the model. The backend stores maps but must agree with `Order.toJson()`.
- **Comments:** explain *why* (decisions, quirks like the SSE `hijack`), not *what*. The owner is learning Flutter — a short why-comment beats a clever one-liner.
- **Generated files and lockfiles:** never hand-edit. Use `flutter pub` / `dart pub`.

Related plugin skills: `dart-flutter:dart-run-static-analysis`, `dart-flutter:dart-use-pattern-matching`.
