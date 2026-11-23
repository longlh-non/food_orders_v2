#!/usr/bin/env bash
# Backs up the orders database and the menu pictures folder as a matching
# pair, and keeps only the last N rounds. Safe to run while the backend is
# serving requests (sqlite3 .backup; see CLAUDE.md "Storage").
#
# Usage (defaults match deploy/food-orders-backend.service):
#   deploy/backup.sh
#   ORDERS_DB=/path/to/orders.db IMAGES_DIR=/path/to/images \
#     BACKUP_DIR=/path/to/backups KEEP=14 deploy/backup.sh
#
# Each round writes two files, same timestamp:
#   orders-YYYY-MM-DD-HHMMSS.db
#   images-YYYY-MM-DD-HHMMSS.tar.gz
# A tar snapshot (not rsync -a into one rotating folder) keeps every round
# self-contained, so one round's db and its pictures are always a matching
# pair, even if the images folder changed between rounds.
#
# Scheduling is the owner's choice (cron or a systemd timer, outside this
# card); this script only does one round per invocation.

set -euo pipefail

# Backup files hold the same customer names as the live database (see
# CLAUDE.md's P2-1 note, also why the systemd unit sets UMask=0077), so
# default to restrictive permissions for everything this script creates.
umask 077

orders_db="${ORDERS_DB:-/var/lib/food-orders/orders.db}"
images_dir="${IMAGES_DIR:-/var/lib/food-orders/images}"
backup_dir="${BACKUP_DIR:-/var/lib/food-orders/backups}"
keep="${KEEP:-14}"

if [[ ! -f "$orders_db" ]]; then
	echo "error: orders database not found: $orders_db" >&2
	exit 1
fi

if ! [[ "$keep" =~ ^[0-9]+$ ]] || [[ "$keep" -lt 1 ]]; then
	echo "error: KEEP must be a positive integer, got: $keep" >&2
	exit 1
fi

# sqlite3's `.backup` dot-command takes the rest of the line as the target
# path, quoted with its own (not the shell's) rules; a BACKUP_DIR containing
# a single quote would misparse it. Both paths are operator-supplied, never
# attacker input, so a clear upfront error is enough -- no escaping needed.
if [[ "$backup_dir" == *"'"* ]] || [[ "$orders_db" == *"'"* ]]; then
	echo "error: BACKUP_DIR/ORDERS_DB must not contain a single quote" >&2
	exit 1
fi

mkdir -p "$backup_dir"

timestamp="$(date +%F-%H%M%S)"
db_backup="$backup_dir/orders-$timestamp.db"
images_backup="$backup_dir/images-$timestamp.tar.gz"

# Write both halves of the round under temp names first, and only rename
# them into the names `prune` globs on once BOTH succeed. Otherwise a tar
# failure after a successful db backup (disk full, permission error -- not
# just "images dir missing", which is handled below) would leave an orphan
# db backup that `prune` would still count and keep, breaking the "db and
# pictures are always a matching pair" guarantee for that round. The trap
# clears any leftover temp file on an early exit, successful or not.
db_tmp="$db_backup.tmp"
images_tmp="$images_backup.tmp"
trap 'rm -f -- "$db_tmp" "$images_tmp"' EXIT

echo "==> Backing up $orders_db -> $db_backup"
sqlite3 "$orders_db" ".backup '$db_tmp'"

if [[ -d "$images_dir" ]]; then
	echo "==> Backing up $images_dir -> $images_backup"
	tar -czf "$images_tmp" -C "$(dirname "$images_dir")" "$(basename "$images_dir")"
else
	echo "warning: images folder not found, skipping: $images_dir" >&2
	# Still record an (empty) archive so counting/pruning below stays in
	# sync between the two file sets, and a restore script can rely on
	# every db backup having a matching images archive.
	tar -czf "$images_tmp" --files-from /dev/null
fi

mv -- "$db_tmp" "$db_backup"
mv -- "$images_tmp" "$images_backup"

prune() {
	local pattern="$1"
	# Newest first; delete anything past the first $keep matches. `ls -1t`
	# over a glob, guarded so a round with nothing to prune doesn't error
	# under `set -e` (shopt -s nullglob would also work, but this keeps the
	# glob expansion visible and avoids changing shell options globally).
	local files=()
	# shellcheck disable=SC2206,SC2086 -- deliberately unquoted: $pattern
	# must glob-expand here (e.g. "$backup_dir/orders-*.db").
	for f in $pattern; do
		[[ -e "$f" ]] && files+=("$f")
	done
	[[ ${#files[@]} -le $keep ]] && return 0
	# shellcheck disable=SC2012
	ls -1t "${files[@]}" | tail -n "+$((keep + 1))" | while IFS= read -r old; do
		echo "==> Removing old backup: $old"
		rm -f -- "$old"
	done
}

prune "$backup_dir/orders-*.db"
prune "$backup_dir/images-*.tar.gz"

echo "==> Done. Kept the last $keep round(s) in $backup_dir"
