# Global preferences

## Default behavior

Unless straightforward (simple lookups, clear how-to): never answer directly — keep asking clarifying questions until full clarity for correct solution.

## What this does not mean

- Don't over-apply to clearly scoped tasks: bug fixes, code edits, explicit "just do X" — those execute directly
- Clarifying questions targeted + purposeful, not stalling
- Prefix "just" or explicit instruction → direct request, execute

## Scope management

- Keep 90% of questions within original topic boundaries
- Exploring adjacent areas → prefix: "This pushes our topic boundary, but relevant because..."
- Watch X-Y problems but don't let context-gathering become endless tangents

## Code comments

- No comments when fixing bugs or editing code: no "why" comments, no rationale inline. All projects.
- Exceptions: user explicitly asks, or file convention heavily commented and new code looks out of place without one.
- Reasoning belongs in commit message, PR description, or ADR — not source file.
- XML doc comments (`///` with `<summary>`/`<remarks>`) separate, encouraged: document *what* a type/member is for IntelliSense, not *why* of edit. Use demand-driven — only where name + type unclear, never blanket every public member. `//` restriction above still applies to inline reasoning.

# Compact instructions

Applies to every compaction — `/compact` and the automatic pass alike.

Preserve, in priority order:

1. Decisions the user made, each with the reason given — verbatim where short.
2. Corrections the user issued, and what the corrected behaviour is now.
3. Rationale for the current direction, including approaches ruled out and why.
4. Questions asked and still unanswered.

Never assert a fact you are reconstructing. If the transcript does not state it, write `unknown` rather than a plausible value. Omitting a detail beats guessing one.

Drop freely: file contents, tool output, search results, dead-end exploration, anything re-readable from disk.

# Working preferences

- **Knowledge routing (no auto-memory)** — auto-memory is off (`autoMemoryEnabled: false`); nothing is written to a private per-machine memory store. Durable knowledge is routed at commit-review time, never auto-saved. Project fact the whole team benefits from → the repo, by kind: contract local to one declaration → `///` XML doc; how the system works today → module or root `README.md`; design not yet built → GitHub spec-issue; considered and not done → `docs/lessons.md`, durable reasons only (bar in `skills/architect/SKILL.md`). Personal workstyle preference → this global `CLAUDE.md`. Auto-memory stays off: it was machine-local and bypassed commit review.
- **Build through the repository's own script, never raw build commands** — where a repository has one entry-point script covering build, code generation and tests, use it and nothing else, including for a single-project rebuild. Raw `build`/`clean`/`test` invocations dump hundreds of lines of toolchain noise into context, re-read every later turn, for no signal a filtered summary doesn't carry. Where the repository has no such script, propose one before reaching for the raw commands a second time.
- **Commit handoff** — when asked to commit (including invoking `/commit`), produce the commit *message* only and stop; never run `git commit`, `git add`/stage, or amend. User runs git themselves, keeps own concurrent uncommitted changes in working tree — `git add -A`/`git add .` would sweep unrelated work into commit. If staging genuinely required, stage only specific files changed, by path — never whole tree. Assume in-progress user edits may be present at all times; leave untouched.
- **Sonnet file discovery** — on Sonnet, prefer the `Explore` subagent (Glob/Grep/Read only) or run `/fewer-permission-prompts` for file/directory discovery. Sonnet reaches for shell `Get-ChildItem` over `Glob`/`Grep` despite instructions → permission prompts.
- **Sub-agent model — always Sonnet, never Opus (nor Haiku)** — every sub-agent runs Sonnet regardless of type or purpose: all `Agent`-tool spawns (reviewers, `Explore`, `test-writer`, `general-purpose`, workers) and every Workflow `agent()` call get `model: 'sonnet'`, and every project agent file sets `model: sonnet` in frontmatter. No sub-agent runs Opus. The orchestrator (main window) is the only Opus-tier model — it writes contracts, triages, and verifies every slice on the converge pass. A slice too hard for Sonnet → split it smaller or pin the design in the contracts yourself; never upgrade the worker.

# graphify

- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`

User types `/graphify` → invoke Skill tool with `skill: "graphify"` before anything else.