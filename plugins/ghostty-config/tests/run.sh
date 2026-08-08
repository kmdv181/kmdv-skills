#!/usr/bin/env sh
# Both tiers. Run from anywhere:  sh plugins/ghostty-config/tests/run.sh
#
#   hermetic.sh  stub binary + fixture tree. Asserts the scripts' own logic.
#                Deterministic, runs anywhere, never touches the real config.
#   contract.sh  the real ghostty, one command at a time. Asserts the facts the
#                scripts depend on — which flags exist, which exit codes mean
#                what. Catches the plugin drifting away from the user's build.
#   e2e.sh       the real ghostty driving the scripts, against a fixture config.
#                Where the other two meet: that what apply.sh writes is what the
#                binary then accepts. Also the only place the stub itself can be
#                checked for honesty, since both binaries are in reach at once.
#
# A missing ghostty makes the contract and e2e tiers SKIP, not pass. The run then
# exits 0 but says plainly what went unverified.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
src=$(CDPATH='' cd -- "$here/.." && pwd)
rc=0
skipped=""

# Does the installed plugin match this working tree? `claude plugin update` keys
# off the version string, not the commit, so it reports success while serving an
# older tree. Both tiers below test $src by default; this says whether that is
# also what the user's sessions load.
name=$(basename "$src")
cache=$(ls -d "$HOME/.claude/plugins/cache"/*/"$name"/* 2>/dev/null | tail -1)
echo "installed-copy drift"
if [ -z "$cache" ]; then
	echo "  --    $name is not installed from a marketplace; only the working tree was tested"
elif diff -r -x '.in_use' -x 'tests' "$src" "$cache" >/dev/null 2>&1; then
	echo "  ok    installed copy matches this tree ($cache)"
else
	echo "  --    installed copy DIFFERS from this tree:"
	diff -r -x '.in_use' -x 'tests' "$src" "$cache" 2>&1 | sed 's/^/          /' | head -20
	echo "        the tiers below tested this tree; re-run with"
	echo "        GHOSTTY_PLUGIN_ROOT=$cache to test what actually loads."
fi
echo

sh "$here/hermetic.sh" || rc=1
echo

sh "$here/contract.sh"
case $? in
	0)  ;;
	77) skipped="contract" ;;
	*)  rc=1 ;;
esac
echo

sh "$here/e2e.sh"
case $? in
	0)  ;;
	77) skipped="${skipped:+$skipped and }e2e" ;;
	*)  rc=1 ;;
esac

echo
if [ -n "$skipped" ]; then
	echo "NOTE: the $skipped tier did not run. Nothing was verified against a real"
	echo "      ghostty — only the scripts' internal logic was checked, and the stub"
	echo "      it was checked against went unverified too."
fi
[ "$rc" -eq 0 ] && echo "OK" || echo "FAILURES — see above"
exit "$rc"
