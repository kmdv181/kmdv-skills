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
- **Codex loads the working directory's `AGENTS.md` into context on its own.**
  Measured on codex-cli 0.147.0, with this repo `trust_level = "trusted"` in
  `~/.codex/config.toml`. (A global `~/.codex/AGENTS.md` also exists on this
  machine; whether and how it merges was not probed.) A `codex exec --json` run
  that forbade tool use
  answered `TIERS=Hermetic,Contract,End-to-end` — a fact only `AGENTS.md`
  carries — and emitted no tool call at all; the same prompt run with `-C` on an
  empty directory answered `NONE`. That negative control is what makes the
  result mean *loaded into context* rather than *found by grep*.
- **Codex does not resolve `@` imports.** Same probe, a scratch `AGENTS.md`
  carrying one canary plus an `@FACTS.md` line, and `FACTS.md` carrying another:
  the first came back, the second came back `NONE`. So `MEMORY.md` cannot be
  bridged to Codex by importing it — under Codex the facts file is out of
  context, and the probe confirmed that directly (`RENAMES=NONE`, a fact only
  `MEMORY.md` carries).
- **The pointer in `AGENTS.md` is what puts this file in front of Codex.** Its
  opening paragraph names `MEMORY.md` and says to read it. Given a task-shaped
  question about `+show-config --no-pager`, Codex's *first* command was
  `sed -n '1,240p' MEMORY.md` in **3 of 3** runs. Against a copy of the repo
  with only that paragraph deleted, **0 of 2** — one never opened the file, the
  other reached it at command two, inside a grep across the whole plugin. So
  keep that sentence; it is load-bearing, not decorative. (The control copy
  still mentions `MEMORY.md` once, under *When you learn something the hard
  way*, which tells the agent to **write** to it. Removing the read instruction
  alone was the point.)
- **But the pointer is not what made the answer right, and don't overread it.**
  All 5 runs above answered correctly, pointer or not: this particular fact is
  also in `plugins/ghostty-config/tests/`, and the pointerless runs went and
  measured the installed binary directly. What the probe shows is *which file
  Codex opens first*, not that facts here are unreachable without it. A fact
  that exists **only** in this file, with no test and no binary to interrogate,
  was never tested — and that is exactly the fact the pointer would be
  protecting. Small denominators; re-run before leaning harder on this.
- In Claude Code, a file in the repo root is not loaded just by existing. Only
  `CLAUDE.md`, `CLAUDE.local.md` and `.claude/rules/` load on their own; anything
  else reaches the agent through an `@` import. Verify with `/context` under
  **Memory files**. Codex is the other way round — see the first bullets above.
- **Nested imports did not resolve here.** `CLAUDE.md` importing `AGENTS.md`,
  which imported `MEMORY.md`, loaded the first and silently dropped the second —
  measured with `claude -p`, which answered `NOT IN CONTEXT` for a fact only
  `MEMORY.md` carries. Docs promise four hops; this repo got one. Keep every
  import first-level, alone on its line, with no trailing punctuation, and
  re-probe after touching them.

## Picking up after a session ends

A session's reasoning does not survive it. What survives is what got written
down, so this is the order to reach for, strongest first.

- **The repo loads itself.** In a session started here, `CLAUDE.md` is read
  automatically and pulls in `AGENTS.md` and `MEMORY.md`. Measured, not assumed:
  a `claude -p` asking for a fact only `MEMORY.md` carries answered from context
  with no file reads. Nothing else needs doing — start a session and the rules
  and facts are already there.
- **The tests re-establish ground truth in seconds.** `sh plugins/ghostty-config/tests/run.sh`
  drives all three tiers against the real binary and the installed copy. Trust it
  over any recollection, including this file's.
- **`git log` is the archive of *why*.** Commit messages here deliberately carry
  the reasoning and the evidence, not a summary of the diff. `git log -p
  plugins/ghostty-config` reads as a post-mortem of every defect found.
- **The literal conversation is on disk**, per session, at
  `~/.claude/projects/<slugified-repo-path>/<session-id>.jsonl`. Reopen it with
  `claude --continue`, or `claude --resume <id>`, or `--resume <id> --fork-session`
  to branch without touching the original. Machine-local, never in git, and large
  — a long session runs to megabytes and will be partly compacted on reload.
- **Auto memory has been empty here.** As of 2026-08-09 the project directory
  above contained transcripts and no `memory/` subdirectory at all, so Claude
  Code had written itself nothing across several sessions. Don't rely on it as a
  continuity mechanism; write to this file instead.

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

## POSIX shell

- **A leading zero makes `$(( ))` read octal.** `$((010 + 1))` is 9, not 11, and
  `$((08 + 1))` is a *fatal* `value too great for base` that kills the script
  where it stands. Both reached `ghostty-apply.sh` through `GHOSTTY_BACKUP_KEEP`:
  `010` silently meant 8, and `08` aborted the apply after the backup and before
  the move, so the config never changed and the failure looked like nothing
  happening. `10#` forces decimal in bash but is not POSIX — strip leading zeros
  with `sed 's/^0*//'` before any arithmetic, and treat the all-zeros result as 0.
- A `case` guard of `''|*[!0-9]*` does **not** catch `00`: it is all digits, and
  it is not the literal `0` a following branch matches. It fell through to
  `tail -n +1` and deleted an entire backup ring, including the backup taken
  seconds earlier, while the command reported success. Normalise the value once,
  up front, instead of enumerating spellings in a `case`.
- Sort backup filenames under `LC_ALL=C`. Locale collation ignores punctuation
  and reordered timestamp-plus-counter names, which made "oldest" resolve to the
  newest entry and pruned the wrong end.

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

## Known gaps, as of 2026-08-09

Facts about what has *not* been checked. Delete an entry when it stops being
true — an unfinished thread left here after it closes is as misleading as a
stale fact.

- **No automated test reads the skills' prose.** Both tiers pass on instructions
  that tell an agent to do the wrong thing; that is exactly how 0.1.5 shipped.
  `plugins/ghostty-config/tests/MANUAL.md` Part B covers it by hand and has been
  run once, by a person. The way to automate it is a skill eval — the
  `skill-creator` skill runs evals and measures variance across repeats — which
  nobody has built here. It is the largest open piece of work on this plugin.
- **One Ghostty build.** Everything is measured against 1.3.1 on macOS. The 1.4+
  branch of the edit skill's Step 2 is derived from Ghostty's source and has
  never been executed.
- **No Linux, and no machine without Ghostty.** The Linux config-path branch is
  exercised only through a fake `uname` in the hermetic tier. The `exit 2` refusal
  and `--no-validate` paths cannot be reached on a machine that has Ghostty,
  because `find_bin` searches `/Applications/Ghostty.app` by absolute path — the
  hermetic tier skips them out loud rather than pretending.
