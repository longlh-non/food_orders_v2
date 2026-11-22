#!/usr/bin/env bash
# Enforces CLAUDE.md → "Architecture invariants" #1 and #4:
#   - lib/customer and lib/restaurant never import each other
#   - lib/shared imports neither app nor lib/dev
#   - neither app imports lib/dev
#   - backend never imports Flutter or the app package
# Matches both relative ('../restaurant/...') and package: imports.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0

# check <dir> <forbidden-folder-regex> <message>
check() {
  local dir="$1" pattern="$2" message="$3" hits
  hits="$(grep -rnE "^(import|export) +'[^']*(^|/|:food_orders/)(${pattern})/" "$dir" --include='*.dart' || true)"
  if [[ -n "$hits" ]]; then
    echo "boundary violation: $message" >&2
    echo "$hits" >&2
    fail=1
  fi
}

check lib/customer   'restaurant|dev'         'lib/customer must not import lib/restaurant or lib/dev'
check lib/restaurant 'customer|dev'           'lib/restaurant must not import lib/customer or lib/dev'
check lib/shared     'customer|restaurant|dev' 'lib/shared must not import either app or lib/dev'

backend_hits="$(grep -rnE "^(import|export) +'package:(flutter[a-z_]*|food_orders)/" backend --include='*.dart' --exclude-dir=.dart_tool || true)"
if [[ -n "$backend_hits" ]]; then
  echo 'boundary violation: backend must not import Flutter or the food_orders app package' >&2
  echo "$backend_hits" >&2
  fail=1
fi

if [[ $fail -eq 0 ]]; then
  echo 'boundaries: ok'
fi
exit $fail
