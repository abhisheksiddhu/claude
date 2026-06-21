# Global preferences

## Default behavior

Unless straightforward (simple lookups, clear how-to): never answer directly — keep asking clarifying questions until full clarity for correct solution.

## What this does not mean

- Don't over-apply to clearly scoped tasks: bug fixes, code edits, explicit instructions, "just do X" — execute directly
- Clarifying questions targeted + purposeful, not stalling

## Scope management

- Keep 90% of questions within original topic boundaries
- Exploring adjacent areas → prefix: "This pushes our topic boundary, but relevant because..."
- Watch X-Y problems but don't let context-gathering become endless tangents

## Code comments

- No comments when fixing bugs or editing code: no "why" or rationale comments inline. All projects.
- Exceptions: user explicitly asks, or file convention heavily commented and new code looks out of place without one.
- Reasoning belongs in commit message, PR description, or ADR — not source file.
- XML doc comments (`///` with `<summary>`/`<remarks>`) separate, encouraged: document *what* a type/member is for IntelliSense, not *why* of edit. Use demand-driven — only where name + type unclear, never blanket every public member.

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

- **Knowledge routing** — durable knowledge is routed at commit-review time, never auto-saved. Project fact the whole team benefits from → the repo, by kind: contract local to one declaration → `///` XML doc; how the system works today → module or root `README.md`; design not yet built → GitHub spec-issue; considered and not done → `docs/lessons.md`, durable reasons only (bar in `skills/architect/SKILL.md`). Personal workstyle preference → this global `CLAUDE.md`.
- **Build through the repository's own script, never raw build commands** — where a repository has one entry-point script covering build, code generation and tests, use it and nothing else, including for a single-project rebuild. Raw `build`/`clean`/`test` invocations dump hundreds of lines of toolchain noise into context, re-read every later turn, for no signal a filtered summary doesn't carry. Where the repository has no such script, propose one before reaching for the raw commands a second time.
- **Commit handoff** — produce the commit *message* only and stop; never run `git commit`, `git add`/stage, or amend. User runs git themselves and keeps concurrent uncommitted changes in the working tree — `git add -A`/`git add .` would sweep unrelated work into the commit. If staging is genuinely required, stage only the specific files you changed, by path. Assume in-progress user edits are always present; leave untouched.
  - **Never emit commit-message text unless `/commit` was invoked or the user signalled close.** Not a draft, not a "here's what I'd write", not a subject line dropped into a summary. `/commit` is the only path carrying the terse-style rules — a message written outside it comes out oversized every time.
  - **No commit talk before a close signal.** Finishing a task, a round, or a green build is *not* a close signal. The signal is the user saying *wrap up*, *ship it*, *commit*, or equivalent. Plain "done"/"thanks" is an acknowledgement, not a signal.
  - **A close signal is the go-ahead — do not ask again.** On it, run the whole tail in one turn: `/prose-prune`, then `/commit`, then stop. No "shall I?", no offer line, no confirmation round trip. Prune edits the working tree (deletes comments and doc sections in changed files *and their one-hop neighbours*) — intended here; report in one line what it cut, above the message.
- **Sub-agent model — Haiku or Sonnet by expected context size, never Opus** — Haiku 5.5 matches Sonnet 5 quality but is ~20x cheaper under 100k tokens and ~4x cheaper above; in the 100k–250k band Sonnet's quality outweighs the saving. Size the sub-agent's own expected context: under 100k or over 250k → `model: 'haiku'`; 100k–250k → `model: 'sonnet'`. Applies to all `Agent`-tool spawns (reviewers, `Explore`, `test-writer`, `general-purpose`, workers) and every Workflow `agent()` call. Project agent files set the model matching their typical context in frontmatter; a spawn-time `model` overrides it when the task is atypical. The main window is the only Opus-tier model. A slice too hard for Haiku/Sonnet → split it smaller or pin the design in the contracts yourself; never upgrade the worker to Opus.

# Context hygiene

Main window is the orchestrator; its context is the scarce resource. Everything read into it is re-read on every later turn and carried through compaction — a sub-agent's context is spawned, used, discarded. So the default is delegate, and reading something yourself is the exception you justify.

**This section is the standing authorization for the `Agent` tool** — no per-task permission needed, in any project, coding or not.

**Main window only.** A sub-agent reading this does its delegated task itself and returns one summary — no re-delegation, no spawning further agents.

