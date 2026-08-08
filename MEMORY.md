# Facts worth not re-deriving

Things this repository has already paid for. Every entry names how it was
established, so the next session can re-check it instead of trusting it.

Rules for *how to work* live in `AGENTS.md`; this file is only facts. Append
rather than rewrite, and delete an entry when it is disproven — a stale fact here
is worse than no fact, because it is trusted.

> **Naming note.** Claude Code also uses `MEMORY.md` as the index of its own
> machine-local auto memory, under `~/.claude/projects/<repo>/memory/`. That is a
> different file. This one is checked in, shared, and reaches an agent only
> because `CLAUDE.md` imports it by name.

## This marketplace

- The marketplace name is `kmdv181`, from `.claude-plugin/marketplace.json`. It is
  independent of the GitHub owner and the repo name, which happen to look similar.
  The repo has been renamed three times; the marketplace name never changed.
- `metadata.pluginRoot` plus a bare `"source": "<name>"` is documented but
  **rejected** by `claude plugin validate`. Use the full `"./plugins/<name>"` form.
- A plugin directory must not carry its own `marketplace.json` — only the repo
  root has one, or you register a redundant marketplace.
- Commands and skills share one namespace. `commands/x.md` and `skills/x/SKILL.md`
  both claim `/<plugin>:x`; the skill wins and the command is dead weight that
  still costs always-on tokens. `claude plugin details` shows it, validation
  doesn't.
- A private repo works fine as a marketplace. This one is public by choice, not
  necessity. Revisit that the moment anything personal lands here.

## Two CLIs, one manifest

- Codex discovers and installs plugins from `.claude-plugin/marketplace.json`. It
  needs no separate manifest. A `.codex-plugin/plugin.json` was added, then
  removed after a direct probe: deleting it from both the marketplace snapshot and
  the install cache, then running `codex exec`, still injected the rule. The real
  blocker had been **hook trust**, which the first attempt misdiagnosed.
- Claude Code reads `CLAUDE.md`, **not** `AGENTS.md`. The supported bridge is an
  `@AGENTS.md` import inside `CLAUDE.md`, which is what this repo does. Import
  parsing skips code spans, so a path in backticks stays literal.
- **The Codex half of that bridge is unverified.** `AGENTS.md` was written to the
  conventional path, but no probe confirmed Codex loads it: `codex exec` fails
  here before reaching a prompt — `gpt-5.6-sol`, `gpt-5.1-codex`, `gpt-5-codex`
  and `gpt-5.1` are all rejected as "not supported when using Codex with a
  ChatGPT account" (codex-cli 0.144.5). Re-run the probe on an account that can
  reach a model before trusting this path.
- A file in the repo root is not loaded just by existing. Only `CLAUDE.md`,
  `CLAUDE.local.md` and `.claude/rules/` load on their own; anything else reaches
  the agent through an `@` import. Verify with `/context` under **Memory files**.
- **Nested imports did not resolve here.** `CLAUDE.md` importing `AGENTS.md`,
  which imported `MEMORY.md`, loaded the first and silently dropped the second —
  measured with `claude -p`, which answered `NOT IN CONTEXT` for a fact only
  `MEMORY.md` carries. Docs promise four hops; this repo got one. Keep every
  import first-level, alone on its line, with no trailing punctuation, and
  re-probe after touching them.

## Ghostty's CLI

All established against **Ghostty 1.3.1 on macOS**, by running the binary and by
reading source pinned with `?ref=v1.3.1`. Anything here can change per version —
`plugins/ghostty-config/tests/contract.sh` re-checks it against whatever is
installed, and is the reason to trust or distrust this section.

- `+validate-config --config-file=<file>` on a **zero-byte** file exits 1 and
  prints nothing at all — same signature as a missing file. A single newline is
  the smallest file it accepts. This made a capability probe report the plugin's
  core guarantee as unavailable on a healthy install.
- `+show-config --no-pager` does not exist before 1.4. An unknown flag makes the
  whole action exit 1 with **empty stdout and empty stderr**, which is
  indistinguishable from "this user has customised nothing". Confirmed against
  `src/cli/show_config.zig`: the flag exists on `main`, not on `v1.3.1`.
- `+explain-config` does not exist before 1.4 either — `src/cli/explain_config.zig`
  is on `main` only. On an older build every invocation exits non-zero, so using
  its exit code as a per-key typo check marks *every* key as a typo.
- Absence from `+show-config --default` does **not** mean a key is invalid.
  `Config.zig:compatibility` keeps renamed options working, so a deprecated alias
  is missing from that list and still validates. `background-blur-radius` is the
  worked example: renamed to `background-blur` in 1.1, still accepted in 1.3.1.
  Distinguish the three cases by combining both commands — in the list, valid;
  not in the list but validates, deprecated alias; neither, a real typo.
- Config path selection mirrors `src/config/edit.zig:configPath()`: first
  candidate that exists and is non-empty, else the first that exists, else the
  first. On macOS the Application Support paths precede the XDG ones, and
  `config.ghostty` precedes the pre-1.3.0 name `config`.
- Relative `config-file =` includes resolve against the directory of the file
  containing them. That is why a candidate must be staged next to the real config
  and not in `/tmp`.
- A pager only spawns when stdout is a TTY (`src/cli/Pager.zig`), and an agent's
  stdout is a pipe. There is never a reason to reach for `--no-pager`.

## One root cause, four defects

`ghostty-config` shipped 0.1.4 with four defects that automated validation passed
clean. Every one was **knowledge baked into text and then going stale** against
the version actually installed: two invented CLI flags, one action that postdated
the user's build, and one rule that didn't know about the compatibility map.

Two things follow, and both are now load-bearing in this repo:

- Don't ship a catalogue of an external tool's options. `ghostty-config` documents
  *grammar and locations* and gets every key, theme, font and action name from the
  binary at runtime. A shipped key list would have rotted exactly the same way,
  only more quietly.
- Extract the commands a test sweeps from the documentation itself rather than
  listing them by hand, so a command written into a reference tomorrow is executed
  against the real binary tomorrow. Distinguish *action absent on this build*
  (fine, probe for it) from *action present and called wrongly* (a defect).
