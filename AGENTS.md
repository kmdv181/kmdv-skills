# Working in this repository

These are the working rules, kept harness-neutral so any coding agent can follow
them. Claude Code reads them through `CLAUDE.md`, which imports this file; Codex
and anything else that honours the `AGENTS.md` convention reads it directly.

Facts already paid for — Ghostty's CLI, this marketplace's quirks, defects that
have shipped and why — live in `MEMORY.md`. Read it before assuming anything
about either; it exists so you don't re-derive what someone already bled for.

## Find your feedback loop before you build

Your first move on any new feature or change is not to plan it and not to write
it. It is to work out **how you would observe whether it worked** — some check
that comes out differently when the change is broken than when it is correct.

This is a search, not a checklist. Ask what in this environment could contradict
you: a command whose output you can read, a file whose contents you can diff, a
stub you can drive, an inventory you can list, a source you can fetch. The
examples below are starting points from past work, not the set of legal answers —
the loop for your change may be one nobody has used here yet, and finding it is
the job.

If you search and find nothing:

1. Say so plainly, before starting. Name what you tried to use as a loop and why
   it doesn't close.
2. Offer concrete options for building one — a fixture, a stub, a probe script, a
   throwaway harness.
3. Wait. Building without a feedback loop needs the user's explicit go-ahead, and
   when you get it, the final report must say which claims went unverified.

**Why this is a hard rule:** an agent working without a feedback loop degrades
badly and quietly. It cannot tell a correct change from a plausible one, so it
optimises for looking finished. Everything it reports is then a claim about its
own intentions rather than about the code. The loop is what makes the work
falsifiable — and falsifiable is the whole difference.

### Loops that have paid off here

| What changed | What actually caught problems |
|---|---|
| Manifests, frontmatter | `claude plugin validate . --strict`, and again per plugin directory — the per-directory run is the one that reads skill and command YAML |
| Anything shipped to users | `claude plugin marketplace add kmdv181/skills` → `install` → `claude plugin details <plugin>@kmdv181`. The component inventory caught a duplicate skill/command name that validation passes clean. |
| Shell scripts | Three tiers, not one — see below. `plugins/ghostty-config/tests/` is the worked example. |
| Anything an agent reads and acts on | A hand-run session against the real thing. `plugins/ghostty-config/tests/MANUAL.md` — the automated suite passes on prose that instructs the agent to do the wrong thing. |
| Claims about an upstream tool | `gh api repos/<org>/<repo>/contents/<path>`, pinned with `?ref=<tag>` to the version actually installed. Reading `Config.zig` corrected a config load order a docs summary had backwards, and `@?ref=v1.3.1` settled which CLI flags existed in the user's build. |

### Three tiers, because one tier always lies

Shell scripts that drive an external binary need all three. Each catches a class
the others structurally cannot:

- **Hermetic** — stub binary, fixture tree. Proves the script's *logic*. Runs
  anywhere, deterministic, never touches real state. Cannot prove the script
  works.
- **Contract** — the real binary, one command at a time. Proves the *facts the
  script relies on*: which flags exist, which exit code means what. Catches the
  code drifting away from the user's installed version. Never runs the script.
- **End-to-end** — the real binary driving the script against a fixture. Proves
  the two meet: that what the script writes is what the binary then accepts.
  It is also the only place the stub can be checked for honesty, because both
  binaries are in reach at once.

A missing real binary must make the last two **skip loudly**, never pass. A
skipped tier that reads as green is how this repo shipped four defects at once.

### What is not a loop

- Re-reading the diff you just wrote.
- A green validator when the question is behavioural. Schema-valid and working
  are different claims; this repo has already shipped a defect that was one and
  not the other.
- A stub you wrote to match your own assumption. It agrees with you by
  construction. Assert it against the real binary, in the same run.
- A test that greps the source of the thing it is testing. Reformat that source
  and the check silently passes. Assert behaviour, hardcode the expected input.
- The user noticing later.

## `marketplace.json` is shared; plugin directories are not

Each plugin is one person's or one session's territory. `.claude-plugin/marketplace.json`
is the only file everyone edits, so touch **only your own plugin's entry** in it —
never reformat, reorder or rewrite the whole file, or you will silently revert
work in flight elsewhere. Whoever builds a plugin adds its entry.

Don't validate, version or "tidy" a plugin you didn't write. If something in one
looks broken, say so; don't fix it.

## Stage explicitly. Never `git add -A`

List the paths you changed. This repository gets worked on from more than one
session at a time, and `git add -A` has already swept an entire unrelated plugin —
ten files — into a commit whose message described something else, and pushed it
public. Before committing, run `git status` and account for every line: if you
cannot say why a path is there, it is not yours to commit.

Then check that the staging worked. `git add` is **atomic**: one unmatched
pathspec — a directory you already removed, a typo — aborts the entire invocation
and stages *nothing*, while the shell carries on to your `git commit`. That has
already pushed a tree here with a file deleted and its replacement missing. Run
`git diff --cached --name-status` and confirm it lists what you expect before
committing.

## Shipping a change to an installed plugin

An installed plugin is cached at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>`,
keyed by **version string**. `claude plugin update` compares that string, not the
commit — so pushing to `main` without a version bump reaches nobody. It reports
"already at the latest version" while serving stale files.

So for any change that should reach a user:

1. Bump the patch version in **both** `plugins/<name>/.claude-plugin/plugin.json`
   and that plugin's entry in `.claude-plugin/marketplace.json`.
2. `claude plugin tag ./plugins/<name>` — validates that the two agree and creates
   the release tag. `claude plugin validate --strict` does **not** catch this
   mismatch, despite the docs saying it warns.
3. Push, then `claude plugin marketplace update <marketplace>` and
   `claude plugin update <plugin>@<marketplace>`.
4. Confirm with `claude plugin details` that the inventory changed. If it didn't,
   the change did not ship, whatever the commands reported.

Never leave a fix sitting unbumped in the tree — an unreleased fix reaches nobody
and reads, to the next session, as a problem already solved.

The `claude` CLI is the release tool regardless of which agent is doing the work;
these steps are facts about this repository, not about a particular harness.

## Anything that leaves this conversation is English

The rule itself lives in `plugins/always-english-artifacts/rules/artifact-language.md`
and is deliberately not restated here — one copy. Read it there. It already names
commit messages, branch names, and **PR titles and bodies** among the things it
covers, so nothing below is a new requirement. What follows is the part this
repository got wrong anyway.

**Quoted evidence is not exempt.** A pull request here shipped with Russian
strings in its body because the probes that produced them ran in Russian, and
measured output felt like *data* rather than prose. It is prose the moment it
lands in a PR, a commit message or a `MEMORY.md` entry, and a reader who does not
speak the language now cannot check your evidence — which is the entire reason
this repository writes evidence down. Translate it, or state the finding instead:
*"the seal kept the offer in the language it was made in"* carries the same
result and survives every reader.

The one place another language belongs in a file that ships is where it is
**functional** — a trigger word in a skill's `description`, a test input chosen
precisely because a non-English request is what's under test. That is user-facing
copy for readers of that language, which the rule already allows. Prose *about*
the work never is.

When talking to the user, follow their language. That is conversation, not an
artifact.

## When you learn something the hard way

Add it to `MEMORY.md`, in the section it belongs to, as one entry that names the
evidence — the command, the source file, the version. A lesson nobody can check
later is a rumour. If the lesson is a rule rather than a fact, it belongs here in
`AGENTS.md` instead.
