---
name: ghostty-config-undo
description: Roll back a Ghostty terminal config change to an earlier backup. Use when the user wants to undo, revert or restore a Ghostty config change — "put it back", "that broke my terminal", "revert the last config change" — or asks what config backups exist.
argument-hint: [backup filename, or blank for the most recent]
allowed-tools: Read, Bash(sh:*), Bash(ghostty:*), Bash(/Applications/Ghostty.app/Contents/MacOS/ghostty:*)
---

# Rolling back a Ghostty config change

Restores a backup taken by `ghostty-apply.sh`. The restore runs back through the
same apply path, so it is validated, diffed and itself backed up — an undo can be
undone.

Invoked with an argument, treat it as the backup to restore. Invoked with none,
use the most recent.

1. List what's available:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --list`
2. Show what restoring would change:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --diff [BACKUP]`
3. Only after the user agrees to that diff:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --restore [BACKUP]`

Never skip step 2. "Undo" sounds unambiguous, but the newest backup is the state
*before* the most recent change — which is not what the user means if they've made
two changes and want only the last one gone. The diff is what makes them notice.

Afterwards, tell them to reload Ghostty: `cmd+shift+,` on macOS, `ctrl+shift+,`
on Linux.

If there are no backups, say so plainly. This plugin knows only about changes it
made itself; it will not try to reconstruct a config it never wrote.
