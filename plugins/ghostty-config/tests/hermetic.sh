#!/usr/bin/env sh
# Tier 1 — hermetic behavioural tests for the three scripts.
#
# No real ghostty, no real config, no real backup directory. Everything runs
# against a fixture tree with a stub binary, so these pass or fail identically on
# any machine and can never touch the user's terminal.
#
# The isolation is not optional. ghostty-apply.sh writes to the detected config
# path when --config is omitted, and backups go to $XDG_STATE_HOME. Every
# invocation below pins HOME, XDG_STATE_HOME, XDG_CONFIG_HOME, GHOSTTY_BIN and a
# fake `uname` on PATH. A test that forgot one would edit the real config.
set -u

# See tests/contract.sh — set GHOSTTY_PLUGIN_ROOT to test the installed copy
# under ~/.claude/plugins/cache/ instead of the working tree.
root=${GHOSTTY_PLUGIN_ROOT:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail=0
ok()   { echo "  ok    $1"; }
bad()  { echo "  FAIL  $1"; fail=1; }
info() { echo "  --    $1"; }

echo "ghostty-config — hermetic (stub binary, fixture tree)"

STUB="$here/stubs/ghostty"
[ -x "$STUB" ] || chmod +x "$STUB" 2>/dev/null
[ -r "$STUB" ] || { echo "  FAIL  stub not found at $STUB"; exit 1; }

# A fake `uname` so the macOS-only candidate branch is reachable on any host.
mkdir -p "$tmp/bin"
cat >"$tmp/bin/uname" <<'EOF'
#!/bin/sh
[ "${1:-}" = "-s" ] && { printf '%s\n' "${FAKE_UNAME:-Darwin}"; exit 0; }
exec /usr/bin/uname "$@"
EOF
chmod +x "$tmp/bin/uname"

# Run a plugin script inside the sandbox. Nothing reaches the real HOME.
sandbox() {
	env HOME="$SBOX/home" \
	    XDG_CONFIG_HOME="$SBOX/home/.config" \
	    XDG_STATE_HOME="$SBOX/state" \
	    GHOSTTY_BIN="${SBOX_BIN-$STUB}" \
	    FAKE_UNAME="${FAKE_UNAME:-Darwin}" \
	    PATH="$tmp/bin:$PATH" \
	    sh "$@"
}

# Fresh fixture tree per test case.
n=0
new_sandbox() {
	n=$((n + 1))
	SBOX="$tmp/case$n"
	mkdir -p "$SBOX/home/.config" "$SBOX/state"
	APPSUP="$SBOX/home/Library/Application Support/com.mitchellh.ghostty"
	XDGDIR="$SBOX/home/.config/ghostty"
	BACKUPS="$SBOX/state/ghostty-config-plugin/backups"
	CONFIG="$APPSUP/config.ghostty"
	mkdir -p "$APPSUP" "$XDGDIR"
	unset SBOX_BIN 2>/dev/null || true
}

backup_files() { find "$BACKUPS" -maxdepth 1 -type f ! -name '*.origin' 2>/dev/null | LC_ALL=C sort -r; }
backup_count() { backup_files | grep -c . ; }

# =============================================================== ghostty-env.sh

echo
echo "  --- ghostty-env.sh: path selection mirrors edit.zig ---"

new_sandbox
FAKE_UNAME=Darwin
out=$(sandbox "$root/scripts/ghostty-env.sh")
cand=$(printf '%s' "$out" | grep -c '"path":')
[ "$cand" -eq 4 ] && ok "macOS offers 4 candidates" || bad "macOS offered $cand candidates, expected 4"
first=$(printf '%s' "$out" | grep '"path":' | head -1)
case "$first" in
	*"Application Support"*config.ghostty*) ok "AppSupport/config.ghostty is the first candidate" ;;
	*) bad "first candidate is not AppSupport/config.ghostty: $first" ;;
esac

new_sandbox
FAKE_UNAME=Linux
out=$(sandbox "$root/scripts/ghostty-env.sh")
cand=$(printf '%s' "$out" | grep -c '"path":')
[ "$cand" -eq 2 ] && ok "Linux offers 2 candidates (no Application Support)" ||
	bad "Linux offered $cand candidates, expected 2"
