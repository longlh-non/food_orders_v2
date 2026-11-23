#!/usr/bin/env bash
# Builds both Flutter web apps for deployment. Run on the machine that will
# copy the result to the server (not necessarily the server itself).
#
# Output:
#   build/customer    (from lib/customer/main.dart)
#   build/restaurant  (from lib/restaurant/main.dart)
#
# This script only builds. It never uploads anything over the network.
# Copying the result to the server is a manual step the owner runs by hand,
# e.g.:
#   rsync -a --delete build/customer/   user@server:/var/www/food-orders/customer/
#   rsync -a --delete build/restaurant/ user@server:/var/www/food-orders/restaurant/
# (see deploy/Caddyfile for the matching `root` paths, and the runbook for
# the owner's photos-folder rsync step.)
#
# `--output` was checked against this project's installed Flutter
# (`flutter build web --help`, Flutter 3.50.1 / Dart 3.14.0): it is a
# supported `flutter build web` flag ("-o, --output  The absolute path to
# the directory where the repository is generated. ... Currently supported
# for subcommands: aar, web."). Despite the help text saying "absolute
# path", a path relative to the current directory (as used below) was also
# tested directly against this Flutter install and worked.

set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
	echo "error: flutter is not on PATH (see CLAUDE.md: export PATH=\"\$HOME/development/flutter/bin:\$PATH\")" >&2
	exit 1
fi

# Resolve the repo root from this script's location, so the script works
# no matter which directory it's run from.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
cd "$repo_root"

echo "==> Building customer app (lib/customer/main.dart -> build/customer)"
rm -rf build/customer
flutter build web --release -t lib/customer/main.dart --output build/customer

echo "==> Building restaurant app (lib/restaurant/main.dart -> build/restaurant)"
rm -rf build/restaurant
flutter build web --release -t lib/restaurant/main.dart --output build/restaurant

echo "==> Done. Output:"
echo "    $repo_root/build/customer"
echo "    $repo_root/build/restaurant"
