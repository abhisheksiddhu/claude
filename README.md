# Shared Claude Code config

Team-shared global Claude Code config, versioned as `~/.claude` itself. Cloned/adopted into `~/.claude` on each machine so hooks, agents, skills, harness settings resolve at expected paths.

## What lives here

- `agents/` — reusable sub-agents available in every project
- `skills/` — reusable skills available in every project
- `settings.json` — harness config: hooks, status line, effort level (hooks reference root scripts below by `~/.claude/...` path, so whole tree must live at `~/.claude`)
- `settings.local.json`, `CLAUDE.local.md` — optional, gitignored, never shared: your machine-local overrides (see [Local overrides](#local-overrides))
- `hooks/`, `prune.sh`, `sync.sh`, `statusline-command.sh` — scripts wired by `settings.json`
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

# Optional: only if you have settings of your own you want to keep.
# settings.local.json is gitignored, so the reset leaves it alone, and Claude Code
# layers it over the shared settings.json.
[ -f settings.json ] && mv settings.json settings.local.json

git reset --hard origin/main
```

Most people can skip that `mv` and just take the shared config as-is — that is the normal path, and it is what the harness is tuned for. It is there for the case where you have already customised your own `settings.json` and want to carry something over: run it **before** `git reset --hard`, since the reset replaces tracked files. Anything already in a `settings.local.json` gets overwritten by the `mv`, so if you have both, merge them yourself first.

**What `git reset --hard` does here:** it replaces the repo's *tracked* files — `settings.json`, `CLAUDE.md`, the caveman files, `prune.sh`, `statusline-command.sh` — with the shared versions. That is the point: you are adopting the shared harness. Your **untracked** files are left alone — credentials (`.credentials.json`), the `.local` files below, `projects/`, caches are all gitignored, so nothing personal or secret is touched.

### Local overrides

Machine-local tweaks belong in the `.local` variants. They are gitignored, never shared, and survive every reset:

| File | Overrides |
|---|---|
| `settings.local.json` | `settings.json` — hooks, permissions, env, status line |
| `CLAUDE.local.md` | layers onto `CLAUDE.md` — personal instruction defaults |

Same pattern works per-project: `.claude/settings.local.json` and `CLAUDE.local.md` in a project root, both gitignored by default there too. Keep anything you would not want to push in these; put anything the team should get in the shared file and push it.

### Updates

`sync.sh` runs on session start and keeps you current, so there is normally nothing to do. It checks the remote at most once every 24 hours and only fast-forwards a **clean** tree onto `origin/main`. If you have uncommitted edits to tracked files, or local commits that are not on `origin/main`, it prints one line and skips — so anyone customising the harness is opted out automatically, without setting anything. `touch ~/.claude/.no-sync` opts out permanently.

A sync lands on the next start: the current session already loaded `settings.json` and the hook scripts, so restart Claude Code to pick up changes.

To update by hand — or to take an update that `sync.sh` skipped:

```bash
git -C ~/.claude fetch origin
git -C ~/.claude reset --hard origin/main
```

Fetch plus reset rather than `git pull`, since the shared branch is the source of truth and a plain pull turns any local drift in a tracked file into a merge conflict. Unlike `sync.sh`, this reset is not gated: it drops your local edits to tracked files. Keep machine-local settings in the `.local` files above and push anything meant for the team.

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