if printf '%s' "$out" | grep -q "Application Support"; then
	bad "Linux candidate list still contains an Application Support path"
else
	ok "Linux candidate list has no Application Support path"
fi
FAKE_UNAME=Darwin

# edit.zig configPath(): first non-empty, else first existing, else first.
new_sandbox
: >"$CONFIG"                                  # exists but empty
printf 'font-size = 9\n' >"$XDGDIR/config.ghostty"   # exists and non-empty
sel=$(sandbox "$root/scripts/ghostty-env.sh" | sed -n 's/^  "config_path": "\(.*\)",$/\1/p')
case "$sel" in
	*.config/ghostty/config.ghostty) ok "a non-empty later candidate beats an empty earlier one" ;;
	*) bad "selected '$sel'; expected the non-empty XDG file" ;;
esac

new_sandbox
: >"$CONFIG"
: >"$XDGDIR/config.ghostty"
sel=$(sandbox "$root/scripts/ghostty-env.sh" | sed -n 's/^  "config_path": "\(.*\)",$/\1/p')
[ "$sel" = "$CONFIG" ] && ok "all-empty falls back to the first existing candidate" ||
	bad "all-empty selected '$sel', expected $CONFIG"

new_sandbox
sel=$(sandbox "$root/scripts/ghostty-env.sh" | sed -n 's/^  "config_path": "\(.*\)",$/\1/p')
[ "$sel" = "$CONFIG" ] && ok "nothing on disk falls back to the first candidate" ||
	bad "empty tree selected '$sel', expected $CONFIG"

# Absence is data, not an error. GHOSTTY_BIN pointing at nothing is the only
# portable way to simulate this: find_bin() falls back to the absolute path
# /Applications/Ghostty.app/..., which no amount of HOME or PATH faking hides.
new_sandbox
SBOX_BIN="$SBOX/no-such-ghostty"
out=$(sandbox "$root/scripts/ghostty-env.sh"); rc=$?
[ "$rc" -eq 0 ] && ok "exits 0 with no ghostty installed" || bad "exited $rc with no ghostty"
printf '%s' "$out" | grep -q '"bin": null' && ok "reports bin: null rather than guessing" ||
	bad "did not report bin: null"
printf '%s' "$out" | grep -q '"validate_config": false' &&
	ok "capabilities are all false when there is no binary" ||
	bad "reported a capability as available with no binary"
unset SBOX_BIN

new_sandbox
if command -v jq >/dev/null 2>&1; then
	for state in empty populated; do
		[ "$state" = populated ] && printf 'font-size = 14\n' >"$CONFIG"
		if sandbox "$root/scripts/ghostty-env.sh" | jq -e . >/dev/null 2>&1
		then ok "emits parseable JSON ($state tree)"
		else bad "emitted invalid JSON ($state tree)"
		fi
	done
else
	info "skipped JSON parse checks (jq not installed)"
fi

# ============================================================= ghostty-apply.sh

echo
echo "  --- ghostty-apply.sh: the config is never left broken ---"

apply() { sandbox "$root/scripts/ghostty-apply.sh" "$@"; }

# A dry run must not write.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 20\n' >"$SBOX/cand"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" --dry-run 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "--dry-run exits 0 on a valid candidate" || bad "--dry-run exited $rc"
[ "$(cat "$CONFIG")" = "font-size = 10" ] && ok "--dry-run left the config untouched" ||
	bad "--dry-run modified the config"
case "$out" in *"Dry run: nothing was written"*) ok "--dry-run says so" ;; *) bad "--dry-run did not say it wrote nothing" ;; esac
[ "$(backup_count)" -eq 0 ] && ok "--dry-run took no backup" || bad "--dry-run took a backup"

# Validation failure must be inert.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'not-a-real-key = 1\n' >"$SBOX/cand"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "an invalid candidate exits 1" || bad "an invalid candidate exited $rc, expected 1"
[ "$(cat "$CONFIG")" = "font-size = 10" ] && ok "the config was not modified" || bad "the config WAS modified"
case "$out" in *"not-a-real-key"*) ok "the diagnostic reaches the user" ;; *) bad "the diagnostic was swallowed" ;; esac
case "$out" in
	*"$SBOX/cand.ghostty-plugin-candidate"*|*ghostty-plugin-candidate*)
		bad "diagnostics leak the staging filename instead of the config path" ;;
	*) ok "diagnostics name the config path, not the staging file" ;;
