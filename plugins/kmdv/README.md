# kmdv

Personal skills bundle. Installed skills are invoked as `/kmdv:<skill-name>` —
the plugin name is the namespace, so nothing here can collide with a bundled or
project skill of the same name.

**This plugin currently ships zero skills.** It's the shell to grow into.

```
/plugin install kmdv@kmdv181
```

## Adding a skill

```
plugins/kmdv/skills/<skill-name>/SKILL.md
```

```markdown
---
name: <skill-name>
description: What it does, and when Claude should reach for it. This sentence is
  the only thing Claude sees before deciding to load the skill — write it as a
  trigger, not a summary.
---

# <Skill name>

Instructions go here.
```

The directory name becomes the command. `name` and `description` are required;
`argument-hint` and `allowed-tools` are optional. Supporting files live beside
`SKILL.md` and load only when the skill runs, so long reference material is cheap.

Then:

```sh
claude plugin validate ./plugins/kmdv --strict
git commit && git push
```

and in a session: `/plugin marketplace update kmdv181`.

## When a skill belongs here vs. in `~/.claude/skills/`

Put it in `~/.claude/skills/<name>/SKILL.md` when it's a scratch idea, machine-
specific, or contains anything you wouldn't publish — **this repository is
public.** Move it here once you want it versioned, on every machine, or shareable.

Moving is just relocating the directory; the frontmatter is identical. The only
change is the invocation: `/foo` becomes `/kmdv:foo`.
