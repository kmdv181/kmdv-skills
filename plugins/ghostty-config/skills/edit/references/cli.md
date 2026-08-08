# The `ghostty` CLI as a source of truth

Every question of the form "is `X` a real key?", "what values does `X` take?",
"what themes exist?", "what does action `Y` do?" is answered by the binary, which
is version-matched to the user's install. Never answer these from memory.

Actions are invoked as `ghostty +action`. The complete set, from
`src/cli/ghostty.zig`:

`version` · `help` · `list-fonts` · `list-keybinds` · `list-themes` ·
`list-colors` · `list-actions` · `ssh` · `ssh-cache` · `edit-config` ·
`show-config` · `explain-config` · `validate-config` · `show-face` ·
`crash-report` · `boo` · `new-window` · `toggle-quick-terminal`

Only one `+action` may appear per invocation. `+explain-config`, `+new-window`
and `+toggle-quick-terminal` are recent — `scripts/ghostty-env.sh` probes for
them rather than assuming, and reports the result under `capabilities`.

## The ones this plugin uses

### `+validate-config`

```sh
ghostty +validate-config --config-file=PATH
```

Exit `0` = clean. Exit `1` = diagnostics printed on stdout, one per line.

With `--config-file`, it validates **that file alone** (defaults + the file + its
recursive includes) — not the user's live config. That property is what makes the
candidate-file workflow safe. Without the flag it validates the default config
paths, which is the right call for "is my current setup healthy?".

### `+show-config`

```sh
ghostty +show-config                    # only keys changed from default
ghostty +show-config --default --docs   # every key, with documentation
```

`--changes-only` defaults to **true**, so a bare `+show-config` shows the user's
diffs against the defaults, not the full key set. `--default` ignores the user
config and implies the full set. Use `--default --docs` when you need the
authoritative key inventory; use the bare form to see what the user has actually
customised, including values Ghostty normalised or filled in.

**Do not add `--no-pager`.** It was added after 1.3.0 and older builds reject it
— and a rejected flag makes the whole action exit 1 printing *nothing*, which
reads exactly like "this user has customised nothing". It buys nothing anyway:
the pager only spawns when stdout is a TTY, and when you run this, stdout is a
pipe. This flag was in these docs for four releases and silently broke
`+show-config` on every 1.3.x install; `tests/contract.sh` now runs every command
written here against the real binary so the next one is caught.

### `+explain-config`

```sh
ghostty +explain-config --option=font-size
ghostty +explain-config --keybind=copy_to_clipboard
```

The precise way to check one key or one keybind action. Prefer this over grepping
`+show-config --docs` output when the question is about a single item — and use a
non-zero exit as evidence the name is wrong, which is exactly how you catch a
typo before writing it.

### `+list-themes`

```sh
ghostty +list-themes --plain            # plain list instead of the TUI
ghostty +list-themes --plain --path     # include each theme's file path
ghostty +list-themes --plain --color=dark   # .all | .dark | .light
```

Without `--plain` this opens an interactive picker when stdout is a terminal.

### `+list-keybinds`

```sh
ghostty +list-keybinds --plain              # the user's effective binds
ghostty +list-keybinds --default --plain    # the shipped defaults
ghostty +list-keybinds --default --docs --plain
```

Diff the two to show which defaults the user has displaced — the usual cause of
"this shortcut stopped working".

### `+list-actions`, `+list-colors`, `+list-fonts`

Valid keybind action names, valid named colors, and installed font family names
respectively. `+list-fonts` is how you verify a `font-family` value exists before
writing it; an unknown family is not a config error, it just silently falls back.

### `+edit-config`

Opens the config in the user's editor. Mentioned for completeness — this plugin
does not call it, since it would hand control to an interactive editor.