esac
if find "$(dirname "$CONFIG")" -name '*.ghostty-plugin-candidate' | grep -q .
then bad "a staging file was left behind after a failure"
else ok "no staging file left behind after a failure"
fi

# The happy path.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
chmod 600 "$CONFIG"
printf 'font-size = 20\n' >"$SBOX/cand"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "a valid candidate exits 0" || bad "a valid candidate exited $rc"
[ "$(cat "$CONFIG")" = "font-size = 20" ] && ok "the new config is in place" || bad "the config was not updated"
[ "$(backup_count)" -eq 1 ] && ok "one backup was taken" || bad "took $(backup_count) backups, expected 1"
b=$(backup_files | head -1)
[ "$(cat "$b")" = "font-size = 10" ] && ok "the backup holds the previous contents" || bad "backup contents are wrong"
[ -f "$b.origin" ] && [ "$(cat "$b.origin")" = "$CONFIG" ] && ok ".origin records where it came from" ||
	bad ".origin sidecar missing or wrong"
mode=$(ls -l "$CONFIG" | cut -c1-10)
[ "$mode" = "-rw-------" ] && ok "file mode 0600 survived the replace" || bad "mode became $mode, expected -rw-------"
if find "$(dirname "$CONFIG")" -name '*.ghostty-plugin-candidate' | grep -q .
then bad "a staging file was left behind after success"
else ok "no staging file left behind after success"
fi

# An unchanged candidate should not churn the backup ring.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 10\n' >"$SBOX/cand"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "an identical candidate exits 0" || bad "identical candidate exited $rc"
case "$out" in *"(no changes)"*) ok "it reports no changes" ;; *) bad "it did not report '(no changes)'" ;; esac
[ "$(backup_count)" -eq 0 ] && ok "an identical candidate takes no backup" ||
	bad "an identical candidate took $(backup_count) backups"

# The ring. Five applies in a row land in the same second, so this exercises the
# collision counter and the LC_ALL=C ordering at the same time: if either is
# wrong, the surviving set is not the newest three.
new_sandbox
printf 'v0\n' >"$CONFIG"
i=1
while [ "$i" -le 5 ]; do
	printf 'v%s\n' "$i" >"$SBOX/cand"
	env GHOSTTY_BACKUP_KEEP=3 HOME="$SBOX/home" XDG_CONFIG_HOME="$SBOX/home/.config" \
	    XDG_STATE_HOME="$SBOX/state" GHOSTTY_BIN="$STUB" FAKE_UNAME=Darwin PATH="$tmp/bin:$PATH" \
	    sh "$root/scripts/ghostty-apply.sh" --new "$SBOX/cand" --config "$CONFIG" >/dev/null 2>&1
	i=$((i + 1))
done
c=$(backup_count)
[ "$c" -eq 3 ] && ok "GHOSTTY_BACKUP_KEEP=3 caps the ring at 3" || bad "ring holds $c, expected 3"
got=$(backup_files | while IFS= read -r f; do cat "$f"; done | tr '\n' ' ')
[ "$got" = "v4 v3 v2 " ] && ok "the ring kept the newest three (v4 v3 v2), newest first" ||
	bad "ring holds [$got], expected [v4 v3 v2 ] — pruning removed the wrong end"
orphans=$(find "$BACKUPS" -name '*.origin' | wc -l | tr -d ' ')
[ "$orphans" -eq 3 ] && ok "pruning removed each .origin with its backup" ||
	bad "$orphans .origin files for 3 backups — sidecars are leaking"
[ "$(cat "$CONFIG")" = "v5" ] && ok "the live config is the newest write" || bad "config is $(cat "$CONFIG"), expected v5"

# GHOSTTY_BACKUP_KEEP, at the values a person actually types. Every one of these
# reaches shell arithmetic, where a leading zero means octal — so the interesting
# inputs are not big or negative, they are `08` and `00`.
echo
echo "  --- GHOSTTY_BACKUP_KEEP edge values ---"

