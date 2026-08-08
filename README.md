# kmdv181 — Claude Code marketplace

A personal marketplace: `kmdv181`. Add it once, then install anything from it.

```
/plugin marketplace add kmdv181/kmdv-skills
/plugin install ghostty-config@kmdv181
```

Refresh after pushing changes here:

```
/plugin marketplace update kmdv181
```

`kmdv181` appears twice above and means two different things. In
`kmdv181/kmdv-skills` it's the GitHub owner, and that whole path follows the
repository — rename the repo and this line needs updating, here and in
`plugins/ghostty-config/README.md`. In `@kmdv181` it's the marketplace name, which
comes from `.claude-plugin/marketplace.json` and is independent of both the owner
and the repo name. They match today because that's what reads well, not because
anything requires it.

## Plugins

| Plugin | What it is |
|---|---|
| [`ghostty-config`](plugins/ghostty-config) | Conversational editing of the Ghostty terminal config, with validation before write and rollback. |

## Layout

```
.claude-plugin/marketplace.json   # the catalog — one entry per plugin
plugins/<name>/
└── .claude-plugin/plugin.json    # the plugin's own manifest
    commands/  skills/  agents/  hooks/  scripts/
```

Only the marketplace root carries `marketplace.json`. Individual plugins must
*not* have one — a second marketplace file would register a second, redundant
marketplace under that plugin's name.

## Adding a plugin

1. `mkdir -p plugins/<name>/.claude-plugin` and write its `plugin.json`
   (`name` and `description` are the whole required contract).
2. Add an entry to `.claude-plugin/marketplace.json` with
   `"source": "./plugins/<name>"`. The short `metadata.pluginRoot` form is not
   accepted by the validator — use the full relative path.
3. `claude plugin validate . --strict` and
   `claude plugin validate ./plugins/<name> --strict`.
4. Commit, push, then `/plugin marketplace update kmdv181`.

## Do you actually need this?

Not always. A skill only you use, only on one machine, needs none of this:

| What you want | What's enough |
|---|---|
| A skill for yourself, everywhere | `~/.claude/skills/<name>/SKILL.md` |
| A skill scoped to one project | `.claude/skills/<name>/SKILL.md` in that repo |
| Sync across machines, versioning, sharing, or bundling commands/hooks/MCP with skills | this marketplace |

`/plugin install` only accepts `name@marketplace`, so there's no marketplace-less
install path — but there's also no rule that every skill has to become a plugin.
Start a skill in `~/.claude/skills/`, and move it here when it earns the trip.

## Validation

```sh
claude plugin validate . --strict                        # the catalog
claude plugin validate ./plugins/ghostty-config --strict  # one plugin, incl. frontmatter
```

Validating the repo root checks `marketplace.json` only. Point the validator at a
plugin directory to get its `plugin.json` plus the YAML frontmatter of every
skill, command and agent file.

## License

MIT
