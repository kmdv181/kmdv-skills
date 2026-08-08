# always-english-artifacts

Talk to the agent in any language; keep everything it writes down in English.

```
/plugin marketplace add kmdv181/skills
/plugin install always-english-artifacts@kmdv181
```

## What it does

At session start the plugin injects one rule as developer context: **anything
that outlives the conversation is written in English.** Source code, comments,
identifiers, docstrings, Markdown, config, commit messages, branch names, PR
titles and bodies, review comments, and issue text written through tools like
`bd` or `gh`.

Several of those are not file writes, which is why they are named explicitly —
an agent told only "write files in English" will still produce a Russian commit
message.

The rule also pins two things that otherwise go wrong:

- A draft artifact quoted in chat stays English. Without this, an agent asked to
  reply in Russian will translate its own commit message to match the
  surrounding prose.
- Reasoning language is left alone. The rule governs output, not thought.
  Forcing a fixed reasoning language measurably hurts accuracy, and the
  translation step introduces its own errors.

It carries no preference about what language *you* speak — that belongs in your
own `CLAUDE.md`, not in a shared plugin.

## Why a hook and not a skill

Skills load on demand. This rule has to hold on every turn, including turns
where nothing signals that language is relevant, so it ships as a `SessionStart`
hook that injects the rule as context. Plugins cannot contribute `CLAUDE.md`
content; a hook is the only always-on mechanism available to one.

The matcher covers `startup|resume|clear|compact|fork`, so the rule is re-injected
after a compaction rather than quietly disappearing mid-session.

## Codex

The same plugin works under Codex CLI, unmodified. Codex discovers it through
this repo's `.claude-plugin/marketplace.json` — no separate marketplace or
manifest file is needed — reads plugin hooks from the same `hooks/hooks.json`
path, accepts the same `hookSpecificOutput.additionalContext` payload, and
supplies `CLAUDE_PLUGIN_ROOT` to plugin-bundled hooks as a compatibility
variable.

```
codex plugin marketplace add kmdv181/skills
codex plugin add always-english-artifacts@kmdv181
```

**Then trust the hook, once per machine.** Installing or enabling a plugin does
not trust its hooks — Codex skips plugin-bundled hooks until you review and
approve the current hook definition, and it does so silently. Start Codex
interactively once and approve; until you do, the plugin reports as `installed,
enabled` while injecting nothing. To confirm without the interactive step:

```
printf 'One word, YES or NO: is a block titled "Artifact language" in your context?' \
  | codex exec --dangerously-bypass-hook-trust -
```

The trust hash covers the hook definition, so editing `hooks/hooks.json` requires
re-approval. Editing the rule text does not — the payload is a separate file.

Claude Code has no equivalent gate; the plugin takes effect there on the next
session after install.

## Editing the rule

`rules/artifact-language.md` is the source. The hook does not read it directly —
it prints `hooks/session-start.json`, generated from the Markdown:

```bash
scripts/build.sh     # regenerate the payload; needs jq
scripts/test.sh      # verify; run before committing
```

Commit both files. `scripts/test.sh` fails if they have drifted.

The payload is pre-encoded rather than built at session start so the hook has no
runtime dependency beyond `cat`. A hook that needs `jq` fails silently on a
machine without it, and a silently missing rule is worse than no plugin.

## Layout

```
.claude-plugin/plugin.json
hooks/hooks.json            SessionStart -> scripts/emit-rule.sh
hooks/session-start.json    generated payload, committed
rules/artifact-language.md  the rule, as prose
scripts/emit-rule.sh        cat the payload
scripts/build.sh            markdown -> payload
scripts/test.sh             payload shape, drift, and no-jq execution
```