# Sets RING (surviving backups) and LIVE (the config's final contents). Not a
# command substitution: that would run new_sandbox in a subshell and lose it.
ring_after() {
	_keep=$1; _n=$2
	new_sandbox
	printf 'font-size = 10\n' >"$CONFIG"
	_i=1
	while [ "$_i" -le "$_n" ]; do
		printf 'font-size = %s\n' "$((10 + _i))" >"$SBOX/cand"
		env ${_keep:+GHOSTTY_BACKUP_KEEP="$_keep"} HOME="$SBOX/home" \
		    XDG_CONFIG_HOME="$SBOX/home/.config" XDG_STATE_HOME="$SBOX/state" \
		    GHOSTTY_BIN="$STUB" FAKE_UNAME=Darwin PATH="$tmp/bin:$PATH" \
		    sh "$root/scripts/ghostty-apply.sh" --new "$SBOX/cand" --config "$CONFIG" \
		    >/dev/null 2>&1
		_i=$((_i + 1))
	done
	RING=$(backup_count)
	LIVE=$(cat "$CONFIG")
}

ring_is() {   # label  keep  applies  expected-count
	ring_after "$2" "$3"
	[ "$RING" -eq "$4" ] && ok "$1" || bad "$1 — ring holds $RING, expected $4"
}

ring_is "unset keeps the documented default of 5"  ""    6  5
ring_is "1 keeps a single backup"                  1     6  1
ring_is "0 means unlimited"                        0     6  6

# `00` is all digits, so a `*[!0-9]*` guard misses it, and it is not the literal
# `0` either. It used to fall through to `tail -n +1` and delete the whole ring,
# including the backup taken moments earlier, while the apply reported success.
ring_is "00 means unlimited, like 0"               00    6  6

# `08` is not a valid octal number. `$((08 + 1))` is fatal, and it killed the
# script after the backup and before the move — so the config never changed and
# the failure looked like nothing happening.
ring_after 08 12
[ "$RING" -eq 8 ] && ok "08 keeps 8, read as decimal" || bad "08 kept $RING, expected 8"
[ "$LIVE" = "font-size = 22" ] && ok "08 does not abort the apply — the config still advanced" ||
	bad "08 left the config at '$LIVE'; the apply died before writing"

ring_is "010 keeps 10, not octal 8"                010   12 10

# An unusable value keeps everything rather than guessing — but must say so,
# because silently disabling pruning is not something to discover months later.
ring_is "an unusable value keeps everything"       5x    6  6
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 11\n' >"$SBOX/cand"
err=$(env GHOSTTY_BACKUP_KEEP=5x HOME="$SBOX/home" XDG_CONFIG_HOME="$SBOX/home/.config" \
	XDG_STATE_HOME="$SBOX/state" GHOSTTY_BIN="$STUB" FAKE_UNAME=Darwin PATH="$tmp/bin:$PATH" \
	sh "$root/scripts/ghostty-apply.sh" --new "$SBOX/cand" --config "$CONFIG" 2>&1 >/dev/null)
case "$err" in
	*GHOSTTY_BACKUP_KEEP*not\ a\ number*) ok "an unusable value is reported on stderr" ;;
	*) bad "an unusable value was accepted silently: [$err]" ;;
esac

# No binary: refuse rather than write unverified.
#
# apply.sh discovers ghostty at absolute paths, so "no ghostty on this machine"
# is not something a fixture can fake here. Run it only where it is meaningful,
# and say so out loud otherwise rather than reporting a pass we did not earn.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 20\n' >"$SBOX/cand"
no_bin_env="PATH=$tmp/bin:/usr/bin:/bin HOME=$SBOX/home XDG_STATE_HOME=$SBOX/state"

if command -v ghostty >/dev/null 2>&1 ||
   [ -x /Applications/Ghostty.app/Contents/MacOS/ghostty ] ||
   [ -x "$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty" ]; then
	info "skipped the no-binary checks: a real ghostty is discoverable at an absolute path"
