#!/usr/bin/env sh
# Run from anywhere:  sh plugins/nightcap/tests/run.sh
#
# One tier, because this plugin ships no scripts — nothing here has logic of its
# own to test hermetically. What it ships is prose an agent reads and then runs
# against a real tracker, so the only mechanical check worth having is the one
# that asserts that prose against the installed bd.
#
# What this tier CANNOT check is whether the prose tells the agent to do the
# right thing. Every command can exist, every flag can be accepted, and the
# protocol can still be wrong. That check is a hand-run session — see
# tests/MANUAL.md — and until someone runs it, a green result here means only
# that the skill is talking about commands that exist.
#
# A missing bd makes the tier SKIP, not pass.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
src=$(CDPATH='' cd -- "$here/.." && pwd)
rc=0

# Does the installed plugin match this working tree? `claude plugin update` keys
# off the version string, not the commit, so it reports success while serving an
# older tree.
name=$(basename "$src")
cache=$(ls -d "$HOME/.claude/plugins/cache"/*/"$name"/* 2>/dev/null | sort -V | tail -1)
echo "installed-copy drift"
if [ -z "$cache" ]; then
	echo "  --    $name is not installed from a marketplace; only the working tree was tested"
elif diff -r -x '.in_use' -x 'tests' "$src" "$cache" >/dev/null 2>&1; then
	echo "  ok    installed copy matches this tree ($cache)"
else
	echo "  --    installed copy DIFFERS from this tree:"
	diff -r -x '.in_use' -x 'tests' "$src" "$cache" 2>&1 | sed 's/^/          /' | head -20
	echo "        this run tested the tree, not what your sessions load."
fi
echo

sh "$here/contract.sh"
case $? in
	0)  ;;
	77) rc=0; skipped=yes ;;
	*)  rc=1 ;;
esac

echo
if [ "${skipped:-}" = yes ]; then
	echo "NOTE: the contract tier did not run. Nothing in SKILL.md was checked"
	echo "      against a real bd — not one command, not one flag."
fi
echo "NOTE: no automated tier reads the skill's instructions for correctness."
echo "      See tests/MANUAL.md."
[ "$rc" -eq 0 ] && echo "OK" || echo "FAILURES — see above"
exit "$rc"
