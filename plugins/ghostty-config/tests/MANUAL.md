# Manual acceptance test — ghostty-config

`tests/run.sh` checks the scripts. It cannot check the part that actually
decides what gets written to your config: **the agent reading SKILL.md**. That
gap is real and it has already shipped a defect — 0.1.5 passed every automated
test while telling the agent to treat every valid config key as a typo.

This is the test for that gap. You run it by hand, and you are the assertion.

- **Part A** — the scripts, against a scratch config. ~5 minutes, zero risk.
  **This part is now automated** as `tests/e2e.sh`, which drives the same flow
  with the real binary and asserts more than a person reasonably can. Run
  `sh tests/run.sh` instead — and keep Part A for when you want to watch it
  happen rather than take a test's word for it.
- **Part B** — the agent, in a real Claude session. ~10 minutes. **This is the
  part that cannot be automated here**, and the only reason this file exists: no
  shell test can read SKILL.md and decide what to write to your config.
- **Part C** — clean up.

Recorded against **Ghostty 1.3.1 on macOS**. Check yours first, because most of
what follows is version-specific to Ghostty:

```sh
/Applications/Ghostty.app/Contents/MacOS/ghostty +version | head -1
claude plugin details ghostty-config@kmdv181 | head -1
```

This file ships inside the plugin, so its own version is whichever one you
installed — the second command tells you, and stating it here would only be one
more number to leave behind on the next release.

If your Ghostty is 1.4 or newer, expect three documented differences: A1 reports
`explain_config: true`, B2 takes the `+explain-config` branch instead of the
`+show-config` one, and A7's first command stops failing. Everything else holds.

---

## Part A — the scripts

Nothing here touches your real config or your real backups: every command passes
`--config` explicitly and `XDG_STATE_HOME` is redirected into the lab directory.
That isolation is the whole reason Part A is safe to run on your daily machine.

### Setup

```sh
export LAB=$(mktemp -d)
export XDG_STATE_HOME="$LAB/state"
export P=$(ls -d ~/.claude/plugins/cache/kmdv181/ghostty-config/*/ | sort -V | tail -1)
printf 'font-family = Menlo\nfont-size = 13\n' > "$LAB/config.ghostty"
echo "testing: $P"
```

Run everything below in that same shell — the exports are load-bearing. `$P`
resolves to the newest installed version rather than a number written here,
which would go stale on the next release; check the `testing:` line names the
version you meant.

### A1 — the probe reports the truth about your install

```sh
sh "$P/scripts/ghostty-env.sh" | sed -n '/capabilities/,$p'
```

**Expected on 1.3.1:**

```
  "capabilities": {
    "validate_config": true,
    "show_config": true,
    "explain_config": false,
    "list_themes": true,
    "list_keybinds": true
  }
}
```

☐ `validate_config` is **true**.

This is the single most important line in Part A. It is the plugin's core safety
guarantee reporting on itself, and until 0.1.5 it said `false` on a perfectly
healthy install — because the probe validated a zero-byte file, which Ghostty
rejects. `explain_config: false` is **correct** on 1.3.1: that action genuinely
doesn't exist yet.

### A2 — a dry run shows the change without making it

```sh
printf 'font-family = Menlo\nfont-size = 16\n' > "$LAB/cand"
sh "$P/scripts/ghostty-apply.sh" --new "$LAB/cand" --config "$LAB/config.ghostty" --dry-run
grep font-size "$LAB/config.ghostty"
```

**Expected:** `Validation passed (ghostty).`, a unified diff showing
`-font-size = 13` / `+font-size = 16`, then `Dry run: nothing was written.`

☐ The diff is shown and `grep` still prints **`font-size = 13`**.

### A3 — an invalid key cannot reach the config

```sh
printf 'font-family = Menlo\nfont-sizee = 16\n' > "$LAB/bad"
sh "$P/scripts/ghostty-apply.sh" --new "$LAB/bad" --config "$LAB/config.ghostty"
echo "exit=$?"
grep font-size "$LAB/config.ghostty"
```

**Expected:**

```
Validation FAILED. The existing config was not modified.

<LAB>/config.ghostty:2:font-sizee: unknown field
exit=1
font-size = 13
```

☐ Exit is **1**, the config still says 13, and the diagnostic names
**`config.ghostty`** — not `config.ghostty.ghostty-plugin-candidate`.

That last detail matters: validation runs against a staging file, and the script
rewrites the path so the error names the file you recognise.

### A4 — applying for real takes a backup first

```sh
sh "$P/scripts/ghostty-apply.sh" --new "$LAB/cand" --config "$LAB/config.ghostty" | tail -3
```

**Expected:** `Backed up to: …/backups/<timestamp>.01-config.ghostty`,
`Wrote: …`, and the reload hint.

☐ Both a `Backed up to:` and a `Wrote:` line appear.

### A5 — undo refuses to choose for you

```sh
sh "$P/scripts/ghostty-undo.sh" --list
sh "$P/scripts/ghostty-undo.sh" --restore; echo "exit=$?"
```

**Expected:** a numbered list with a readable timestamp and a `→` line naming
the config the backup belongs to; then `ghostty-undo: no target given` and
`exit=2`, with the list printed again.

☐ `--restore` with no argument **refuses** (exit 2) rather than guessing.

This is deliberate. Every restore is itself an apply and takes its own backup,
so after one undo the newest entry is the state you just undid — a silent
"restore the newest" would toggle between two states while looking like it walks
back through history.

