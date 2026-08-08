---
name: edit
description: Read, explain and edit the Ghostty terminal configuration file conversationally. Use when the user wants to change how their terminal looks or behaves — themes, fonts, colors, padding, cursor, transparency, keybinds, shell integration, window behaviour — or asks what a Ghostty config key does, why a setting isn't taking effect, or wants to undo a config change.
argument-hint: [what to change, e.g. "dark theme, font 15, tmux-style splits"]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(sh:*), Bash(ghostty:*), Bash(/Applications/Ghostty.app/Contents/MacOS/ghostty:*)
---

# Editing a Ghostty config

The user describes what they want in plain language. You turn that into config
lines, prove they're valid, show the diff, and write only after they agree.

Invoked with an argument, treat it as the request. Invoked with none, read their
current config and walk them through what it sets before asking what to change.

Two rules carry most of the weight:

1. **The binary is the source of truth for keys, values, themes and actions.**
   Never write a key you haven't confirmed exists on *this* install. Ghostty
   ships `+explain-config`, `+show-config --default --docs`, `+list-themes`,
   `+list-actions`, `+list-fonts` precisely so you don't have to guess, and a
   guess that happens to be a real key from a different version is worse than an
   obvious error, because it validates and then silently does nothing.
2. **Never write directly to the config.** `scripts/ghostty-apply.sh` validates a
   candidate before anything is overwritten, so there is no window in which the
   user's terminal is misconfigured. Use it even for one-line changes.

## Reference material

Load these as needed rather than up front:

- [`references/syntax.md`](references/syntax.md) — file locations, statement
  syntax, resets, `config-file` includes, reload behaviour.
- [`references/cli.md`](references/cli.md) — every `+action`, its real flags, and
  which question each one answers.
- [`references/keybind.md`](references/keybind.md) — trigger grammar, sequences,
  the `global:`/`all:`/`unconsumed:`/`performable:` prefixes.

## Step 1 — probe

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-env.sh"
```

Returns JSON: `bin`, `version`, `config_path`, `config_exists`, `candidates`,
`backup_dir`, `backup_count`, and a `capabilities` map. It always exits 0 —
absence is reported in the data.

Read it before anything else, and react to what it says:

- **`bin` is null** — Ghostty isn't installed here. Say so plainly. This plugin
  belongs on the machine Ghostty runs on; if the user is SSH'd in from a Ghostty
  client, the config is on that client, not on this host. Don't fabricate a
  config path or offer to write one blind.
- **A capability is `false`** — that action is missing from this build. Fall back
  to another one (`+show-config --default --docs` covers most of what
  `+explain-config` gives you) and tell the user which check you couldn't run.
- **More than one entry in `candidates` has `"exists": true`** — the user is
  layering config files and may not realise it. Ghostty loads them all: XDG
  first, then Application Support on macOS, with `config` before `config.ghostty`
  in each directory, and later files win. `config_path` is already the
  highest-precedence file, so editing it is correct — but say which file you're
  touching and that another one is also being loaded underneath it. See
  `references/syntax.md` for the full ordering.

Then read the current config with the Read tool. Also run
`ghostty +show-config` — it shows the *effective* changed-from-default
settings, which catches values inherited from an included file that aren't
visible in the file you're reading.

## Step 2 — resolve the request against the binary

For every key you intend to write or change, confirm it exists. **Which command
does that depends on `capabilities.explain_config` from Step 1** — read the flag,
don't assume:

```sh
# capabilities.explain_config == true
ghostty +explain-config --option=<key>       # non-zero exit = no such key
ghostty +explain-config --keybind=<action>   # same, for keybind actions

