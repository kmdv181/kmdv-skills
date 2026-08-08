---
description: Change your Ghostty terminal config by describing what you want
argument-hint: [what to change, e.g. "switch to a dark theme and bump the font to 15"]
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(sh:*), Bash(ghostty:*), Bash(/Applications/Ghostty.app/Contents/MacOS/ghostty:*)
---

Use the `ghostty-config` skill to carry out this request against the user's
Ghostty configuration:

**$ARGUMENTS**

Follow the skill's flow: probe with `scripts/ghostty-env.sh`, read the current
config, confirm every key against the binary before writing it, build a complete
candidate file, `--dry-run` it, show the diff, and apply only after the user
agrees.

If `$ARGUMENTS` is empty, read their current config and walk them through what
it currently sets — then ask what they'd like to change.
