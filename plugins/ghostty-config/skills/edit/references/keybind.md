# `keybind` grammar

The grammar is stable and lives here. The **action names are not** — get those
from `ghostty +list-actions`, which every build has. `ghostty +explain-config
--keybind=NAME` also describes one, but only when `capabilities.explain_config`
is true; on a build without it that command exits non-zero for every name,
including valid ones.

## Shape

```ini
keybind = trigger=action
```

`keybind` is repeated, once per binding. Never merge two bindings onto one line
and never assume a later `keybind` line replaces an earlier one for a different
trigger — they accumulate.

## Triggers

Modifiers join with `+`:

```ini
keybind = ctrl+shift+t=new_tab
```

A **sequence** — a prefix key followed by another key, tmux style — uses `>`:

```ini
keybind = ctrl+a>n=new_window
```

Once `ctrl+a` is bound as a sequence prefix, it stops being available as a
standalone trigger. Say so before writing one; this is the single most common way
a user breaks a shortcut they relied on.

## Trigger prefixes

| Prefix | Meaning |
|---|---|
| `all:` | Applies to every terminal surface, not just the focused one. |
| `global:` | Works system-wide even when Ghostty is unfocused. Implies `all:`. |
| `unconsumed:` | Runs the action *and* still sends the keypress to the running program. |
| `performable:` | Consumes the input only if the action can actually run right now. |

```ini
keybind = performable:ctrl+c=copy_to_clipboard
keybind = global:cmd+grave=toggle_quick_terminal
keybind = unconsumed:ctrl+a=reload_config
```

Notes that matter in practice:

- `global:` and `all:` **always** consume input, so combining them with
  `unconsumed:` is contradictory.
- `performable:` bindings do not show up as menu shortcuts.
- `performable:ctrl+c=copy_to_clipboard` is the idiomatic way to keep `ctrl+c`
  working as SIGINT when nothing is selected. Plain `ctrl+c=copy_to_clipboard`
  swallows SIGINT — flag this if a user asks for it.
- `global:` on macOS may require an accessibility permission prompt; the binding
  is valid config either way, so validation passing is not proof it will fire.

## Actions

Actions take an optional `:argument`:

```ini
keybind = ctrl+d=new_split:right
keybind = ctrl+z=close_surface
```

`ghostty +list-actions` enumerates them. Validation catches a misspelled action
name, but it cannot catch a *valid* action that isn't what the user meant — read
the description back to them for anything non-obvious.

## Auditing what's bound

```sh
ghostty +list-keybinds --plain            # effective, after the user's config
ghostty +list-keybinds --default --plain  # shipped defaults
```

Diffing these two answers "what did I override?" — which is nearly always the
real question behind "my shortcut stopped working".
