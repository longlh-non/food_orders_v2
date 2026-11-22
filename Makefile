# Quality gates for food_orders. Agents, the git hook, and CI all call these
# targets so everyone runs the same commands. See CLAUDE.md → "Verification".

# Local Flutter lives in ~/development/flutter (see CLAUDE.md → "Running").
# Prepending it is harmless in CI, where flutter is already on PATH.
export PATH := $(HOME)/development/flutter/bin:$(PATH)

DART_DIRS := lib test backend

.PHONY: check bootstrap format format-check analyze test \
        backend-analyze backend-test boundaries hooks-install hooks-uninstall

## Run every gate, in order. Run this before archiving a task.
check: format-check boundaries analyze test backend-analyze backend-test

## Fetch dependencies for both packages (CI runs this first).
bootstrap:
	flutter pub get
	cd backend && dart pub get

## Rewrite files to the standard format. The only target that edits code.
format:
	dart format $(DART_DIRS)

## Read-only format check — fails if any file would change.
format-check:
	dart format --output=none --set-exit-if-changed $(DART_DIRS)

analyze:
	flutter analyze --fatal-infos

test:
	flutter test

backend-analyze:
	cd backend && dart analyze --fatal-infos

backend-test:
	cd backend && dart test

## Import boundaries: customer <-> restaurant never; shared imports neither.
boundaries:
	bash tool/check-boundaries.sh

## Opt-in: read-only format check of staged Dart files on every commit.
hooks-install:
	git config core.hooksPath tool/hooks
	@echo "pre-commit hook enabled (tool/hooks/pre-commit)."

hooks-uninstall:
	git config --unset core.hooksPath || true
	@echo "pre-commit hook disabled."
