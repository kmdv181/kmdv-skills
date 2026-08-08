#!/usr/bin/env sh
# Tier 2 — contract tests against the REAL ghostty binary.
#
# These assert the facts the plugin's scripts and skills depend on. They are the
# only tier that can catch the plugin drifting away from the binary the user
# actually runs, because a stub written from the same assumption as the code will
# always agree with it.
#
# Two distinct failure classes, deliberately kept apart:
#
#   DEFECT  — the action exists on this build but the plugin uses it wrongly
#             (a flag the build rejects, an exit code the scripts misread).
#   ABSENT  — the action does not exist on this build at all. Not a defect:
#             ghostty-env.sh probes for these and the skill is told to fall back.
#             Reported so a stale reference is still visible.
#
# With no ghostty installed this exits 77 and says so loudly. It never passes
# silently — a skipped contract test that looks green is how the plugin got here.
set -u

# GHOSTTY_PLUGIN_ROOT points the whole suite at a different copy of the plugin.
# The copy that matters to the user is the installed one —
#   ~/.claude/plugins/cache/kmdv181/ghostty-config/<version>/
# — which is what their sessions load, and which `claude plugin update` will
# happily leave stale while reporting success. Testing only the working tree
# verifies the source, not the thing that runs.
root=${GHOSTTY_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
ok()   { echo "  ok      $1"; }
bad()  { echo "  DEFECT  $1"; fail=1; }
note() { echo "  absent  $1"; }
info() { echo "  --      $1"; }

echo "ghostty-config — contract (real binary)"

# ------------------------------------------------------------------ the binary

G="${GHOSTTY_BIN:-}"
if [ -z "$G" ]; then
	if command -v ghostty >/dev/null 2>&1; then
		G=$(command -v ghostty)
	elif [ -x "/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
		G="/Applications/Ghostty.app/Contents/MacOS/ghostty"
	elif [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
		G="$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
	fi
fi

if [ -z "$G" ] || [ ! -x "$G" ]; then
	echo
	echo "  SKIPPED — no ghostty binary found."
	echo "  These are the checks that verify the plugin against the real thing."
	echo "  Nothing about the binary contract was verified by this run."
	echo "  Set GHOSTTY_BIN, or run this on the machine Ghostty is installed on."
	exit 77
fi

version=$("$G" +version 2>/dev/null | grep -v '^[[:space:]]*$' | head -1)
info "binary:  $G"
info "version: ${version:-unknown}"

# Actions this build advertises. Used to tell DEFECT from ABSENT.
"$G" +help >"$tmp/help" 2>&1 || true
has_action() { grep -q "^  +$1\$" "$tmp/help"; }

# Never run: these open an editor, a window, or talk to a running instance.
# `action` is the placeholder the docs use when describing the `+action` form.
INTERACTIVE="edit-config new-window toggle-quick-terminal boo ssh ssh-cache crash-report action"
is_interactive() {
	for a in $INTERACTIVE; do [ "$a" = "$1" ] && return 0; done
	return 1
}

echo
echo "  --- validate-config: the plugin's safety guarantee ---"

printf 'font-size = 14\n'      >"$tmp/valid"
printf 'not-a-real-key = 1\n'  >"$tmp/invalid"
: >"$tmp/zero"
printf '\n'                    >"$tmp/newline"

# 1. The flag the scripts are built on exists.
"$G" +validate-config --config-file="$tmp/valid" >"$tmp/o" 2>"$tmp/e"
rc=$?
if [ "$rc" -eq 0 ]; then
	ok "--config-file accepted; a valid config exits 0"
else
	bad "a valid config did not exit 0 (exit $rc): $(cat "$tmp/o" "$tmp/e")"
fi

# 2. Bad config must exit non-zero AND say why. A silent failure is unusable:
#    ghostty-apply.sh prints the diagnostics to the user as the whole
#    explanation of what went wrong.
"$G" +validate-config --config-file="$tmp/invalid" >"$tmp/o" 2>"$tmp/e"
rc=$?
if [ "$rc" -eq 0 ]; then
	bad "an unknown config key exited 0 — validation is not catching typos"
elif [ ! -s "$tmp/o" ] && [ ! -s "$tmp/e" ]; then
	bad "an invalid config exited $rc with no diagnostics at all"
else
	ok "an invalid config exits $rc with diagnostics"
	if grep -q "$tmp/invalid" "$tmp/o" "$tmp/e" 2>/dev/null; then
		ok "diagnostics name the file being validated (apply.sh rewrites this path)"
	else
		bad "diagnostics do not name the file; apply.sh's sed rewrite is a no-op"
	fi
fi

# 3. The capability probe in ghostty-env.sh validates a fixture file. Whatever
#    fixture it uses must itself be valid, or the probe reports the plugin's
#    core capability as missing on a healthy install.
"$G" +validate-config --config-file="$tmp/zero" >/dev/null 2>&1
zero_rc=$?
"$G" +validate-config --config-file="$tmp/newline" >/dev/null 2>&1
newline_rc=$?
info "zero-byte file exits $zero_rc; single-newline file exits $newline_rc"
[ "$zero_rc" -ne 0 ] && info "this build rejects a zero-byte config file"
# Whether env.sh's probe fixture is a good one is settled behaviourally further
# down, by check_cap validate_config. Grepping env.sh for the fixture it writes
# would pass the moment someone refactored `: >f` into `touch f` — still
# zero-byte, still broken, but no longer matching the pattern.

# 4. The reason candidates are staged next to the real config: relative
#    config-file includes resolve against the including file's directory. If this
#    stopped being true, staging in /tmp would be safe and the comment in
#    ghostty-apply.sh would be wrong.
mkdir -p "$tmp/inc"
printf 'font-size = 13\n'          >"$tmp/inc/included"
printf 'config-file = included\n'  >"$tmp/inc/main"
"$G" +validate-config --config-file="$tmp/inc/main" >"$tmp/o" 2>&1
if [ $? -eq 0 ] && [ ! -s "$tmp/o" ]; then
	ok "a relative config-file include resolves next to its includer"
else
	bad "relative include did not resolve: $(cat "$tmp/o")"
fi

# 5. ghostty-apply.sh's contract with itself: exit 1 must mean "not applied".
echo
echo "  --- every command the docs tell the agent to run ---"

# Extracted from the skills, not hand-listed here: a command that gets written
# into a SKILL.md or a reference tomorrow is executed by this test tomorrow.
# That is the loop that catches documentation drifting ahead of the user's build.
grep -rhoE '(ghostty|\$G) \+[a-z-]+( --[a-z-]+(=[^ `"]*)?)*' \
	"$root/skills" "$root/README.md" 2>/dev/null |
	sed -e 's/^\$G /ghostty /' |
	sort -u >"$tmp/cmds"

[ -s "$tmp/cmds" ] || info "no ghostty commands found in skills/ — nothing to sweep"

while IFS= read -r cmd; do
	[ -n "$cmd" ] || continue
	action=$(printf '%s' "$cmd" | sed -n 's/^ghostty +\([a-z-]*\).*/\1/p')
	[ -n "$action" ] || continue
	is_interactive "$action" && { info "skipped (interactive): $cmd"; continue; }

	# Substitute the doc placeholders with something real.
	real=$(printf '%s' "$cmd" |
		sed -e "s|--config-file=PATH|--config-file=$tmp/valid|" \
		    -e 's|--option=<key>|--option=font-size|' \
		    -e 's|--keybind=<action>|--keybind=copy_to_clipboard|' \
		    -e 's|--keybind=NAME|--keybind=copy_to_clipboard|')
	case "$real" in *'<'*|*'PATH'*|*'NAME'*) info "skipped (unsubstituted placeholder): $cmd"; continue ;; esac

	if ! has_action "$action"; then
		note "+$action is not an action on this build: $cmd"
		continue
	fi

	# shellcheck disable=SC2086
	eval "\"\$G\" ${real#ghostty }" >"$tmp/o" 2>"$tmp/e"
	rc=$?
	if [ "$rc" -eq 0 ]; then
		ok "$cmd"
	elif [ ! -s "$tmp/o" ] && [ ! -s "$tmp/e" ]; then
		bad "$cmd → exit $rc, no output at all (a rejected flag looks like an empty result)"
	else
		bad "$cmd → exit $rc: $(head -2 "$tmp/o" "$tmp/e" | tr '\n' ' ')"
	fi
done <"$tmp/cmds"

# 6. The probe's capability map must agree with the binary, flag by flag. This is
#    the check that closes the loop between what env.sh reports and what is true.
echo
echo "  --- ghostty-env.sh capability map vs the binary ---"

env_json=$(GHOSTTY_BIN="$G" sh "$root/scripts/ghostty-env.sh")
# BSD sed has no \| alternation, so match the key and strip the rest by hand.
cap() {
	printf '%s' "$env_json" |
		grep -F "\"$1\":" |
		sed -e 's/.*: *//' -e 's/[^a-z].*$//' |
		head -1
}

check_cap() {
	name=$1; shift
	reported=$(cap "$name")
	"$@" >/dev/null 2>&1 && actual=true || actual=false
	if [ "$reported" = "$actual" ]; then
		ok "$name reported $reported, binary agrees"
	else
		bad "$name reported $reported but the binary says $actual"
	fi
}

check_cap validate_config "$G" +validate-config --config-file="$tmp/valid"
check_cap list_themes     "$G" +list-themes --plain
check_cap list_keybinds   "$G" +list-keybinds --default --plain

# The flags below are hardcoded on purpose: they are a known-good way to invoke
# each action, independent of how env.sh chooses to probe it. Reading the flags
# back out of env.sh would make this agree with env.sh by construction — the
# same source-coupling deleted above — and a reformatted probe line would yield
# empty flags, a bare invocation that exits 0, and a silent pass on exactly the
# defect this exists to catch.
#
# So: env.sh says false, a known-good invocation says true -> env.sh's probe is
# using a flag this build rejects. That is the --no-pager defect, in both
# directions, with nothing parsed.
for pair in "show_config:+show-config:--default" "explain_config:+explain-config:--option=font-size"; do
	name=${pair%%:*}
	rest=${pair#*:}
	act=${rest%%:*}
	flags=${rest#*:}
	reported=$(cap "$name")
	# shellcheck disable=SC2086
	"$G" $act $flags >/dev/null 2>&1 && actual=true || actual=false
	if [ "$reported" = "$actual" ]; then
		ok "$name reported $reported, binary agrees ($act $flags)"
	elif [ "$reported" = "false" ] && [ "$actual" = "true" ]; then
		bad "env.sh reports $name false, but '$act $flags' works — its probe is using a flag this build rejects"
	else
		bad "$name reported $reported but '$act $flags' says $actual"
	fi
	if [ "$actual" = "false" ] && has_action "${act#+}"; then
		bad "$act EXISTS on this build yet '$act $flags' fails — the known-good invocation is wrong"
	fi
done

echo
[ "$fail" -eq 0 ] || { echo "FAILED"; exit 1; }
echo "contract: all checks passed"
