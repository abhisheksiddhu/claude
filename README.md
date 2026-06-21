# Shared Claude Code config

Team-shared global Claude Code config, versioned as `~/.claude` itself. Cloned/adopted into `~/.claude` on each machine so hooks, agents, skills, harness settings resolve at expected paths.

## What lives here

- `agents/` — reusable sub-agents available in every project
- `skills/` — reusable skills available in every project
- `settings.json` — harness config: hooks, status line, effort level (hooks reference root scripts below by `~/.claude/...` path, so whole tree must live at `~/.claude`)
- `hooks/`, `prune.sh`, `statusline-command.sh` — scripts wired by `settings.json`
- `caveman-rules.txt`, `caveman-turn.txt` — the caveman persona injected by the hooks
- `CLAUDE.md` — global instruction defaults

Project-specific agents/skills do **not** belong here — they stay in each project's own `.claude/`. On a name clash, the project copy wins.

## Install (teammates)

Claude Code already creates `~/.claude`, so you cannot clone over it. Adopt repo in place instead:

```bash
cd ~/.claude
git init
git remote add origin https://github.com/abhisheksiddhu/claude.git
git fetch origin
git reset --hard origin/main
```

**What `git reset --hard` does here:** it overwrites the repo's *tracked* files — `settings.json`, `CLAUDE.md`, the caveman files, `prune.sh`, `statusline-command.sh` — with the shared versions. That is the point: you are adopting the shared harness. Your **untracked** files are left untouched — credentials (`.credentials.json`), `projects/`, caches, and anything else are all gitignored, so nothing personal or secret is deleted. If you have customised your own `settings.json`, back it up first, because it will be replaced.

Update later:

```bash
git -C ~/.claude pull
```

Runtime state, session transcripts, and secrets are gitignored — only shared config is tracked.

## Third-party skills

Skills vendored from external sources, copied into `skills/` rather than managed by Claude Code's plugin/marketplace system — do **not** appear in `/plugin` Marketplaces; updates come from source repo (re-run installer / `git pull` there), not plugin UI.

- `skills/graphify/` — third-party skill by Graphify-Labs — https://github.com/Graphify-Labs/graphify. Provides `graphify` CLI, `/graphify` trigger; wires session hooks injecting `graphify:` context on tool calls. Update/remove via source repo; removing also means stripping graphify blocks from `CLAUDE.md` (and any project `CLAUDE.local.md`) plus hook entry in `settings.json`.

## Credits

Caveman persona and commit skill are derivatives of the **caveman** Claude Code skill by Julius Brussee — https://github.com/JuliusBrussee/caveman — used and modified under MIT licence.

- `caveman-rules.txt` / `caveman-turn.txt` / `hooks/caveman-*` — the caveman persona and its activation/tracking hooks, stripped of the selectable compression levels and tuned more aggressive (always-on, single fixed level).
- `skills/commit/` — derived from upstream's `caveman-commit`, adapted to a team commit workflow (Conventional Commits, flat unwrapped body lines, scope = module/area).

```
MIT License

Copyright (c) 2026 Julius Brussee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
