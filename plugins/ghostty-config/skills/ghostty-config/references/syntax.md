# Ghostty config file syntax

The grammar, which is stable. Individual **keys and their valid values are not
listed here on purpose** — ask the binary instead (see `cli.md`), because a baked
list drifts from whatever Ghostty build the user actually runs.

## Where the file lives

`config.ghostty` is the modern name; bare `config` is the pre-1.3.0 name and is
still loaded. Two separate questions have two different answers — don't conflate
them.

### Load order — which file wins

`Config.zig:loadDefaultFiles` loads **every** file that exists, in this order.
Later files override earlier ones, so the **last** row wins a conflict.

| Loaded | Platform | Path |
|---|----------|------|
| 1st | all | `${XDG_CONFIG_HOME:-~/.config}/ghostty/config` |
| 2nd | all | `${XDG_CONFIG_HOME:-~/.config}/ghostty/config.ghostty` |
| 3rd | macOS | `~/Library/Application Support/com.mitchellh.ghostty/config` |
| 4th | macOS | `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` |

So: XDG loads first and Application Support layers on top of it, and within each
directory the legacy `config` loads before `config.ghostty`. On macOS, Application
Support `config.ghostty` therefore has the final say over everything.

When both files in one directory exist, Ghostty logs a warning and loads both.
That warning goes to the log, not to the user's face — so if the probe reports two
existing candidates, surface it yourself.

### Edit target — which file to change

`+edit-config` (`src/config/edit.zig`) uses the **reverse** order — Application
Support before XDG, `config.ghostty` before `config` — and takes the first
candidate that exists *and is non-empty*; failing that the first that exists;
failing that the first candidate, which it creates.

That reversal is deliberate, and it's why the two lists don't contradict each
other: the first candidate in edit order is the last file in load order, i.e. the
highest-precedence file. Editing it is always effective.
`scripts/ghostty-env.sh` reproduces this rule and reports it as `config_path`.

One wrinkle: if the highest-precedence file exists but is *empty*, the edit rule
skips to the next non-empty one. That's still correct — an empty file sets
nothing — but it means `config_path` is not always literally the last-loaded file.

## Statements

```ini
# The syntax is "key = value". Whitespace around the equals doesn't matter.
background = 282c34
foreground = ffffff

# Comments start with `#` and are only valid on their own line.
# Blank lines are ignored.

keybind = ctrl+z=close_surface
keybind = ctrl+d=new_split:right

# An empty value resets the key to its default.
font-family =
```

- Keys are **case-sensitive and always lowercase**.
- Quoting is optional and carries no meaning:
  `font-family = "JetBrains Mono"` ≡ `font-family = JetBrains Mono`.
- An **empty value resets to the default** — this is a real operation, not a
  no-op. Deleting the line and writing `key =` mean different things when an
  earlier config file already set the key.
- Some keys accumulate rather than overwrite. `keybind` and `config-file` are
  repeated deliberately; do not collapse repeats into one line.

## Includes

```ini
config-file = some/relative/sub/config
config-file = ?optional/config
config-file = /absolute/path/config
```

- Relative paths resolve **relative to the file containing the directive** — this
  is why a candidate file must be validated from the real config's directory.
- `?` prefix makes a missing file non-fatal. To load a file whose name genuinely
  starts with `?`, quote the value.
- Includes are processed at the **end** of the containing file.
- Cycles are detected and produce a warning.

## Reload

`cmd+shift+,` on macOS, `ctrl+shift+,` on Linux, or any key bound to the
`reload_config` action. Some options cannot reload at runtime and others apply
only to newly opened terminals — when a change doesn't appear to take, that is
usually why, not a syntax error. Tell the user to reload after every applied
change.
