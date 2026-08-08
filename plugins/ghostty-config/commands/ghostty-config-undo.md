---
description: Roll back a Ghostty config change to an earlier backup
argument-hint: [backup filename, or blank for the most recent]
allowed-tools: Read, Bash(sh:*), Bash(ghostty:*), Bash(/Applications/Ghostty.app/Contents/MacOS/ghostty:*)
---

Roll back the user's Ghostty configuration using the `ghostty-config` skill's
undo flow.

1. List what's available:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --list`
2. Pick the target — `$ARGUMENTS` if given, otherwise the most recent backup.
3. Show what restoring would change:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --diff [BACKUP]`
4. Only after the user agrees to that diff:
   `sh "${CLAUDE_PLUGIN_ROOT}/scripts/ghostty-undo.sh" --restore [BACKUP]`

The restore is itself validated and backed up, so it can be undone in turn. Tell
the user to reload Ghostty afterwards (`cmd+shift+,` on macOS,
`ctrl+shift+,` on Linux).

If there are no backups, say so — this plugin only knows about changes it made
itself, and it will not attempt to reconstruct a config it never wrote.
