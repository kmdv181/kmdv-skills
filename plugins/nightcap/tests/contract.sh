#!/usr/bin/env sh
# Contract tests against the REAL bd binary.
#
# This plugin ships no scripts — it ships prose an agent reads and then executes
# against someone's tracker. So the failure this tier exists to catch is the one
# that has shipped from this repo before: a command or flag written into the text
# that the installed binary does not have, or has with different semantics.
#
# Two halves:
#
#   1. Every `bd ...` invocation is EXTRACTED FROM SKILL.md and probed. Written
#      this way on purpose — a hand-maintained list of commands stops covering
#      the document the moment someone adds a line to it. Add a command to the
#      skill tomorrow and it is checked against the real binary tomorrow.
#   2. The behaviours the skill's advice depends on are asserted in a throwaway
#      workspace: that memory keys may contain a slash, that --key overwrites in
#      place, and that --notes replaces while --append-notes appends. That last
#      one is the reason the skill says what it says; if it ever stops being
#      true, the skill is giving harmful advice and must change.
#
# With no bd installed this exits 77 and says so loudly. It never passes
# silently.
set -u

root=${NIGHTCAP_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
skill="$root/skills/nightcap/SKILL.md"

fail=0
ok()   { echo "  ok      $1"; }
bad()  { echo "  DEFECT  $1"; fail=1; }
info() { echo "  --      $1"; }

echo "nightcap — contract (real bd)"

# ------------------------------------------------------------------ the binary

BD="${BD_BIN:-}"
[ -z "$BD" ] && command -v bd >/dev/null 2>&1 && BD=$(command -v bd)

if [ -z "$BD" ] || ! command -v "$BD" >/dev/null 2>&1; then
	echo
	echo "  SKIPPED — no bd binary found."
	echo "  This is the only tier that checks the skill against the real tracker."
	echo "  Nothing in SKILL.md was verified by this run."
	echo "  Install beads (https://github.com/gastownhall/beads), or set BD_BIN."
	exit 77
fi

info "bd: $BD ($("$BD" version 2>/dev/null | head -1))"

if [ ! -f "$skill" ]; then
	bad "SKILL.md not found at $skill"
	exit 1
fi

# ------------------------------------------------- half 1: what the skill says
#
# Only CODE contexts are read: fenced blocks whole, and the contents of inline
# backtick spans. Prose is excluded deliberately — an early version scanned the
# whole file and tried to run "bd itself would record" out of an ordinary
# English sentence. And flags are taken only from the text FOLLOWING the bd
# invocation on its line, or `command -v bd && bd ready` donates the -v that
# belongs to `command`.

work=$(mktemp -d)
tmp=$(mktemp -d)
# One trap for both scratch dirs. A second `trap ... EXIT` later in the file
# would silently replace this one and leak whichever dir it forgot.
cleanup() {
	# $tmp/ws, not $tmp — the workspace is the subdirectory, and `bd dolt stop`
	# from a directory with no .beads is a silent no-op that would leave a
	# sql-server running over the tree we are about to delete. No leak was
	# observed on bd 1.1.2, which does not keep one alive for these short
	# operations; this is still the directory the command means.
	( cd "$tmp/ws" 2>/dev/null && "$BD" dolt stop >/dev/null 2>&1 )
	rm -rf "$work" "$tmp"
}
trap cleanup EXIT INT TERM

awk '
	/^[[:space:]]*```/ { fence = !fence; next }
	fence              { print; next }
	{ n = split($0, part, "`"); for (i = 2; i <= n; i += 2) print part[i] }
' "$skill" > "$work/code"

: > "$work/pairs"
while IFS= read -r line; do
	case $line in *bd\ *) ;; *) continue ;; esac
	cmd=$(printf '%s\n' "$line" |
		grep -oE '(^|[[:space:]&|;(])bd( [a-z][a-z-]*)+' |
		head -1 | sed 's/^[^b]*//')
	[ -z "$cmd" ] && continue
	printf '%s\t\n' "$cmd" >> "$work/pairs"
	rest=${line#*"$cmd"}
	printf '%s\n' "$rest" | grep -oE ' --?[a-z][a-z-]*' | tr -d ' ' |
		while IFS= read -r f; do printf '%s\t%s\n' "$cmd" "$f" >> "$work/pairs"; done
done < "$work/code"

sort -u "$work/pairs" -o "$work/pairs"
[ -s "$work/pairs" ] || bad "extracted no bd commands from SKILL.md — the extractor is broken, not the doc"

echo
echo "  commands named in SKILL.md"
while IFS="$(printf '\t')" read -r cmd flag; do
	[ -n "$flag" ] && continue
	if "$BD" ${cmd#bd } --help >/dev/null 2>&1; then
		ok "$cmd"
	else
		bad "$cmd — not a command on this build"
	fi
done < "$work/pairs"

echo
echo "  flags named in SKILL.md"
while IFS="$(printf '\t')" read -r cmd flag; do
	[ -z "$flag" ] && continue
	# `bd close --reason` prints as `-r, --reason string`; match the flag token
	# itself, never a substring of a longer one (--notes vs --append-notes).
	if "$BD" ${cmd#bd } --help 2>&1 |
		grep -qE "(^|[[:space:],])$flag([[:space:],=]|$)"; then
		ok "$cmd $flag"
	else
		bad "$cmd $flag — flag not accepted on this build"
	fi
done < "$work/pairs"

# --------------------------------------- half 2: what the skill's advice needs

echo
echo "  behaviour the advice depends on"

# An empty directory with no workspace: the skill's precondition check.
if ( cd "$tmp" && "$BD" ready >/dev/null 2>&1 ); then
	bad "bd ready succeeded outside a beads workspace — the skill's precondition check is wrong"
else
	ok "bd ready fails outside a beads workspace (the skill's go/no-go check)"
fi

mkdir -p "$tmp/ws"
( cd "$tmp/ws" && git init -q . && git config user.email t@example.com && git config user.name tester )
if ! ( cd "$tmp/ws" && "$BD" init >/dev/null 2>&1 ); then
	bad "bd init failed in a scratch repo — cannot verify the rest"
	exit 1
fi

bdws() { ( cd "$tmp/ws" && "$BD" "$@" ) }

# Slashes in a key. The whole <name>/<topic> namespace rests on this.
bdws remember "sealed by the contract test" --key tester/nightcap >/dev/null 2>&1
if [ "$(bdws recall tester/nightcap 2>&1)" = "sealed by the contract test" ]; then
	ok "a memory key may contain a slash (<name>/<topic> is legal)"
else
	bad "slashed memory key did not round-trip — the namespace scheme in Step 0 does not work"
fi

# --key overwrites in place. "One key, always overwritten" depends on it.
bdws remember "resealed, later that night" --key tester/nightcap >/dev/null 2>&1
if [ "$(bdws recall tester/nightcap 2>&1)" = "resealed, later that night" ] &&
   [ "$(bdws memories 2>&1 | grep -c 'tester/nightcap')" -eq 1 ]; then
	ok "--key overwrites in place, leaving one key (the barrel seal)"
else
	bad "repeating --key did not overwrite in place — move 4 would accumulate a diary"
fi

# The one the skill argues from: --notes destroys, --append-notes preserves.
id=$(bdws q "contract probe" 2>&1 | tail -1)
if [ -z "$id" ]; then
	bad "could not create a probe issue; notes semantics unverified"
else
	bdws update "$id" --notes "stopped at step 3" >/dev/null 2>&1
	bdws update "$id" --notes "stopped at step 7" >/dev/null 2>&1
	if bdws show "$id" 2>&1 | grep -q "stopped at step 3"; then
		bad "--notes appended — SKILL.md's warning is now wrong and must be rewritten"
	else
		ok "--notes REPLACES the notes field (why the skill forbids it for handoff)"
	fi
	# `bd note` and not `--append-notes`, because `bd note` is what the skill
	# actually tells the agent to run. Its help calls it a shorthand for
	# --append-notes; that is a claim about bd, so assert the behaviour rather
	# than trusting the help text.
	bdws note "$id" "and then step 9" >/dev/null 2>&1
	if bdws show "$id" 2>&1 | grep -q "stopped at step 7" &&
	   bdws show "$id" 2>&1 | grep -q "and then step 9"; then
		ok "bd note appends, preserving what was already there"
	else
		bad "bd note did not preserve prior notes — the in-flight handoff loses it"
	fi
fi

echo
[ "$fail" -eq 0 ] && echo "  contract: OK" || echo "  contract: FAILURES"
exit "$fail"
