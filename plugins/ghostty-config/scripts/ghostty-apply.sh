#!/bin/sh
# Apply a new Ghostty config safely.
#
#   ghostty-apply.sh --new FILE [--config PATH] [--dry-run] [--no-validate]
#
# The real config is never in a broken state, not even briefly. The candidate is
# validated on disk *before* anything is overwritten, and only a clean validation
# is followed by the move.
#
# Why the candidate is written next to the real config and not to /tmp:
# `+validate-config --config-file=X` calls loadRecursiveFiles(), and `config-file =`
# includes resolve relative to the file that contains them. A candidate validated
# from a temp directory would fail to find the user's relative includes and report
# a verdict about a file that isn't the one being installed.
#
# Exit codes:
#   0  applied (or, with --dry-run, the candidate validates)
#   1  validation failed — the real config was not touched
#   2  cannot proceed (no ghostty binary, unreadable input, bad arguments)

set -u

new_file=""
config_path=""
dry_run=1
validate=0

die() { printf 'ghostty-apply: %s\n' "$1" >&2; exit "${2:-2}"; }

while [ $# -gt 0 ]; do
	case "$1" in
		--new)         [ $# -ge 2 ] || die "--new needs a path"; new_file="$2"; shift 2 ;;
		--config)      [ $# -ge 2 ] || die "--config needs a path"; config_path="$2"; shift 2 ;;
		--dry-run)     dry_run=0; shift ;;
		--no-validate) validate=1; shift ;;
		-h|--help)
			sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
			exit 0 ;;
		*) die "unknown argument: $1" ;;
	esac
done

[ -n "$new_file" ] || die "--new FILE is required"
[ -r "$new_file" ] || die "cannot read candidate file: $new_file"

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"

# ------------------------------------------------------------- resolve targets

if [ -z "$config_path" ]; then
	config_path="$(sh "$script_dir/ghostty-env.sh" |
		sed -n 's/^  "config_path": "\(.*\)",$/\1/p' |
		sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
fi
[ -n "$config_path" ] || die "could not determine the config path; pass --config"

config_dir="$(dirname -- "$config_path")"
mkdir -p -- "$config_dir" || die "cannot create config directory: $config_dir"

# A GHOSTTY_BIN that points at nothing is a broken install, not a broken config.
# Without this check the missing binary surfaces as "Validation FAILED", which
# sends the user to fix a file that is fine. ghostty-env.sh already reports
# bin:null for the same value; this keeps the two consistent.
ghostty_bin="${GHOSTTY_BIN:-}"
if [ -n "$ghostty_bin" ] && [ ! -x "$ghostty_bin" ]; then
	die "GHOSTTY_BIN is set to '$ghostty_bin', which is not an executable file.