```sh
sh "$P/scripts/ghostty-undo.sh" --restore 1 >/dev/null
grep font-size "$LAB/config.ghostty"
```

☐ Prints **`font-size = 13`** — the change is rolled back.

### A6 — clearing the config is not a dead end

```sh
: > "$LAB/empty"
sh "$P/scripts/ghostty-apply.sh" --new "$LAB/empty" --config "$LAB/config.ghostty" | tail -2
wc -c < "$LAB/config.ghostty"
```

☐ It succeeds, and the result is **1** byte, not 0.

Ghostty rejects a zero-byte config file (silently, with no diagnostic), so
"strip my config back to defaults" used to fail as an unexplained validation
error. A lone newline is the smallest file the binary accepts and means the same
thing.

### A7 — see the bugs for yourself

Optional, but this is the part that makes the rest concrete. These are the exact
commands the plugin used to run, against your own binary:

```sh
G=/Applications/Ghostty.app/Contents/MacOS/ghostty
"$G" +show-config --no-pager; echo "exit=$? — and how many bytes did it print?"
E=$(mktemp -d); : > "$E/empty"
"$G" +validate-config --config-file="$E/empty"; echo "exit=$?"
"$G" +explain-config --option=font-size >/dev/null 2>&1; echo "exit=$?"
```

☐ All three exit **1**, and the first two print **nothing at all**.

That silence is the whole problem. A rejected flag is indistinguishable from an
empty result, so `+show-config --no-pager` didn't look like a broken command —
it looked like a user who had customised nothing. And since `+explain-config`
exits non-zero for *every* key on this build, using it as a typo check marked
every valid key as a typo.

---

## Part B — the agent

Part A proves the scripts are sound. It says nothing about whether the agent
uses them correctly, which is where the defects actually lived.

Open a **new** Claude Code session (the plugin update needs a restart to load).
Part B uses your real config — that is the point — so do B0 first.

### B0 — a way back

```sh
cp ~/Library/Application\ Support/com.mitchellh.ghostty/config.ghostty ~/ghostty-config.manual-test-backup
```

☐ The copy exists. If anything below goes wrong, `cp` it back.

### B1 — it reads before it writes

> **Ask:** `/ghostty-config:edit`

☐ It runs the probe and reads your actual config before proposing anything.
☐ It does **not** invent a config path or claim Ghostty isn't installed.
☐ If more than one config file exists, it says which one it is editing.

### B2 — the trap: a plausible key that is not the current one

> **Ask:** `включи размытие фона, background-blur-radius = 20`

`background-blur-radius` was Ghostty's real key name until 1.1, when it was
renamed to `background-blur`. On 1.3.1 it still **validates clean** through the
compatibility map — so validation alone will not catch it, and neither will a
model working from older documentation.

☐ It ends up writing **`background-blur`**, not `background-blur-radius`.
☐ It *says* the name you gave is a deprecated alias — not that it's a typo, and
  not silently.

**Failure looks like:** writing `background-blur-radius = 20` verbatim because
validation passed. That leaves you on a deprecated name that a future Ghostty
can drop. **Also a failure:** flatly telling you the key doesn't exist — it does.

### B3 — the trap that really is a typo

> **Ask:** `а ещё включи font-ligatures = false`

☐ It reports that `font-ligatures` does **not** exist on your build, and does
  not write it.
☐ It offers the real mechanism (`font-feature`) rather than stopping at "no".

This is the one that regressed in 0.1.5: with `+explain-config` missing, an agent
following the old Step 2 got a non-zero exit for *every* key and would have
called `font-size` a typo just as confidently. If it now dismisses obviously
real keys as typos, that regression is back.

### B4 — you see the diff before anything is written

> **Ask:** `увеличь шрифт на один пункт`

☐ It shows you a diff and **waits** for your agreement before applying.
☐ It does not apply on the strength of your original request.
☐ After applying, it tells you to reload with `cmd+shift+,`.

### B5 — undo shows the list and lets you pick

> **Ask:** `верни как было`

☐ It shows the numbered backup list and **asks which one** — it does not pick
  for you, even though you said "как было".
☐ After restoring, your config is back and it tells you to reload.

☐ **Finally:** open a new Ghostty window and confirm your terminal looks the way
it did before you started.

---

## Part C — clean up

```sh
rm -rf "$LAB"
unset LAB XDG_STATE_HOME P
```

Your real backup ring is untouched by Part A. Part B wrote to it, which is
correct — those were real edits. Check what is there:

```sh
sh "$(ls -d ~/.claude/plugins/cache/kmdv181/ghostty-config/*/ | sort -V | tail -1)/scripts/ghostty-undo.sh" --list
```

Once your config is where you want it, the safety copy from B0 can go:

```sh
rm ~/ghostty-config.manual-test-backup
```

---

## What this test still does not cover

Say it plainly rather than let a passing run imply more than it proves:

- **One Ghostty build.** Everything is recorded against 1.3.1. The 1.4+ branch of
  Step 2 (`+explain-config`) is verified from Ghostty's source, not executed.
- **No-Ghostty machines.** The `exit 2` refusal and `--no-validate` paths cannot
  be reached here, because `find_bin` searches `/Applications/Ghostty.app` by
  absolute path. Testing those needs a machine without Ghostty.
- **Part B is not deterministic.** It samples the agent's behaviour; it does not
  prove it. A pass means the skill steered it correctly *this time*.
- **Linux.** The candidate-path branch is exercised by `tests/hermetic.sh` with a
  fake `uname`, never on a real Linux install.
