# Manual acceptance test — nightcap

`tests/run.sh` proves that every `bd` command and flag written into SKILL.md
exists on the installed binary, and that the behaviours the skill argues from
are real. It proves nothing about whether the protocol is any good.

This plugin ships **only prose**. There is no script between the skill and your
tracker: the agent reads the instructions and runs `bd` itself. And the thing
this skill asks of the agent is a *judgment* — which parts of a session were
worth keeping — which is the one thing a shell test structurally cannot check.
So the checks below are mostly about taste, and you are the assertion.

Budget ~15 minutes. It runs entirely in a scratch repository; your real store is
never touched.

---

## Setup — a throwaway store

```sh
export LAB=$(mktemp -d)/lab
mkdir -p "$LAB" && cd "$LAB"
git init -q . && git config user.email you@example.com && git config user.name tester
bd init
bd create "Wire up the export path" -p 1
```

Claim it and leave a note, so there is prior state something could destroy:

```sh
bd update <id> --claim
bd note <id> "started: sketched the interface"
```

Now start an agent session **in `$LAB`** with the plugin installed and give it
some substance to distil: ask it to do a small piece of work, **correct it once
on something it got wrong**, and leave a thread visibly unfinished. The
correction is the important part — it is the clearest example of a heart, and
whether it survives is check 4.

Then say: **"nightcap"**.

---

## What to check, in order

### 1. It refuses rather than improvises

First the negative case, because it matters most:

```sh
cd $(mktemp -d) && git init -q .     # no bd workspace here
```

Say "nightcap" in a session started there.

- [ ] The agent **says it cannot run** and stops.
- [ ] It does **not** invent a substitute — no `HANDOFF.md`, no TODO list, no
      "I'll keep this in mind".

An agent that writes a Markdown handoff when the store is missing has produced
something nobody will ever read, while reporting success.

### 2. It picks one name and keeps it

- [ ] It states the name it is writing under, and where that name came from.
- [ ] Every key it writes starts with that same `<name>/`.

### 3. The cut is a choice, not a transcript

This is the skill's whole reason to exist, and the only check here that needs
you to think.

```sh
bd memories
```

- [ ] The correction you made in setup **is** there.
- [ ] Things that are not there: chatter, the dead ends, detail that only
      mattered once. If nearly everything from the session became a memory, the
      agent transcribed instead of choosing, and the store is now worse than
      empty.
- [ ] Nothing it saved is already better recorded by the code, the tests or
      `git log`.
- [ ] Read each memory cold. Would it help someone who was not in this session?
      A memory that only makes sense to a reader who already knows is a heart
      that was cut badly.

### 4. The seal is one glass

Before saying "nightcap", make sure the session ended the way sessions actually
end: let the agent **propose something and wait** — an offer, a question, a "say
X and I'll do Y". Do not answer it. That pending proposal is what check 4b is
about.

```sh
bd recall <name>/nightcap
```

- [ ] It has a date, where things stand, and a concrete first move.
- [ ] The first move is a *move*, not a topic.

**4b — the proposal is quoted, not summarised.**

- [ ] The agent's last proposal is in the seal **in the words it used**. Compare
      against the transcript: "offered to ship it" is a fail, the actual
      sentence is a pass.
- [ ] It says what it was waiting for, and what an answer would mean.

- [ ] If the session was held in a language other than English, the offer is
      sealed **in that language**, not translated. It is a quotation; translating
      it is a summary wearing quotation marks.

Now the test that gives this its point. Start a fresh session in `$LAB` and reply
with nothing but a bare confirmation — **"yes, go ahead"** and nothing else.

- [ ] The agent reads the seal *before* answering, and resolves what the
      confirmation refers to.
- [ ] It acts on the actual proposal — not on a plausible reconstruction of it.

A wrong guess here is not a hedge, it is an action. This is the check most worth
running twice.

Now say "nightcap" a second time in the same session.

```sh
bd memories | grep nightcap
```

- [ ] Still exactly **one** key. It was overwritten, not duplicated.

### 5. Work in flight, if there was any

Only applies if the agent had claimed work. From the ledger, not the transcript:

```sh
bd show <id>
```

- [ ] Your earlier note (`started: sketched the interface`) is **still there**.

If it is gone, the agent used `bd update --notes`, which replaces the field. It
destroyed a previous session's stopping point and nothing in the transcript
shows it.

- [ ] The new note names an exact stopping point and a literal next command.
- [ ] If there was no claimed work, the agent **skipped this silently** rather
      than inventing ledger activity to look thorough.

### 6. Sync last

- [ ] `bd dolt push` ran **after** the memories and any notes were written — not
      before. A push that runs first leaves the actual work on this machine.
- [ ] A scratch repo has no Dolt remote, so expect a failure. The agent should
      report the exact command and error, and not treat it as fatal.
- [ ] It did **not** commit and did **not** push git without you asking.

### 7. It runs on its own judgment

The skill claims the agent will nightcap unprompted when it is holding something
it might lose. Test it without saying the word:

- [ ] In a long session, or one approaching compaction, the agent proposes or
      runs a nightcap by itself.

The failure mode in the other direction is worth watching for too:

- [ ] It does **not** fire on every trivial exchange. A skill that nightcaps
      after two turns is noise, and its store fills with nothing.

### 8. Wake

Start a fresh session in `$LAB` and ask "what were we doing?".

- [ ] It reaches the handoff by key — `bd recall <name>/nightcap` — rather than
      searching with `bd memories`.

Then make the ledger newer than the seal and try again:

```sh
bd note <id> "someone else moved this after the nightcap"
```

- [ ] The agent treats the ledger as authoritative and the seal as history,
      instead of following a plan that has been overtaken.

---

## Cleanup

```sh
cd "$LAB" && bd dolt stop
rm -rf "$(dirname "$LAB")"
```

---

## Record the run

A hand-run test nobody wrote down is a rumour. When you finish, note in the
commit message or in this repo's `MEMORY.md`: the date, `bd version`, the
harness, and every box that did **not** get ticked.

An unticked box is not a failure of the run — it is the finding, and it is the
whole return on doing this by hand.
