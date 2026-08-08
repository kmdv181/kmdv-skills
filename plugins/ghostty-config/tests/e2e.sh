#!/usr/bin/env sh
# Tier 3 — the scripts driven end to end by the REAL ghostty, against a fixture
# config. This is Part A of tests/MANUAL.md, automated.
#
# Why a third tier rather than more of the other two:
#
#   hermetic.sh  drives the full apply/undo flow, but through a stub. It proves
#                the scripts' logic, and cannot prove they work.
#   contract.sh  uses the real binary, but invokes it one command at a time. It
#                proves the facts the scripts rely on, and never runs a script.
#
# Nothing checked that the two meet — that ghostty-apply.sh, driven by the real
# binary, actually produces a config the real binary then accepts. Everything
# below lives in that gap.
#
# Isolation: every invocation passes --config into a fixture tree and redirects
# XDG_STATE_HOME, so the real config and the real backup ring are never touched.
# The fixture config is a normal file in a temp directory, which is exactly what
# `--config` is for.
set -u

root=${GHOSTTY_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; fail=1; }
info() { echo "  --    $1"; }

echo "ghostty-config — end to end (real binary, fixture config)"

G="${GHOSTTY_BIN:-}"
if [ -z "$G" ]; then
	if command -v ghostty >/dev/null 2>&1; then G=$(command -v ghostty)
	elif [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then G="/Applications/Ghostty.app/Contents/MacOS/ghostty"
	elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then G="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
	fi
fi
if [ -z "$G" ] || [ ! -x "$G" ]; then
	echo
	echo "  SKIPPED — no ghostty binary found."
	echo "  The scripts were never driven by a real Ghostty in this run."
	exit 77
fi
info "binary: $G  ($("$G" +version 2>/dev/null | head -1))"

n=0
new_lab() {
	n=$((n + 1))
	LAB="$tmp/lab$n"
	mkdir -p "$LAB/state"
	CONFIG="$LAB/config.ghostty"
	BACKUPS="$LAB/state/ghostty-config-plugin/backups"
	printf 'font-family = Menlo\nfont-size = 13\n' >"$CONFIG"
}
apply() { env XDG_STATE_HOME="$LAB/state" GHOSTTY_BIN="$G" sh "$root/scripts/ghostty-apply.sh" "$@"; }
undo()  { env XDG_STATE_HOME="$LAB/state" GHOSTTY_BIN="$G" sh "$root/scripts/ghostty-undo.sh" "$@"; }
loads() { "$G" +validate-config --config-file="$1" >/dev/null 2>&1; }

# ------------------------------------------------------- is the stub honest?

# hermetic.sh's entire value rests on the stub behaving like the real binary on
# the inputs it claims to model. CLAUDE.md's rule — "a stub you wrote to match
# your own assumption will agree with you every time" — is only answerable here,
# with both binaries in the same process tree.
echo
echo "  --- the stub agrees with the real binary ---"

STUB="$here/stubs/ghostty"
printf 'font-size = 14\n'     >"$tmp/f-valid"
printf 'not-a-real-key = 1\n' >"$tmp/f-unknown"
: >"$tmp/f-zero"
printf '\n'                   >"$tmp/f-newline"
printf '# just a comment\n'   >"$tmp/f-comment"

for f in valid unknown zero newline comment; do
	"$G" +validate-config --config-file="$tmp/f-$f" >/dev/null 2>&1; r=$?
	sh "$STUB" +validate-config --config-file="$tmp/f-$f" >/dev/null 2>&1; s=$?
	if [ "$r" -eq "$s" ]; then
		ok "$f: real and stub both exit $r"
	else
		bad "$f: real exits $r, stub exits $s — hermetic.sh is testing against a fiction"
	fi
done

# The stub recognises a fixed list of bad keys; it is not a config validator and
# must not be mistaken for one. Asserting the limitation keeps it from being
# discovered later as a false pass — a hermetic test using a realistic bad key
# would sail through while the real binary rejects it.
printf 'font-ligatures = false\n' >"$tmp/f-unmodelled"
"$G" +validate-config --config-file="$tmp/f-unmodelled" >/dev/null 2>&1; r=$?
sh "$STUB" +validate-config --config-file="$tmp/f-unmodelled" >/dev/null 2>&1; s=$?
if [ "$r" -ne 0 ] && [ "$s" -eq 0 ]; then
	ok "known limit: the stub accepts unmodelled bad keys — hermetic fixtures must use the names in its case list"
elif [ "$r" -eq "$s" ]; then
	info "the stub now agrees on unmodelled keys too; the limitation note can go"
else
	bad "the stub REJECTS a key the real binary accepts — stricter than real, it will fail valid configs"
fi

# ------------------------------------------------ the real diagnostic format

# The stub's diagnostic string is something this repo invented. apply.sh rewrites
# the staging path out of it with sed, and that rewrite has only ever been tested
# against the invented format. This is the real one.
echo
echo "  --- a real diagnostic reaches the user, naming the real file ---"

new_lab
printf 'font-family = Menlo\nfont-sizee = 16\n' >"$LAB/cand"
out=$(apply --new "$LAB/cand" --config "$CONFIG" 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "a genuinely invalid config exits 1" || bad "invalid config exited $rc, expected 1"
grep -q 'font-size = 13' "$CONFIG" && ok "the config was not modified" || bad "the config WAS modified"
case "$out" in *font-sizee*) ok "ghostty's own diagnostic text is shown" ;; *) bad "the diagnostic was swallowed: $out" ;; esac
case "$out" in
	*ghostty-plugin-candidate*) bad "the staging filename leaked into the diagnostic — the sed rewrite does not match the real format" ;;
	*"$CONFIG"*) ok "the diagnostic names the config file, not the staging file" ;;
	*) bad "the diagnostic names neither file: $out" ;;
