# kmdv181 — a marketplace for Claude Code and Codex

A personal marketplace: `kmdv181`. Add it once, then install anything from it.

Claude Code:

```
/plugin marketplace add kmdv181/skills
/plugin install always-english-artifacts@kmdv181
```

Codex:

```
codex plugin marketplace add kmdv181/skills
codex plugin add always-english-artifacts@kmdv181
```

Both CLIs read the same `.claude-plugin/marketplace.json`. Codex needs no
marketplace file of its own — the name is a historical accident, not a scope.

Refresh after pushing changes here:

```
/plugin marketplace update kmdv181     # Claude Code
codex plugin marketplace upgrade       # Codex
```

`kmdv181` appears twice above and means two different things. In
`kmdv181/skills` it's the GitHub owner, and that whole path follows the
repository — rename the repo and this line needs updating, here and in each
plugin's README. In `@kmdv181` it's the marketplace name, which comes from
`.claude-plugin/marketplace.json` and is independent of both the owner and the
repo name. They match today because that's what reads well, not because anything
requires it.

## Plugins

| Plugin | Claude Code | Codex | What it is |
|---|---|---|---|
| [`always-english-artifacts`](plugins/always-english-artifacts) | yes | yes | Talk to the agent in any language; keep code, comments, Markdown, commit messages and issue text in English. |
| [`ghostty-config`](plugins/ghostty-config) | yes | — | Conversational editing of the Ghostty terminal config, with validation before write and rollback. |

Codex needs no Codex-specific manifest: it discovers plugins through
`.claude-plugin/marketplace.json` and loads their components from the default
paths. `ghostty-config` is marked Claude-only because it has not been exercised
under Codex, not because anything blocks it.

## Layout

```
.claude-plugin/marketplace.json   # the catalog — one entry per plugin, read by both CLIs
plugins/<name>/
├── .claude-plugin/plugin.json    # the plugin's manifest, read by both CLIs
└── skills/  agents/  hooks/  scripts/
```

Only the marketplace root carries `marketplace.json`. Individual plugins must
*not* have one — a second marketplace file would register a second, redundant
marketplace under that plugin's name.

A `.codex-plugin/plugin.json` was tried and removed: with it absent from both
the marketplace snapshot and the install cache, Codex still loaded the plugin's
hook. It buys nothing and would add a second `version` field to keep in step.

## Adding a plugin

1. `mkdir -p plugins/<name>/.claude-plugin` and write its `plugin.json`
   (`name` and `description` are the whole required contract).
2. Keep components at their default paths (`skills/`, `hooks/hooks.json`, …) so
   both CLIs find them without a manifest override.
3. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./plugins/<name>"`. The short `metadata.pluginRoot` form is not
   accepted by the validator — use the full relative path.
4. `claude plugin validate . --strict` and
   `claude plugin validate ./plugins/<name> --strict`.
5. Commit, push, then refresh the marketplace in each CLI.
6. Verify it behaves — see below. Steps 1–5 can all pass on a plugin that does
   nothing.

## Verifying

`claude plugin validate` checks schemas and YAML frontmatter. It does not check
that the plugin loads, that component names do not collide, or that a hook or
script does what it claims. `CLAUDE.md` in this repo makes a working feedback
loop a precondition for starting; these are the loops that exist here.

| What you changed | How to actually verify it |
|---|---|
| Manifests, catalog | `claude plugin validate` — schema only |
| Anything that ships | Install it, then `claude plugin details <name>@kmdv181`. The component inventory is the only thing that catches duplicate component names. |
| Shell scripts | Fixtures and a fake binary; assert exit codes and file contents. `ghostty-config` stubs `ghostty` and `uname`; `always-english-artifacts` runs `scripts/test.sh`. |
| Anything that changes agent behaviour | Run the same prompt with the plugin enabled and disabled. A probe that passes in both arms proves nothing — pick one where the baseline plausibly fails. |

## Codex hook trust

Installing or enabling a plugin does not trust its hooks. Codex skips
plugin-bundled hooks until you review and approve the hook definition, once per
machine, and it does so **silently** — the plugin reports as `installed,
enabled` while contributing nothing. Start Codex interactively once after
installing to approve.

The trust hash covers the hook definition, so editing `hooks/hooks.json` forces
a re-approval everywhere. Prefer keeping the changeable part — prompt text,
payloads — in a separate file the hook reads.

Claude Code has no equivalent gate.

## Do you actually need this?

Not always. A skill only you use, only on one machine, needs none of this:

| What you want | What's enough |
|---|---|
| A skill for yourself, everywhere | `~/.claude/skills/<name>/SKILL.md` |
| A skill scoped to one project | `.claude/skills/<name>/SKILL.md` in that repo |
| Sync across machines, versioning, sharing, both CLIs, or bundling hooks/MCP with skills | this marketplace |

`/plugin install` only accepts `name@marketplace`, so there's no marketplace-less
install path — but there's also no rule that every skill has to become a plugin.
Start a skill in `~/.claude/skills/`, and move it here when it earns the trip.

## Validation

```sh
claude plugin validate . --strict                                  # the catalog
claude plugin validate ./plugins/always-english-artifacts --strict  # one plugin
```

Validating the repo root checks `marketplace.json` only. Point the validator at a
plugin directory to get its `plugin.json` plus the YAML frontmatter of every
skill, command and agent file.

## License

MIT