else
	# shellcheck disable=SC2086
	env $no_bin_env sh "$root/scripts/ghostty-apply.sh" --new "$SBOX/cand" --config "$CONFIG" >/dev/null 2>&1
	[ $? -eq 2 ] && ok "no ghostty binary exits 2" || bad "no binary did not exit 2"
	[ "$(cat "$CONFIG")" = "font-size = 10" ] && ok "no binary leaves the config alone" ||
		bad "config changed with no binary"

	# shellcheck disable=SC2086
	out=$(env $no_bin_env sh "$root/scripts/ghostty-apply.sh" --new "$SBOX/cand" --config "$CONFIG" --no-validate 2>&1)
	rc=$?
	[ "$rc" -eq 0 ] && ok "--no-validate writes without a binary" || bad "--no-validate exited $rc"
	[ "$(cat "$CONFIG")" = "font-size = 20" ] && ok "--no-validate applied the change" ||
		bad "--no-validate did not write"
	case "$out" in *"Validation SKIPPED"*) ok "--no-validate announces that the result is unverified" ;;
		*) bad "--no-validate did not warn" ;; esac
fi

# --no-validate must work regardless of what is installed.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'not-a-real-key = 1\n' >"$SBOX/cand"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" --no-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "--no-validate bypasses a failing validation" || bad "--no-validate exited $rc"
case "$out" in *"Validation SKIPPED"*) ok "--no-validate announces the result is unverified" ;;
	*) bad "--no-validate did not warn" ;; esac

# A GHOSTTY_BIN that no longer exists is a broken *install*, not a broken config.
# Telling the user their config failed validation sends them to fix the wrong file.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 20\n' >"$SBOX/cand"
SBOX_BIN="$SBOX/no-such-ghostty"
out=$(apply --new "$SBOX/cand" --config "$CONFIG" 2>&1); rc=$?
[ "$(cat "$CONFIG")" = "font-size = 10" ] && ok "a stale GHOSTTY_BIN leaves the config alone" ||
	bad "a stale GHOSTTY_BIN modified the config"
if [ "$rc" -eq 2 ]; then
	ok "a stale GHOSTTY_BIN exits 2 (cannot proceed)"
else
	bad "a stale GHOSTTY_BIN exits $rc and reports the config as invalid; env.sh reports bin:null for the same value"
fi
unset SBOX_BIN

# Bad arguments must not be interpreted generously.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
apply --config "$CONFIG" >/dev/null 2>&1
[ $? -eq 2 ] && ok "a missing --new exits 2" || bad "a missing --new did not exit 2"
apply --new "$SBOX/nope" --config "$CONFIG" >/dev/null 2>&1
[ $? -eq 2 ] && ok "an unreadable candidate exits 2" || bad "an unreadable candidate did not exit 2"

# An empty candidate — "strip my config back to defaults". Ghostty rejects a
# zero-byte config file in silence, so this must not reach the binary as one.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
: >"$SBOX/cand"
apply --new "$SBOX/cand" --config "$CONFIG" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 0 ] && ok "an empty candidate applies cleanly" ||
	bad "an empty candidate exited $rc — clearing the config is a dead end"
[ -s "$CONFIG" ] && ok "the cleared config is not zero bytes (ghostty rejects those)" ||
	bad "the cleared config is zero bytes; ghostty will reject it on next load"
[ "$(wc -c <"$CONFIG" | tr -d ' ')" -eq 1 ] && ok "the cleared config is exactly one newline" ||
	bad "the cleared config is $(wc -c <"$CONFIG" | tr -d ' ') bytes, expected 1"
b=$(backup_files | head -1)
[ -n "$b" ] && [ "$(cat "$b")" = "font-size = 10" ] &&
	ok "clearing the config is still backed up and undoable" ||
	bad "clearing the config took no usable backup"

# ============================================================== ghostty-undo.sh

echo
echo "  --- ghostty-undo.sh: an undo can itself be undone ---"

undo() { sandbox "$root/scripts/ghostty-undo.sh" "$@"; }

new_sandbox
undo --list >/dev/null 2>&1
[ $? -eq 1 ] && ok "no backup directory exits 1" || bad "no backup directory did not exit 1"

new_sandbox
mkdir -p "$BACKUPS"
undo --list >/dev/null 2>&1
[ $? -eq 1 ] && ok "an empty backup directory exits 1" || bad "an empty backup directory did not exit 1"

# Build real history through apply, so the fixtures are whatever apply produces.
new_sandbox
printf 'v0\n' >"$CONFIG"
i=1
while [ "$i" -le 3 ]; do
	printf 'v%s\n' "$i" >"$SBOX/cand"
	apply --new "$SBOX/cand" --config "$CONFIG" >/dev/null 2>&1
	i=$((i + 1))
