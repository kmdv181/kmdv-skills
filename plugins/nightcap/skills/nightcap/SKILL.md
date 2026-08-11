---
name: nightcap
description: Decide what this session is worth remembering and write it down before it is lost — distil the session into persistent beads memory and seal one key holding the state of play and the next move. Use when the user says "nightcap", "отбой", or is wrapping up; when context compaction is near; or whenever you are holding something worth keeping and have no guarantee you will still have it later.
---

# Nightcap

What you know right now does not survive this session. Not the decision you
settled two hours ago, not the correction the user made to your approach, not
the reason the obvious thing turned out to be wrong. By tomorrow it is gone
unless you wrote it down.

A nightcap is you choosing what of it was worth keeping, and keeping it.

**The choosing is the point.** No checklist can tell you which parts of your own
session mattered — you were there and nothing else was. What follows is where to
put things, not what to value.

## Requires beads

Memory here is the beads store, so every move is a `bd` command. Before
starting, confirm both halves:

```sh
command -v bd && bd ready >/dev/null
```

`bd ready` exits 1 with `no beads database found` when the directory has no
beads workspace. If either check fails, **say so and stop.** Do not improvise a
substitute — a Markdown file written instead of a memory is a note nobody will
ever read, and writing one lets you report success you did not achieve.

## When to run

- **You are holding something worth keeping and have no guarantee you will
  still have it in an hour.** That is the whole trigger. You decide, and nobody
  has to ask you.
- Context compaction is near. Don't wait to be told: if the session has grown
  long or the harness warns about the boundary, run it yourself before it hits.
- The user says "nightcap", "отбой", or is otherwise wrapping up the day.

Running it more than once in a day is normal, not a mistake. The seal is a
single key that is always overwritten, so a second nightcap replaces the first
rather than piling up beside it. Mid-afternoon is a fine time for one.

Who runs it: any agent facing a boundary that has a tomorrow — a next session,
or a post-compaction continuation of this one. A bounded subagent finishing its
task does not nightcap; its report is its handoff.

## Step 0 — the name you write under

Memory keys are namespaced `<name>/<topic>`, so several agents can share one
store without overwriting each other. Slashes are legal in a bd memory key.

Pick `<name>` once and use it for every key you write this session:

- The identity you were launched under, if the session named one.
- Otherwise the actor bd itself would record: `$BEADS_ACTOR`, else git
  `user.name`, else `$USER`.

Your handoff key is `<name>/nightcap`.

## 1. The cut

Distil the session like a spirit run: keep the hearts, discard heads and tails.

**Hearts** — what you would be worse off not knowing tomorrow:

```sh
bd remember "..." --key <name>/<topic>
```

A repeated `--key` updates that memory in place, so sharpen the existing topic
rather than accumulating near-duplicates beside it. Facts that belong to
everyone working here — domain knowledge, tracker policy, how this project is
built — go to a shared key with no `<name>/` prefix.

What tends to be hearts: a decision that is settled and should not be reopened;
a correction the user made to how you work; the reason an approach that looks
right is wrong here; a mechanism worth reusing. What tends not to be: anything
the code, the tests or `git log` already say better than you can.

```sh
bd forget <key>
```

for anything that went stale. A wrong memory is worse than a missing one,
because it is trusted.

**Heads and tails** — chatter, dead ends, one-off detail — are discarded
deliberately. Choosing not to write something down is a decision, and a session
that saved everything did not make it.

## 2. Barrel seal

Overwrite your single key with the handoff:

```sh
bd remember "<date> — <state of play> — <what you last proposed, verbatim>" --key <name>/nightcap
```

The date, one paragraph on where things stand, and the next move. Always the
same key: the nightcap is a glass, not a diary.

### Quote your last proposal word for word

Sessions usually end with you proposing something — an offer, a question, a
"say X and I'll do Y". That proposal is the next move, and it goes into the seal
**in the words you actually used**, not as a description of it.

Two reasons, and the second is the one that bites:

- A summary drifts. *"Offered to ship it"* and *"Say «ship it» and I'll tag,
  push, then confirm with `plugin details`"* are not the same thing, and only
  the second still means something read cold tomorrow.
- **The user's next message may be the answer to it.** They come back and say
  "yes, go ahead" — a pointer with no referent, because the thing it pointed at
  lived in a context that no longer exists. With your own words in the seal,
  "go ahead" resolves to a specific action. Without them you have to guess what
  you offered, and a wrong guess here is confident and immediate: you act on it.

So quote yourself; don't paraphrase yourself. If you were waiting on an answer,
say what you were waiting for and what each answer would mean.

This is also what makes the seal *yours* rather than a status report. The state
of play says where the work is. Your last proposal says what you wanted — and
intent is the part that does not survive anywhere else.

## If you have work in flight

Only if you do. This is not a checklist item and there is nothing wrong with a
session that touches no issue.

But a claimed issue you leave silently is a thing you knew and didn't save, same
as any other:

```sh
bd close <id> --reason "..."       # finished
bd note <id> "..."                 # still open: where you stopped
```

On open work, record the exact stopping point and the literal next command.
"Continue the refactor" is not a handoff.

**Never `bd update --notes` for this.** `--notes` *replaces* the notes field, so
it silently deletes the stopping point an earlier session left there — the exact
information the next one came for, and nothing in the transcript will show it
happened. `bd note` appends, which is what a handoff needs.

## Last, always — sync

```sh
bd dolt push
```

Memory that doesn't survive the machine isn't memory. Do this after everything
above, or what you just wrote stays here. A failure doesn't block sleep, but the
exact command and its error go into your report.

**Git stays report-only.** Run `git status`, propose the commands — no commits
and no pushes without the user asking for them in this session.

## Wake — the counterpart

- **Usually your memories are already in context.** `bd init` installs a
  SessionStart hook (`bd prime --hook-json`) into `.claude/settings.json`, so in
  a standard beads repository the seal is loaded before you read the user's
  first word. Look there before running anything.
- If it isn't — no hook, or a harness that doesn't run one — fetch it by key:

  ```sh
  bd recall <name>/nightcap
  ```

  `bd recall <key>` is the exact-key lookup. `bd memories [search]` lists and
  searches — it is for finding a key you have forgotten, not for reading one you
  know.

**Read the seal before you answer, not after.** If the user opens with a bare
"yes", "go ahead" or "do it", that is an answer to the proposal you sealed last
night, and the seal is the only place the question still exists. Resolve the
pointer first; acting on a guess about what you offered is the failure this
whole move exists to prevent.

**The ledger beats the nightcap.** If beads shows activity newer than the date
in your seal, that seal is history rather than a plan — someone worked after you
wrote it. Build from `bd ready` and the issues' own notes, and treat the
nightcap as background.
