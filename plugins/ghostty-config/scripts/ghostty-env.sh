#!/bin/sh
# Probe the local Ghostty installation and emit a single JSON object on stdout.
#
# Nothing here is guessed: the config path candidates mirror
# src/config/edit.zig:configPathCandidates() and the selection rule mirrors
# configPath() — first candidate that exists and is non-empty, else first that
# exists, else the first candidate (the file Ghostty would create).
#
# Capability flags are probed by running each action, not assumed: several of
# these actions are recent additions and older builds will not have them.
#
# Exit status is always 0. Absence is reported in the JSON, not as an error.

set -u

GHOSTTY_APP_SUPPORT="Library/Application Support/com.mitchellh.ghostty"

# ---------------------------------------------------------------- json helper

jstr() {
	# Emit a JSON string. Escapes backslash, double quote and tab; paths with
	# raw control characters are not something this plugin needs to survive.
	if [ $# -eq 0 ] || [ -z "${1:-}" ]; then
		printf 'null'
		return
	fi
	printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g')"
}

jbool() {
	[ "$1" -eq 0 ] 2>/dev/null && printf 'true' || printf 'false'
}

# --------------------------------------------------------------- binary lookup

# PATH first, then the standard macOS bundle locations. GHOSTTY_BIN overrides
# everything, which is how you point the plugin at a non-standard install.
find_bin() {
	if [ -n "${GHOSTTY_BIN:-}" ]; then
		[ -x "$GHOSTTY_BIN" ] && { printf '%s' "$GHOSTTY_BIN"; return 0; }
		return 1
	fi
	if command -v ghostty >/dev/null 2>&1; then
		command -v ghostty
		return 0
	fi
	for candidate in \
		"/Applications/Ghostty.app/Contents/MacOS/ghostty" \
		"$HOME/Applications/Ghostty.app/Contents/MacOS/ghostty"
	do
		[ -x "$candidate" ] && { printf '%s' "$candidate"; return 0; }
	done
	return 1
}

# ---------------------------------------------------------------- config paths

# Mirrors src/config/edit.zig:configPathCandidates(). On macOS the Application
# Support paths win over XDG; `config.ghostty` is the modern name and `config`
# is the pre-1.3.0 name, both still loaded.
config_candidates() {
	xdg_home="${XDG_CONFIG_HOME:-$HOME/.config}"
	if [ "$(uname -s)" = "Darwin" ]; then
		printf '%s\n' "$HOME/$GHOSTTY_APP_SUPPORT/config.ghostty"
		printf '%s\n' "$HOME/$GHOSTTY_APP_SUPPORT/config"
	fi
	printf '%s\n' "$xdg_home/ghostty/config.ghostty"
	printf '%s\n' "$xdg_home/ghostty/config"
}

# Mirrors src/config/edit.zig:configPath() — prefer non-empty over empty,
# existing over absent, and fall back to the first candidate.
select_config() {
	# Collect into positional parameters: a `while read` in a pipeline runs in a
	# subshell and cannot hand its findings back.
	empty_hit=""
	old_ifs="$IFS"
	IFS='
'
	set -f  # paths are literal; never let a bracket in one glob-expand
	# shellcheck disable=SC2086
	set -- $(config_candidates)
	set +f
	IFS="$old_ifs"

	first="$1"
	for p in "$@"; do
		if [ -s "$p" ]; then
			printf '%s' "$p"
			return 0
		fi
		if [ -e "$p" ] && [ -z "$empty_hit" ]; then
			empty_hit="$p"
		fi
	done

	if [ -n "$empty_hit" ]; then
		printf '%s' "$empty_hit"
	else
		printf '%s' "$first"
	fi
}

# ------------------------------------------------------------------ capability

# Probe an action by actually running it. Side-effect free invocations only:
# nothing here writes, opens a window, or talks to a running Ghostty instance.
probe() {
	"$@" >/dev/null 2>&1
}

# ------------------------------------------------------------------------ main

bin="$(find_bin || true)"
version=""
cap_validate=1
cap_show=1
cap_explain=1
cap_themes=1
cap_keybinds=1

if [ -n "$bin" ]; then
	version="$("$bin" +version 2>/dev/null | grep -v '^[[:space:]]*$' | head -1)"

	# An empty file has no `config-file` includes, so validating it from a temp
	# directory is sound — unlike a real candidate, which must sit next to the
	# config it replaces.
	probe_dir="${TMPDIR:-/tmp}/ghostty-config-plugin-probe.$$"
	mkdir -p "$probe_dir" 2>/dev/null && : >"$probe_dir/empty"
	if [ -f "$probe_dir/empty" ]; then
		probe "$bin" +validate-config --config-file="$probe_dir/empty"
		cap_validate=$?
	fi
	rm -rf "$probe_dir" 2>/dev/null

	probe "$bin" +show-config --default --no-pager;      cap_show=$?
	probe "$bin" +explain-config --option=font-size;     cap_explain=$?
	probe "$bin" +list-themes --plain;                   cap_themes=$?
	probe "$bin" +list-keybinds --default --plain;       cap_keybinds=$?
fi

config="$(select_config)"
[ -e "$config" ] && exists=0 || exists=1

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ghostty-config-plugin/backups"
backup_count=0
[ -d "$backup_dir" ] && backup_count="$(find "$backup_dir" -type f 2>/dev/null | wc -l | tr -d ' ')"

printf '{\n'
printf '  "os": %s,\n'              "$(jstr "$(uname -s)")"
printf '  "bin": %s,\n'             "$(jstr "$bin")"
printf '  "version": %s,\n'         "$(jstr "$version")"
printf '  "config_path": %s,\n'     "$(jstr "$config")"
printf '  "config_exists": %s,\n'   "$(jbool "$exists")"
printf '  "candidates": [\n'
sep=""
config_candidates | while IFS= read -r p; do
	[ -e "$p" ] && present=true || present=false
	printf '%s    {"path": %s, "exists": %s}' "$sep" "$(jstr "$p")" "$present"
	sep=",
"
done
printf '\n  ],\n'
printf '  "backup_dir": %s,\n'      "$(jstr "$backup_dir")"
printf '  "backup_count": %s,\n'    "$backup_count"
printf '  "capabilities": {\n'
printf '    "validate_config": %s,\n' "$(jbool "$cap_validate")"
printf '    "show_config": %s,\n'     "$(jbool "$cap_show")"
printf '    "explain_config": %s,\n'  "$(jbool "$cap_explain")"
printf '    "list_themes": %s,\n'     "$(jbool "$cap_themes")"
printf '    "list_keybinds": %s\n'    "$(jbool "$cap_keybinds")"
printf '  }\n'
printf '}\n'
