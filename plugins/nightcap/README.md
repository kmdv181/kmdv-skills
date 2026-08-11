# nightcap

A memory checkpoint an agent can call on itself, for repositories tracked with
[beads](https://github.com/gastownhall/beads).

```
nightcap
```

What an agent knows at the end of a session does not survive it. Not the
decision settled two hours ago, not the correction you made to its approach, not
the reason the obvious thing was wrong here. A nightcap is the agent choosing
what of that was worth keeping — and keeping it, in `bd`, before the boundary
takes it.

**The choosing is the point.** The skill says where to put things; it does not
try to tell the agent what to value, because nothing but that session was there.

## Requires beads

```sh
command -v bd && bd ready
```

`bd` on `PATH` and a beads workspace in the repository. Without both, the skill
says so and stops — it will not write a Markdown file instead. A substitute
nobody reads is worse than an honest refusal, and it lets an agent report
success it did not achieve.

Install:

```sh
/plugin marketplace add kmdv181/skills
/plugin install nightcap@kmdv181
```

## What it does

| Move | What happens |
|---|---|
| The cut | Keeps the hearts — settled decisions, your corrections, the reason an approach that looks right is wrong here — as `bd remember` keys. Discards chatter and dead ends deliberately. |
| Seal | Overwrites one key, `<name>/nightcap`: the date, the state of play, and the agent's last proposal **quoted verbatim**. |
| In flight | *Only if there is any.* Claimed issues get closed with a reason, or a note with the exact stopping point. Not a checklist item — a session that touches no issue is fine. |
| Sync | `bd dolt push`, last, after everything else is written. Git stays report-only. |

## Why the last proposal is quoted, not summarised

A session almost always ends with the agent proposing something and waiting. The
seal keeps that sentence **verbatim**, because the user's next message is often
the answer to it — "yes, go ahead" — a pointer whose referent died with the
context. With the exact words sealed, that resolves. Without them the agent
reconstructs what it must have offered, and acts on the reconstruction.

The state of play records where the work is. The quoted proposal records what
the agent *wanted*, which is the part that survives nowhere else.

The reading half needs no setup: `bd init` installs a `bd prime --hook-json`
SessionStart hook into `.claude/settings.json`, so the seal is already in context
when the next session opens. This plugin ships no hook of its own — beads
already put one there.

## It runs on its own judgment

The trigger is not only the word. The skill's first listed reason to run is *you
are holding something worth keeping and have no guarantee you will still have it
in an hour* — so the agent nightcaps when context is about to compact, or when a
session has gone long, without being asked.

Running it twice in a day is normal. The seal is one key, always overwritten, so
a second nightcap replaces the first rather than piling up beside it.

## No quality gates

It does not run your tests or linters first. Gates are not memory, they need no
judgment, and a heavyweight blocking step at the front is exactly what stops a
checkpoint being cheap enough to run whenever it is worth running. `bd` has its
own session-close protocol if that is what you want.

## Why `bd note` and never `bd update --notes`

`--notes` **replaces** the notes field. Used for a handoff, it deletes the
stopping point an earlier session left there — precisely the information the
next session came for — and the transcript shows nothing wrong. `bd note`
appends.

## Why keys are namespaced

Memory keys are `<name>/<topic>` so several agents can share one store without
overwriting each other. `<name>` is the identity the session was launched under,
or else the actor bd itself resolves (`$BEADS_ACTOR`, git `user.name`, `$USER`).

## No `allowed-tools`

Deliberate. The skill has to be able to reach whatever `bd` invocation the
situation calls for, and a tool allowlist written today would quietly narrow
that later. The failure mode of getting it wrong is an agent that reports a
clean checkpoint because it could not run anything.

## Testing

```sh
sh plugins/nightcap/tests/run.sh
```

Every `bd` command and flag in the suite is **extracted from `SKILL.md` itself**
and probed against your installed binary, so the skill is checked against the bd
you actually have rather than the one it was written for. It also asserts the
behaviours the skill's advice depends on. No `bd`? The tier skips loudly and says
nothing was verified.

What it cannot check is the judgment the skill actually asks for. `tests/MANUAL.md`
is the hand-run session that covers it — start there before trusting a green run.