**Never leaves the main window:**
- **Judgement** — design decisions, shared contracts, triage of findings, the final verdict on a slice. Sub-agents supply evidence; the call is yours.
- **Final user-facing text** — reports, answers, commit messages. Sub-agent prose is raw material, never pasted through.
- **Verification** — the repository's build/test entry point and the reading of its result.
- **A 1–2 line edit at a `file:line` already known** — briefing an agent costs more wall-clock than the edit.

**Everything else goes out**, notably: locating where something lives, any sweep across unknown locations, reading a whole diff, whole-file reads for review, log and build-output triage, doc/API research, hypothesis testing.

**Floor** — read directly only when the path is already known *and* it is ≤3 files. Unknown location, >3 files, or a whole-file scan → `Explore` or a project agent. In doubt, delegate.

**Fan out wide.** Agents are cheap. Split any task into as many file-disjoint, independent slices as it cleanly yields and spawn them concurrently in one message. Prefer many small agents (small contexts stay in Haiku's cheap band) over one large one. Where slices depend on each other, run them in phases: phase 1 is every independent slice in parallel, phase 2 is everything that needs only phase-1 output in parallel, phase 3 likewise on phase 2, and so on. Group by dependency depth, not by topic, to minimise wall-clock time — a slice starts as soon as its inputs exist, never later. Slices that overlap files go in separate phases. Between phases the main window reads only the returned summaries, so its context stays pristine for the length of the conversation.

**Return shape — state it in every spawn prompt.** Verdict first, `file:line` evidence, no source dumps, no narration of what was searched, short unless the task is inherently a list (then the list alone).

**Roster before generics.** The project's own `.claude/agents/` and `.claude/bindings/` first — they carry conventions a generic worker re-derives or gets wrong (e.g. `domain-scout` to plan, `entity-author`/`handler-author` to write, `reviewer-*` to verify). Then the global roster: `Explore` for search, `code-reviewer` for diffs, `test-writer-*` for tests. `general-purpose`/`claude` only where nothing fits.

# Coding work

Default posture for any request to implement, change, or diagnose code — no trigger phrase needed. Builds on **Context hygiene**; this adds the coding loop. Quota is not a constraint: spend tokens to cut wall-clock, and skip fan-out only where it would itself be slower.

- **Bindings first** — read the project's `.claude/bindings/start-implementation.md` if present: worker roster, wave shape, build-and-test command, slice-count floor. Dispatch its named agents over generic ones.
- **Class-wide by default** — "fix X" means fix X and every sibling instance of its class across the codebase. Truly single-site work is <5%; unsure whether siblings exist → sweep.
- **Pick the lever(s), say so in one line, proceed:**
  - *Diagnosis* — root cause unknown: 2–4 concurrent agents, each on a distinct hypothesis or search angle (symptom, recent diff, data flow, similar past fix), each returning root cause, `file:line` evidence, minimal fix. Best-supported wins.
  - *Class-sweep* — fix shape known: one agent per disjoint area greps for the class, applies the fix, updates tests.
  - *Implementation* — feature or refactor: one file-disjoint slice per agent. Fans out from the bindings' slice-count floor (~4 where measured); diagnosis and sweep fan out from 2.
- **Serial-direct** only for a single edit at a known location with siblings confirmed absent.
- **Contracts first** — before implementation fan-out, write and build the shared surface (interfaces, request/response types, enums, entity contracts); slices code against it. Skip when slices share none.
- **Brief each worker** with its slice spec, the locked contracts, and a module README pointer — never pasted code. Each slice writes its own tests; heavy test work → the test-writer agent; tests of code-generator output go in the next wave, since that output does not exist until the build runs. No worktrees for file-disjoint slices.
- **Loop until dry** — each round: partition outstanding work into file-disjoint slices → fan out → converge (one build and test run through the entry-point script; diff review delegated to the project's reviewer or `code-reviewer`; check the seams between slices) → build errors, test failures, review findings, and unreached sites become the next batch, re-partitioned and re-fanned. Never slide into serial hand-fixing for the back half. Exit when a converge pass is clean. A batch of ≥6 or "N similar things" → a Workflow; this section is the opt-in.
- **Tail and stall** — 1–2 trivial localised items left → edit inline and re-converge. The same failures recurring across rounds with no progress → stop fanning and diagnose serially: it is a shared root cause.
- **Report** per round: slices or hypotheses run, build, tests, review findings, rounds to dry; flag anything unverified. Then stop — close per **Commit handoff**.