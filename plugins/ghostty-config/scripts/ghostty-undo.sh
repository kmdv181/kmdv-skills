#!/bin/sh
# List and restore Ghostty config backups taken by ghostty-apply.sh.
#
#   ghostty-undo.sh --list              show the ring, newest first, numbered
#   ghostty-undo.sh --diff [TARGET]     diff the live config against a backup
#   ghostty-undo.sh --restore TARGET    restore a backup
#
# TARGET is either an index from --list (1 is newest) or a backup filename.
#
# `--restore` deliberately refuses to run without a TARGET. Restoring is not
# obviously "the last one": every restore is itself an apply and therefore takes
# its own backup, so after one undo the newest entry is the state you just undid.
# A silent default would toggle between two states while looking like it walks
# back through history. Making the choice explicit is the fix.
#
# A restore goes back through ghostty-apply.sh, so it is validated, diffed and
# backed up like any other change — an undo can be undone.

set -u

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ghostty-config-plugin/backups"
mode="list"
target=""

die() { printf 'ghostty-undo: %s\n' "$1" >&2; exit "${2:-2}"; }

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

while [ $# -gt 0 ]; do
	case "$1" in
		--list)    mode="list"; shift ;;
		--restore) mode="restore"; shift; [ $# -gt 0 ] && { target="$1"; shift; } ;;
		--diff)    mode="diff"; shift; [ $# -gt 0 ] && { target="$1"; shift; } ;;
		-h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

# Newest first. `.origin` sidecars are metadata, not backups.
list_backups() {
	# LC_ALL=C is load-bearing: locale collation ignores punctuation and puts the
	# collision-suffixed names in the wrong order, so "newest" stops being newest.
	find "$backup_dir" -maxdepth 1 -type f ! -name '*.origin' 2>/dev/null | LC_ALL=C sort -r
}

# 20260808-150812[.N]-config  ->  2026-08-08 15:08:12
pretty_stamp() {
	printf '%s' "$1" | sed -n \
		's/^\([0-9]\{4\}\)\([0-9][0-9]\)\([0-9][0-9]\)-\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\).*/\1-\2-\3 \4:\5:\6/p'
}

print_table() {
	i=0
	list_backups | while IFS= read -r b; do
		i=$((i + 1))
		name="$(basename -- "$b")"
		when="$(pretty_stamp "$name")"
		[ -n "$when" ] || when="(unparsed timestamp)"
		origin="unknown target"
		[ -f "$b.origin" ] && origin="$(cat "$b.origin")"
		printf '%2s  %s  %s\n      → %s\n' "$i" "$when" "$name" "$origin"
	done
}

# TARGET is an index into the newest-first list, or a filename, or a full path.
resolve_target() {
	sel="$1"
	case "$sel" in
		''|*[!0-9]*) : ;;  # not a plain number — fall through to name handling
		*)
			resolved="$(list_backups | sed -n "${sel}p")"
			[ -n "$resolved" ] || die "no backup at index $sel — run --list" 1
			printf '%s' "$resolved"
			return 0 ;;
	esac
	[ -f "$sel" ] || sel="$backup_dir/$sel"
	[ -f "$sel" ] || die "backup not found: $1 — run --list" 1
	printf '%s' "$sel"
}

config_for() {
	if [ -f "$1.origin" ]; then
		cat "$1.origin"
	else
		printf 'Note: no .origin sidecar; falling back to the detected config path.\n' >&2
		sh "$script_dir/ghostty-env.sh" |
			sed -n 's/^  "config_path": "\(.*\)",$/\1/p' |
			sed -e 's/\\"/"/g' -e 's/\\\\/\\/g'
	fi
}

[ -d "$backup_dir" ] || die "no backups yet ($backup_dir does not exist)" 1
all="$(list_backups)"
[ -n "$all" ] || die "no backups found in $backup_dir" 1

case "$mode" in
	list)
		print_table
		;;

	restore)
		if [ -z "$target" ]; then
			printf 'Pick which backup to restore — pass its number or filename:\n\n'
			print_table
			printf '\n  ghostty-undo.sh --restore <number>\n'
			die "no target given" 2
		fi
		backup="$(resolve_target "$target")" || exit $?
		config_path="$(config_for "$backup")"
		[ -n "$config_path" ] || die "cannot determine where to restore this backup"
		exec sh "$script_dir/ghostty-apply.sh" --new "$backup" --config "$config_path"
		;;

	diff)
		# Read-only, so defaulting to the newest is safe here.
		[ -n "$target" ] || target=1
		backup="$(resolve_target "$target")" || exit $?
		config_path="$(config_for "$backup")"
		printf -- '--- live:   %s\n+++ backup: %s\n' "$config_path" "$backup"
		diff -u -- "$config_path" "$backup" || true
		;;
esac
