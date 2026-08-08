#!/bin/sh
# List and restore Ghostty config backups taken by ghostty-apply.sh.
#
#   ghostty-undo.sh --list                 show every backup, newest first
#   ghostty-undo.sh --restore [BACKUP]     restore BACKUP, or the newest one
#   ghostty-undo.sh --diff [BACKUP]        diff the live config against a backup
#
# Restoring is itself an applied change: the current config is backed up first,
# so undo is reversible.

set -u

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ghostty-config-plugin/backups"
mode="list"
target=""

die() { printf 'ghostty-undo: %s\n' "$1" >&2; exit "${2:-2}"; }

while [ $# -gt 0 ]; do
	case "$1" in
		--list)    mode="list"; shift ;;
		--restore) mode="restore"; shift; [ $# -gt 0 ] && { target="$1"; shift; } ;;
		--diff)    mode="diff"; shift; [ $# -gt 0 ] && { target="$1"; shift; } ;;
		-h|--help) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

[ -d "$backup_dir" ] || die "no backups yet ($backup_dir does not exist)" 1

# Backups are named <timestamp>-<basename>, so a reverse lexical sort is a
# reverse chronological sort. `.origin` sidecars are metadata, not backups.
list_backups() {
	find "$backup_dir" -type f ! -name '*.origin' 2>/dev/null | sort -r
}

newest() { list_backups | head -1; }

case "$mode" in
	list)
		all="$(list_backups)"
		if [ -z "$all" ]; then
			printf 'No backups found in %s\n' "$backup_dir"
			exit 1
		fi
		printf '%s\n' "$all" | while IFS= read -r b; do
			origin="unknown target"
			[ -f "$b.origin" ] && origin="$(cat "$b.origin")"
			printf '%s\n    -> %s\n' "$b" "$origin"
		done
		;;

	restore|diff)
		[ -n "$target" ] || target="$(newest)"
		[ -n "$target" ] || die "no backups found in $backup_dir" 1
		# Accept either a full path or a bare filename.
		[ -f "$target" ] || target="$backup_dir/$target"
		[ -f "$target" ] || die "backup not found: $target" 1

		if [ -f "$target.origin" ]; then
			config_path="$(cat "$target.origin")"
		else
			script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
			config_path="$(sh "$script_dir/ghostty-env.sh" |
				sed -n 's/^  "config_path": "\(.*\)",$/\1/p' |
				sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
			printf 'Note: no .origin sidecar; falling back to the detected config path.\n' >&2
		fi
		[ -n "$config_path" ] || die "cannot determine where to restore this backup"

		if [ "$mode" = "diff" ]; then
			printf -- '--- live: %s\n+++ backup: %s\n' "$config_path" "$target"
			diff -u -- "$config_path" "$target" || true
			exit 0
		fi

		# Route the restore through apply so it is validated, diffed and backed up
		# exactly like any other change.
		script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
		exec sh "$script_dir/ghostty-apply.sh" --new "$target" --config "$config_path"
		;;
esac
