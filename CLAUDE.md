# Working in this repository

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
| Shell scripts | Fixtures plus a stub binary. `ghostty-config` is tested with a fake `ghostty`, a fixture config tree, and a fake `uname` for the macOS branch. Assert exit codes and file contents. |
| Claims about Ghostty | `gh api repos/ghostty-org/ghostty/contents/<path>`. Reading `Config.zig` corrected a config load order that a docs summary had backwards. |

### What is not a loop

- Re-reading the diff you just wrote.
- A green validator when the question is behavioural. Schema-valid and working
  are different claims; this repo has already shipped a defect that was one and
  not the other.
- A stub you wrote to match your own assumption. Check the stub against the real
  thing first — a stub encoding your mistake will agree with you every time.
- The user noticing later.

## Facts worth not re-deriving

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