esac
find "$LAB" -name '*.ghostty-plugin-candidate' | grep -q . &&
	bad "a staging file was left behind" || ok "no staging file left behind"

# --------------------------------------------- what apply writes, ghostty loads

echo
echo "  --- what the scripts write, the binary accepts ---"

new_lab
printf 'font-family = Menlo\nfont-size = 16\n' >"$LAB/cand"
apply --new "$LAB/cand" --config "$CONFIG" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "a valid change applies" || bad "a valid change exited $rc"
loads "$CONFIG" && ok "the written config validates under the real binary" ||
	bad "the written config does NOT validate — the scripts produced a broken file"

# Clearing the config. The stub cannot prove this one: the fix exists precisely
# because the real binary rejects a zero-byte file, so only the real binary can
# show that the result of clearing is something it will actually load.
new_lab
: >"$LAB/empty"
apply --new "$LAB/empty" --config "$CONFIG" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "clearing the config applies" || bad "clearing the config exited $rc"
[ "$(wc -c <"$CONFIG" | tr -d ' ')" -eq 1 ] && ok "the cleared config is one byte, not zero" ||
	bad "the cleared config is $(wc -c <"$CONFIG" | tr -d ' ') bytes"
loads "$CONFIG" && ok "the cleared config validates under the real binary" ||
	bad "the cleared config does NOT validate — the zero-byte workaround does not work"

# A deprecated alias. SKILL.md Step 2 tells the agent these still work; if apply
# ever refused one, the guidance would be wrong at the point of writing.
new_lab
printf 'background-blur-radius = 20\n' >"$LAB/cand"
apply --new "$LAB/cand" --config "$CONFIG" >/dev/null 2>&1
[ $? -eq 0 ] && ok "a deprecated-alias key applies (the compatibility map holds)" ||
	bad "a deprecated alias was rejected on the write path, contradicting SKILL.md Step 2"

# ----------------------------------------------- why staging sits where it does

# ghostty-apply.sh stages the candidate next to the real config rather than in
# /tmp, because relative `config-file =` includes resolve against the including
# file's directory. That is a claim about the binary AND about the script, so it
# belongs here rather than in either other tier.
echo
echo "  --- relative includes survive the staging location ---"

new_lab
printf 'font-size = 15\n'         >"$LAB/included"
printf 'config-file = included\n' >"$CONFIG"
printf 'config-file = included\nfont-family = Menlo\n' >"$LAB/cand"
out=$(apply --new "$LAB/cand" --config "$CONFIG" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
	ok "a config with a relative include applies"
	loads "$CONFIG" && ok "the result, includes and all, validates" || bad "the applied config does not validate"
else
	bad "a relative include broke validation (exit $rc): $(printf '%s' "$out" | head -3)"
fi

# ----------------------------------------------------------------- undo, for real

echo
echo "  --- undo restores something the binary will load ---"

new_lab
printf 'font-family = Menlo\nfont-size = 20\n' >"$LAB/cand"
apply --new "$LAB/cand" --config "$CONFIG" >/dev/null 2>&1
undo --restore >/dev/null 2>&1
[ $? -eq 2 ] && ok "--restore still refuses without a target against the real binary" ||
	bad "--restore without a target did not exit 2"
undo --restore 1 >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "--restore 1 succeeds" || bad "--restore 1 exited $rc"
grep -q 'font-size = 13' "$CONFIG" && ok "the previous config is back" ||
	bad "after restore the config is: $(tr '\n' ' ' <"$CONFIG")"
loads "$CONFIG" && ok "the restored config validates under the real binary" ||
	bad "the restored config does NOT validate"

echo
[ "$fail" -eq 0 ] || { echo "FAILED"; exit 1; }
echo "e2e: all checks passed"
