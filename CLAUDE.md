@AGENTS.md
@MEMORY.md

# Claude Code

The working rules are in `AGENTS.md` and the accumulated facts are in
`MEMORY.md`, both imported above. They are not duplicated here on purpose: this
repository has already shipped defects caused by knowledge copied into a second
place and left to rot. One copy, two harnesses.

Both imports are first-level and each sits alone on its line. A nested import —
`AGENTS.md` pulling in `MEMORY.md` — was tried first and silently failed to
resolve, so the facts were absent while everything still looked correct. Keep
new imports at the top level, on their own line, with no trailing punctuation.

Everything below is specific to Claude Code and belongs nowhere else.

- Confirm what actually loaded with `/context`, under **Memory files**. If
  `AGENTS.md` and `MEMORY.md` are not listed, the imports above did not resolve
  and you are working without them — say so rather than guessing at the rules.
- `claude plugin validate <dir> --strict` reads a plugin's skill and command
  frontmatter only when pointed at that plugin's directory. Run it at the repo
  root *and* per plugin.
- Skills in `plugins/*/skills/` are this repo's product. When you change one,
  remember that no schema check reads its prose: the instructions an agent
  follows are testable only by running an agent. See `AGENTS.md` on feedback
  loops, and `plugins/ghostty-config/tests/MANUAL.md` for the worked example.
