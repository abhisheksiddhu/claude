---
name: changelog-review
description: Read the last 30 days of Claude Code release notes and suggest what to adopt in the ~/.claude setup. Returns a ranked report; edits nothing without discussion and explicit approval. Manual invoke only.
---

Read the Claude Code changelog for the last 30 days, check each actionable item against the current setup, and return a ranked adoption report. Edit nothing without first discussing the change with the user and getting their explicit approval. No commit talk.

## Steps

1. **Fetch** https://code.claude.com/docs/en/changelog. Keep releases dated within 30 days of today. Window is fixed.
2. **Extract** — one Haiku agent per ~5 releases, in parallel. Keep only items that can change config or workflow: settings, permissions, hooks, skill/agent frontmatter, slash commands, flags, env vars, MCP, plugins, deprecations, breaking changes. Drop bug fixes and UI polish. Return `version | item | one-line what it enables`.
3. **Check against setup** — one Haiku agent per slice, in parallel: settings+permissions, hooks, skills+agents, MCP+plugins+CLAUDE.md. Each reads the relevant files under `~/.claude` and, for every extracted item in its slice, returns `new | already applied | n/a`, target file, proposed change in one line, why (the concrete fact in our current files that makes it worth doing, with file:line), effort (S/M/L).
4. **Rank** in the main window by value ÷ effort. Drop `already applied` and `n/a`.

## Report

One table, ranked: `# | version | item | why for us | target file | proposed change | effort`.

Then **Breaking / deprecated** — items that hit the current setup, adopted or not. Omit if none.

Then footer: counts of releases scanned, items extracted, already applied.

Verdict first. No narration of what was fetched.
