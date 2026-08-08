# ghostty-config

A Claude Code plugin for editing the [Ghostty](https://ghostty.org) terminal
configuration by describing what you want.

```
/ghostty-config switch to a dark theme, bump the font to 15, and give me tmux-style splits
```

Claude finds your config the same way Ghostty does, checks every key against your
installed binary, validates the change *before* touching the real file, shows you
the diff, and applies it only when you say so.

## Install it where Ghostty runs

The plugin shells out to the `ghostty` binary and edits a file on the local disk,
so it has to run on the machine Ghostty is installed on — not on a remote host
you're SSH'd into from a Ghostty window.

```sh
/plugin marketplace add kmdv181/kmdv-skills
/plugin install ghostty-config@kmdv181
```

Set `GHOSTTY_BIN` if your install isn't on `PATH` and isn't at
`/Applications/Ghostty.app/Contents/MacOS/ghostty`.

## Commands

| Command | What it does |
|---|---|
| `/ghostty-config [request]` | Make a change. With no argument, explains your current config first. |
| `/ghostty-config-undo [backup]` | Roll back to a backup. Defaults to the most recent. |

The `ghostty-config` skill also loads on its own when you ask about Ghostty
settings in conversation — you don't have to use the slash commands.

## Why it doesn't ship a list of config keys

Ghostty's own binary can enumerate every valid key, value, theme, font and
keybind action for the exact version you're running:

```sh
ghostty +explain-config --option=font-size
ghostty +show-config --default --docs --no-pager
ghostty +list-themes --plain
ghostty +list-actions
```

A key list baked into the plugin would drift from your install and start
confidently recommending settings that don't exist — or, worse, ones that do
exist in some other version and validate but do nothing. So the plugin ships the
*grammar* (which is stable) and asks the binary for everything else.

## How a write is made safe

`+validate-config --config-file=PATH` validates that file in isolation — the
defaults plus that file plus its recursive includes — without touching your live
config. So the flow is:

1. Write the intended config to `<config-dir>/<name>.ghostty-plugin-candidate`.
   It lives in the config's own directory because relative `config-file =`
   includes resolve relative to the file containing them; validating from `/tmp`
   would give a verdict about a different file.
   Ghostty matches `config.ghostty` and `config` by exact filename, so the
   staging file is inert even if a crash leaves it behind.
2. `ghostty +validate-config --config-file=<candidate>`.
3. On failure: print the diagnostics, delete the candidate, **exit without
   touching the config**.
4. On success: back the old file up, print a unified diff, `mv` the candidate
   into place.

Your config is never briefly broken, so rollback is a user-facing undo rather
than an error path.

Backups go to `${XDG_STATE_HOME:-~/.local/state}/ghostty-config-plugin/backups/`
as `<timestamp>-<basename>`, each with an `.origin` sidecar recording which file
it came from. Nothing is written into `Application Support`.

## Scripts

Usable on their own, no Claude required:

```sh
scripts/ghostty-env.sh                                  # probe → JSON
scripts/ghostty-apply.sh --new FILE [--dry-run]         # validate, diff, apply
scripts/ghostty-undo.sh --list | --diff | --restore     # rollback
```

`ghostty-env.sh` always exits 0 and reports absence in its JSON. `ghostty-apply.sh`
exits `1` on validation failure and `2` when it can't proceed at all.

Everything is POSIX `sh` with no dependencies beyond `diff`, `sed` and `find`.

## Config file locations

Every file that exists is loaded, in this order — later files override earlier
ones:

1. `${XDG_CONFIG_HOME:-~/.config}/ghostty/config`
2. `${XDG_CONFIG_HOME:-~/.config}/ghostty/config.ghostty`
3. `~/Library/Application Support/com.mitchellh.ghostty/config` *(macOS)*
4. `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` *(macOS)*

`config.ghostty` is the modern name; bare `config` is pre-1.3.0 and still loaded.

The plugin edits whichever file `ghostty +edit-config` would open — which walks
that list backwards and takes the first one that exists and is non-empty, i.e. the
highest-precedence file. If more than one exists, it tells you, because Ghostty
only mentions it in a log line you'll never see.

## License

MIT