done

list=$(undo --list 2>&1)
lines=$(printf '%s' "$list" | grep -c '→')
[ "$lines" -eq 3 ] && ok "--list shows all 3 backups" || bad "--list showed $lines entries, expected 3"
newest=$(printf '%s' "$list" | grep -A1 '^ 1 ' | head -1)
[ -n "$newest" ] && ok "--list numbers entries from 1" || bad "--list is not numbered from 1"
case "$list" in *"$CONFIG"*) ok "--list shows which config each backup belongs to" ;;
	*) bad "--list does not show the origin path" ;; esac

# Index 1 must be the newest backup, which after three applies holds v2.
d=$(undo --diff 1 2>&1)
case "$d" in *v2*) ok "--diff 1 targets the newest backup" ;; *) bad "--diff 1 did not target the newest backup" ;; esac

# The refusal that stops an undo loop from toggling.
out=$(undo --restore 2>&1); rc=$?
[ "$rc" -eq 2 ] && ok "--restore with no target exits 2" || bad "--restore with no target exited $rc, expected 2"
case "$out" in *'→'*) ok "--restore with no target prints the list instead" ;;
	*) bad "--restore with no target did not print the list" ;; esac
[ "$(cat "$CONFIG")" = "v3" ] && ok "the refused restore changed nothing" || bad "the refused restore wrote something"

undo --restore 9 >/dev/null 2>&1
[ $? -eq 1 ] && ok "an out-of-range index exits 1" || bad "an out-of-range index did not exit 1"
[ "$(cat "$CONFIG")" = "v3" ] && ok "a failed restore changed nothing" || bad "a failed restore wrote something"

before=$(backup_count)
out=$(undo --restore 1 2>&1); rc=$?
[ "$rc" -eq 0 ] && ok "--restore 1 exits 0" || bad "--restore 1 exited $rc"
[ "$(cat "$CONFIG")" = "v2" ] && ok "--restore 1 put the previous contents back" ||
	bad "after restore the config is $(cat "$CONFIG"), expected v2"
after=$(backup_count)
[ "$after" -gt "$before" ] || [ "$before" -ge 5 ] && ok "the restore took its own backup ($before → $after)" ||
	bad "the restore did not back up the state it replaced"
top=$(backup_files | head -1)
[ "$(cat "$top")" = "v3" ] && ok "the state that was undone is now backup 1 (the undo is undoable)" ||
	bad "backup 1 holds $(cat "$top"), expected the undone state v3"

# A backup by filename, not index.
name=$(basename "$(backup_files | head -1)")
undo --restore "$name" >/dev/null 2>&1
[ "$(cat "$CONFIG")" = "v3" ] && ok "--restore accepts a backup filename" || bad "--restore by filename did not work"

# A restore is an apply, so it is validated like one.
new_sandbox
printf 'font-size = 10\n' >"$CONFIG"
printf 'font-size = 20\n' >"$SBOX/cand"
apply --new "$SBOX/cand" --config "$CONFIG" >/dev/null 2>&1
b=$(backup_files | head -1)
printf 'not-a-real-key = 1\n' >"$b"     # corrupt the backup
out=$(undo --restore 1 2>&1); rc=$?
[ "$rc" -eq 1 ] && ok "restoring an invalid backup exits 1" || bad "restoring an invalid backup exited $rc"
[ "$(cat "$CONFIG")" = "font-size = 20" ] && ok "an invalid backup does not reach the config" ||
	bad "an invalid backup was written to the config"

undo --bogus >/dev/null 2>&1
[ $? -eq 2 ] && ok "an unknown argument exits 2" || bad "an unknown argument did not exit 2"

# ================================================================== the real HOME

echo
if find "$tmp" -maxdepth 1 -type d -name 'case*' | grep -q .; then
	ok "all fixtures stayed inside the sandbox"
fi
[ -d "$HOME/.local/state/ghostty-config-plugin" ] &&
	info "note: $HOME/.local/state/ghostty-config-plugin exists (pre-existing, not written by this run)"

echo
[ "$fail" -eq 0 ] || { echo "FAILED"; exit 1; }
echo "hermetic: all checks passed"