Unset it to search the usual locations, or point it at the real ghostty binary." 2
fi
if [ -z "$ghostty_bin" ]; then
	if command -v ghostty >/dev/null 2>&1; then
		ghostty_bin="$(command -v ghostty)"
	elif [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
		ghostty_bin="/Applications/Ghostty.app/Contents/MacOS/ghostty"
	elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
		ghostty_bin="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
	fi
fi

if [ "$validate" -eq 0 ] && [ -z "$ghostty_bin" ]; then
	die "no ghostty binary found, so the change cannot be validated.
Install this plugin on the machine Ghostty runs on, set GHOSTTY_BIN, or re-run
with --no-validate to write the file unchecked." 2
fi

# --------------------------------------------------------- stage the candidate

# Neither `config.ghostty` nor `config` — Ghostty matches those filenames
# exactly, so this staging file is inert even if a crash leaves it behind.
candidate="$config_dir/$(basename -- "$config_path").ghostty-plugin-candidate"
cleanup() { rm -f -- "$candidate"; }
trap cleanup EXIT INT TERM

# Seed the candidate from the current config so it inherits the file's mode, then
# truncate it in place. `>` on an existing file keeps its permissions, so a 0600
# config stays 0600 instead of picking up whatever the umask says. Avoids `stat`,
# whose -c/-f flags mean different things on GNU and BSD.
if [ -e "$config_path" ]; then
	cp -p -- "$config_path" "$candidate" || die "cannot stage candidate: $candidate"
fi
cat -- "$new_file" >"$candidate" || die "cannot write candidate: $candidate"

# "Strip my config back to defaults" produces an empty candidate, and
# `+validate-config --config-file=` on a zero-byte file exits 1 printing nothing
# — so a legitimate request dead-ended as an unexplained validation failure. A
# lone newline is the smallest file the binary accepts and is identical in
# effect: no statements, everything falls back to the defaults.
[ -s "$candidate" ] || printf '\n' >"$candidate"

# ------------------------------------------------------------------- validate

if [ "$validate" -eq 0 ]; then
	diagnostics="$("$ghostty_bin" +validate-config --config-file="$candidate" 2>&1)"
	rc=$?
	if [ "$rc" -ne 0 ]; then
		printf 'Validation FAILED. The existing config was not modified.\n\n'
		# Diagnostics name the staging file; report the path the user recognises.
		printf '%s\n' "$diagnostics" | sed "s|$candidate|$config_path|g"
		exit 1
	fi
	printf 'Validation passed (%s).\n' "$(basename -- "$ghostty_bin")"
else
	printf 'Validation SKIPPED (--no-validate): the result is unverified.\n'
fi

# ----------------------------------------------------------------------- diff

printf '\n--- diff: %s ---\n' "$config_path"
if [ -e "$config_path" ]; then
	if diff -u -- "$config_path" "$candidate"; then
		printf '(no changes)\n'
		exit 0
	fi
else
	printf '(new file — %s does not exist yet)\n' "$config_path"
	sed 's/^/+/' <"$candidate"
fi

if [ "$dry_run" -eq 0 ]; then
	printf '\nDry run: nothing was written.\n'
	exit 0
fi

# --------------------------------------------------------------- back up + move

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ghostty-config-plugin/backups"
backup_keep="${GHOSTTY_BACKUP_KEEP:-5}"

# Normalise the count to a plain decimal before any arithmetic touches it, and
# fold everything unusable onto 0, which means unlimited. Three ways this bit:
#
#   `08`  POSIX arithmetic reads a leading zero as octal, and 8 is not an octal
#         digit — `$((08 + 1))` is a fatal "value too great for base" that killed
#         the script *after* the backup and *before* the move, so every apply
#         silently left the config unchanged.
#   `010` same rule, no error: it quietly meant 8 rather than 10.
#   `00`  all digits, so the old guard's `*[!0-9]*` missed it, and it is not the
#         literal `0` the next branch matched. It fell through to `tail -n +1`,
#         which deleted the entire ring including the backup just taken — while
#         the apply reported success.
#
# Stripping leading zeros makes each of those read the way a person meant it.
case "$backup_keep" in
	''|*[!0-9]*)
		# Not a plain number. Keep everything rather than guess at an intent, but
		# say so: a typo that silently disables pruning is worth one line.
		[ -z "${GHOSTTY_BACKUP_KEEP:-}" ] ||
			printf 'Note: GHOSTTY_BACKUP_KEEP=%s is not a number; keeping every backup.\n' \
				"$GHOSTTY_BACKUP_KEEP" >&2
		backup_keep=0
		;;
	*)
		backup_keep="$(printf '%s' "$backup_keep" | sed 's/^0*//')"
		[ -n "$backup_keep" ] || backup_keep=0   # the value was all zeros
		;;
esac

# Keep the ring at `backup_keep` entries, newest first. Names begin with a
# timestamp, so a reverse lexical sort is a reverse chronological one — but only
# under LC_ALL=C. Locale collation ignores punctuation and silently reordered
# these, which pruned the newest entry instead of the oldest. Each backup's
# `.origin` sidecar goes with it.
prune_backups() {
	[ "$backup_keep" -eq 0 ] && return 0   # 0, or anything unusable, means unlimited
	find "$backup_dir" -maxdepth 1 -type f ! -name '*.origin' 2>/dev/null |
		LC_ALL=C sort -r | tail -n "+$((backup_keep + 1))" |
		while IFS= read -r old; do
			rm -f -- "$old" "$old.origin"
		done
}

if [ -e "$config_path" ]; then
	mkdir -p -- "$backup_dir" || die "cannot create backup directory: $backup_dir"
	stamp="$(date +%Y%m%d-%H%M%S)"
	base="$(basename -- "$config_path")"

	# Several applies can land in the same second, so the name always carries a
	# counter. It is the highest existing counter for this second plus one — not
	# the first free slot. Pruning deletes oldest-first, which frees low numbers;
	# reusing one would produce a name that sorts as the *oldest* and gets pruned
	# on the very next write, silently destroying the newest backup.
	last="$(find "$backup_dir" -maxdepth 1 -name "$stamp.*-$base" ! -name '*.origin' 2>/dev/null |
		sed -n "s|.*/$stamp\.0*\([0-9][0-9]*\)-.*|\1|p" | LC_ALL=C sort -n | tail -1)"
	# Zero-padded so .10 sorts after .02. Past 99 writes in one second the
	# ordering would degrade, which is not a rate this tool can be driven at.
	backup="$(printf '%s/%s.%02d-%s' "$backup_dir" "$stamp" "$(( ${last:-0} + 1 ))" "$base")"
	cp -p -- "$config_path" "$backup" || die "backup failed; refusing to overwrite"
	# Record where this backup came from so restore never guesses.
	printf '%s\n' "$config_path" >"$backup.origin"
	printf '\nBacked up to: %s\n' "$backup"
	prune_backups
fi

mv -- "$candidate" "$config_path" || die "failed to install the new config"
trap - EXIT
printf 'Wrote: %s\n' "$config_path"
printf 'Reload Ghostty with cmd+shift+, (macOS) or ctrl+shift+, (Linux).\n'
