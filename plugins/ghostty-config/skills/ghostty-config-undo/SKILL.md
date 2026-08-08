---
name: ghostty-config-undo
description: Roll back a Ghostty terminal config change to an earlier backup. Use when the user wants to undo, revert or restore a Ghostty config change — "put it back", "that broke my terminal", "revert the last config change" — or asks what config backups exist.
argument-hint: [backup number or filename, or blank to be shown the list]
allowed-tools: Read, Bash(sh:*), Bash(ghostty:*), Bash(/Applications/Ghostty.app/Contents/MacOS/ghostty:*)
---

# Rolling back a Ghostty config change

Restores one of the last five backups taken by `ghostty-apply.sh`.

**Always show the list and let the user choose.** Never pick a backup for them,
even when they say "just undo the last thing" — see why below.

## Flow

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --list
```

Numbered newest-first, with a readable timestamp and the config each one belongs
to. Show it to the user as-is and ask which one they want.

```sh
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --diff <N>
sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --restore <N>
```

`<N>` is the number from the list, or a backup filename. Show the diff and get
their agreement before restoring — timestamps alone don't tell anyone what a
backup contains.

`--restore` with no target refuses to run and prints the list instead. That is
deliberate; don't work around it.

## Why you must not guess

Every restore is itself an apply, so it takes its own backup. After one undo, the
newest entry in the ring is the state you just undid. A silent "restore the
newest" therefore toggles between two states while looking like it steps back
through history — and the further back the user actually wanted to go, the more
confidently it does the wrong thing.

The list makes the real shape visible, which is the whole point of showing it.

## The ring holds five

`ghostty-apply.sh` keeps the five most recent backups and deletes the rest
(`GHOSTTY_BACKUP_KEEP` overrides the count; `0` means unlimited). Undos consume
slots too, so a few rounds of undo and redo will push genuine history out.

If the user is hunting for a state that's several changes old, say early that the
ring may not reach it, rather than restoring three times and discovering it's
gone.

## After restoring

Tell them to reload Ghostty: `cmd+shift+,` on macOS, `ctrl+shift+,` on Linux.

The restore is validated and backed up like any other change, so it can itself be
undone — the state you replaced is now number 1 in the list.

If there are no backups at all, say so plainly. This plugin knows only about
changes it made itself; it will not try to reconstruct a config it never wrote.