# capabilities.explain_config == false  (every build up to and including 1.3.1)
ghostty +show-config --default | grep -E '^<key> ='   # no match = no such key
ghostty +list-actions | grep -qx '<action>'           # for keybind actions
```

`+explain-config` postdates 1.3.1. On a build without it, *every* invocation
exits non-zero — so using it unconditionally as a typo check marks every valid
key as a typo and is worse than not checking at all.

**A missing key is not automatically a typo.** `+show-config --default` lists
only *canonical* names, but Ghostty keeps renamed options working through a
compatibility map (`Config.zig:compatibility`), so a deprecated alias is absent
from that list and still valid. Validating a one-line file separates the two:

```sh
printf '%s = 1\n' "<key>" >/tmp/k.conf && ghostty +validate-config --config-file=/tmp/k.conf
```

| in `+show-config --default` | `+validate-config` | verdict |
|---|---|---|
| yes | accepts | current key — use it |
| no | accepts | deprecated alias — works, but write the canonical name instead and say why |
| no | rejects | genuine typo — do not write it |

Worked example on 1.3.1: `background-blur-radius` validates clean and is absent
from `+show-config`; it was renamed to `background-blur` in 1.1 and still maps
through. Reporting it as a typo would be wrong; writing it verbatim would leave
the user on a deprecated name.

For themes use `ghostty +list-themes --plain`; for fonts `ghostty +list-fonts`.

If the user's request is vague ("make it look nicer", "less cramped"), propose
two or three concrete options with the actual key names and let them pick. Don't
ask a clarifying question you can answer by reading their existing config.

Watch for requests that validate but misbehave:

- A `font-family` that isn't installed validates fine and silently falls back.
  Check it against `+list-fonts`.
- Binding a bare `ctrl+c` to `copy_to_clipboard` swallows SIGINT — offer
  `performable:` instead.
- Making a key a sequence prefix (`ctrl+a>n=…`) removes the standalone binding.
- Some options only apply to newly opened terminals, or can't reload at all.

## Step 3 — build the candidate

Write the complete intended config to a scratch file — not a fragment, the whole
file as it should end up. Preserve the user's comments, ordering and grouping;
this is a file a human reads and edits by hand, and a rewrite that reorders it is
a bad diff even when it's a correct config.

Prefer the smallest edit that expresses the intent: change the value in place if
the key exists, append near related keys if it doesn't. When removing a setting,
decide between deleting the line and writing `key =` — those differ when another
config file sets the same key (see `references/syntax.md`).

## Step 4 — dry run, then apply

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-apply.sh" --new /path/to/candidate --dry-run
```

This validates the candidate and prints a unified diff without writing anything.

- **Validation fails** — the diagnostics name the offending line. Fix and re-run;
  don't apply with `--no-validate` to get past an error you don't understand.
- **Validation passes** — show the user the diff and what each change does, then
  wait for their agreement. Don't apply on the strength of the original request;
  they haven't seen the diff yet.

Then drop `--dry-run`:

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-apply.sh" --new /path/to/candidate
```

The script backs the old file up under
`${XDG_STATE_HOME:-~/.local/state}/ghostty-config-plugin/backups/` with an
`.origin` sidecar, then moves the validated candidate into place.

Finish by telling them to reload: `cmd+shift+,` on macOS, `ctrl+shift+,` on
Linux. Add that a restart is needed if the changed key doesn't apply at runtime.

`--no-validate` exists only for a machine with no Ghostty binary. It writes
unverified — say so explicitly before using it, and never reach for it to
silence a real diagnostic.

## Undo

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --list
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --diff <N>
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --restore <N>
```

The `undo` skill owns this flow — hand off to it rather than
reimplementing the steps here. The short version: the ring holds the five most
recent backups, `--restore` refuses to run without an explicit target, and you
show the list and let the user pick. Never choose for them; a restore is itself
an apply that takes its own backup, so "the newest" means something different
after every undo.

## Diagnosing "my config isn't working"

Work outward from cheapest to most expensive:

1. `ghostty +validate-config` (no `--config-file`) — validates the live default
   paths. Syntax and unknown-key errors surface here.
2. `ghostty +show-config` — the effective changed-from-default values.
   If the key isn't listed, it never took; if it's listed with a value the user
   didn't write, something else set it.
3. Check `candidates` from the probe for a second config file overriding the
   first, and grep the config for `config-file` includes.
4. `ghostty +list-keybinds --plain` vs `--default --plain` for shortcut problems.
5. If all of that is clean, the setting is probably reload-scoped or
   new-terminal-scoped. Have them fully restart Ghostty before digging further.
