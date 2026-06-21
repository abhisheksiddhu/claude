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
- **Commit handoff** — produce the commit *message* only and stop; never run `git commit`, `git add`/stage, or amend. User runs git themselves, keeps own concurrent uncommitted changes in working tree — `git add -A`/`git add .` would sweep unrelated work into commit. If staging genuinely required, stage only specific files changed, by path — never whole tree. Assume in-progress user edits may be present at all times; leave untouched.
  - **Never emit commit-message text unless `/commit` was invoked or the user signalled close.** Not a draft, not a "here's what I'd write", not a subject line dropped into a summary. `/commit` is the only path carrying the terse-style rules — a message written outside it comes out oversized every time.
  - **No commit talk before a close signal.** Finishing a task, a round, or a green build is *not* a close signal. The signal is the user saying *wrap up*, *ship it*, *commit*, or equivalent. Plain "done"/"thanks" is an acknowledgement, not a signal.
  - **A close signal is the go-ahead — do not ask again.** On it, run the whole tail in one turn: `/prose-prune`, then `/commit`, then stop. No "shall I?", no offer line, no confirmation round trip.
  - **Order is fixed:** prune first, message written against the pruned tree. Prune edits the working tree — deletes comments and doc sections in changed files *and their one-hop neighbours* — which is intended here; report in one line what it cut, above the message.
- **Sonnet file discovery** — on Sonnet, prefer the `Explore` subagent (Glob/Grep/Read only) or run `/fewer-permission-prompts` for file/directory discovery. Sonnet reaches for shell `Get-ChildItem` over `Glob`/`Grep` despite instructions → permission prompts.
- **Sub-agent model — always Sonnet, never Opus (nor Haiku)** — every sub-agent runs Sonnet regardless of type or purpose: all `Agent`-tool spawns (reviewers, `Explore`, `test-writer`, `general-purpose`, workers) and every Workflow `agent()` call get `model: 'sonnet'`, and every project agent file sets `model: sonnet` in frontmatter. No sub-agent runs Opus. The orchestrator (main window) is the only Opus-tier model — it writes contracts, triages, and verifies every slice on the converge pass. A slice too hard for Sonnet → split it smaller or pin the design in the contracts yourself; never upgrade the worker.

# Context hygiene

Main window is the orchestrator; its context is the scarce resource. Everything read into it is re-read on every later turn and carried through compaction — a sub-agent's context is spawned, used, discarded. So the default is delegate, and reading something yourself is the exception you justify.

**This section is the standing authorization for the `Agent` tool** — no per-task permission needed, in any project, coding or not.

**Never leaves the main window:**
- **Judgement** — design decisions, shared contracts, triage of findings, the final verdict on a slice. Sub-agents supply evidence; the call is yours.
- **Final user-facing text** — reports, answers, commit messages. Sub-agent prose is raw material, never pasted through.
- **Verification** — the repository's build/test entry point and the reading of its result.
- **A 1–2 line edit at a `file:line` already known** — briefing an agent costs more wall-clock than the edit.

**Everything else goes out**, notably: locating where something lives, any sweep across unknown locations, reading a whole diff, whole-file reads for review, log and build-output triage, doc/API research, hypothesis testing.

**Floor** — read directly only when the path is already known *and* it is ≤3 files. Unknown location, >3 files, or a whole-file scan → `Explore` or a project agent. In doubt, delegate: a wasted agent costs tokens, a polluted main context costs the rest of the session.

**Return shape — state it in every spawn prompt.** Verdict first, `file:line` evidence, no source dumps, no narration of what was searched, ~20 lines unless the task is inherently a list (then the list alone). An agent that returns a transcript has defeated the purpose; say so in the prompt rather than hoping.

**Roster before generics.** The project's own `.claude/agents/` and `.claude/bindings/` first — they carry conventions a generic worker re-derives or gets wrong (e.g. `domain-scout` to plan, `entity-author`/`handler-author` to write, `reviewer-*` to verify). Then the global roster: `Explore` for search, `code-reviewer` for diffs, `test-writer-*` for tests. `general-purpose`/`claude` only where nothing fits. All on Sonnet, per **Sub-agent model** above.

# graphify

- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`

User types `/graphify` → invoke Skill tool with `skill: "graphify"` before anything else.