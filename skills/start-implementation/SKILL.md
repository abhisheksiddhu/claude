---
name: start-implementation
description: Activate by DEFAULT for essentially all coding work — feature implementation, multi-file changes, batches of independent edits, refactors, AND bug fixes. No prior plan or trigger phrase is required; "start implementation"/"let's build it" still activate it, but so does any ordinary "fix X", "implement Y", "why is Z broken". Assume class-wide scope: a bug fix is almost never one site — the user nearly always wants the same class of bug found and fixed everywhere it occurs, so a fix implies a parallel codebase sweep by default. The goal is minimum wall-clock: fan out file-disjoint implementation/sweep slices to concurrent Sonnet sub-agents, and/or fan out concurrent diagnosis agents to hunt a root cause down parallel hypotheses, then integrate and review. Bias aggressively toward parallel execution even at higher token/quota cost — burning quota early to cut wall-clock is the intended trade. The serial-direct path is a rare (<5%) exception, only for a single edit whose exact file+location is already known AND that has no sibling sites. Do NOT activate for pure design discussion (use architect) or a non-coding question.
---

# Parallel-first execution (implicit, looping fan-out)

This is the **default posture for coding work**, not a phrase-gated mode. Whenever a request involves implementing, changing, or diagnosing code, the question is never "should I parallelise?" but "which parallel lever applies?" You shift from writer to orchestrator + integrator. The user does not split the work; you derive the split.

The mechanic that buys speed: a single agent generates and investigates serially and you cannot make it type or read faster. Wall-clock comes from running multiple sub-agents at once — on file-disjoint code slices, or on competing diagnostic hypotheses. Your own output stays serial — you do contracts, triage, and dispatch; the sub-agents do the bulk generation and the search.

**Parallelism is re-applied at every round, not just the first.** This is the single most important rule and the one most easily forgotten. Fan-out is not a one-shot opening move followed by a serial slog. Each round of fan-out converges into a build/test/review pass, and that pass *produces the next batch of work* — build errors, test failures, review findings, remaining sweep sites. **That next batch is re-partitioned and fanned out again, exactly like the first.** You keep looping fan-out → converge → re-fan until a convergence round surfaces nothing new. Never quietly drop into serial hand-fixing for the back half of a task — the integration and review tail is usually as disjoint, and as parallelisable, as the opening wave.

**Quota is not a constraint.** Spending more tokens early to finish in less wall-clock is the explicit trade the user wants. Lean toward fanning out. The only reason *not* to fan out is when fan-out would itself be *slower* (see the floor below), never to save tokens.

## Read your bindings first

Read `.claude/bindings/start-implementation.md` in the project. It carries this project's parameters: the worker roster and what each owns, the wave shape, the single command that builds and tests, and the slice count below which fan-out stops paying. Where a roster exists, dispatch its named agents rather than generic ones — they carry the project's conventions, which a generic worker re-derives or gets wrong. If there is no such file, the defaults below apply.

## Step 0 — Assume class-wide scope, then pick the parallel lever(s)

**A bug fix is almost never one site.** The user nearly always wants the *class* of bug fixed everywhere — they have historically had to add "now look around and fix similar ones" at the end. Do that proactively, by default: treat "fix X" as "fix X and every sibling instance of its class across the codebase". Truly-localised, single-site work is <5% of tasks — don't assume you're in it. This makes nearly every task multi-file, which is exactly what parallelises.

Identify which levers apply and say so in one line, then proceed.

- **Parallel diagnosis** — root cause / correct approach not yet pinned. Fan out concurrent agents (`Explore` for code-hunting, `claude`/`general-purpose` for hypothesis-testing), each chasing a *different* hypothesis or searching a different way (by symptom, by recent diff, by data flow, by similar past fix). First confident root cause wins; you then fix.
- **Parallel class-sweep** (the common one) — once the bug and its fix-shape are understood, fan out concurrent agents to find *and* fix every sibling instance, partitioned by disjoint area (e.g. per feature folder, per layer, per component group) so they never touch the same file. One agent per partition: it greps its area for the class, applies the same fix, writes/updates tests. This is the default tail of essentially every bug fix.
- **Parallel implementation** — feature/refactor work that decomposes into ≥2 file-disjoint units (handlers, validators, entities, DTOs, mappers, endpoints). Fan out one slice per agent.

**The floor differs by lever.** Diagnosis and class-sweep fan out from 2 units — there the parallel search *is* the value, and turning up a sibling site nobody asked about pays for the round on its own. Feature implementation carries a higher floor: coordination overhead is paid per run, so below the slice count the project's bindings name (~4 where it has been measured), default orchestration finishes cheaper and no slower, because there is nothing for the overhead to amortise against.

**Floor — do it directly, serially (rare, <5%):** a single edit whose exact file and location you already know *and* which has no sibling sites (you've confirmed the class is genuinely one-of-a-kind, not assumed it). Here fan-out adds wall-clock with no payoff. Say so in one line and just do it. If in doubt about whether siblings exist, fan out a sweep — cheap to confirm, expensive to miss.

State the decision and proceed. Don't block on a question unless the task is genuinely ambiguous (then ask, per the project's "when in doubt, ask" rule).

## Step 1 — Diagnosis fan-out (when the lever applies)

Spawn 2–4 agents in **one message** so they run concurrently, each with a distinct hypothesis or search angle and a pointer to the relevant module README — not the whole codebase. **Spawn them on Sonnet** (`model: 'sonnet'` on the `Agent` call), per the always-Sonnet sub-agent rule — each agent chases one narrow hypothesis and returns evidence, and you weigh the verdicts yourself on the main window. Have each return a crisp verdict: root cause, the evidence (file:line), and the minimal fix it implies. Converge on the best-supported one; discard the rest. Then move to the fix (directly if localised, or via implementation fan-out if multi-file).

## Step 2 — Lock the shared contracts first (serial, implementation fan-out only)

Parallel code-gen fails when slices invent incompatible interfaces. Before fanning out, write the shared surface every slice depends on — interfaces, request and response types, enumerations, entity contracts, and whatever else the project's bindings name. Small and fast. Build it, confirm it compiles. The slices code against it. (Skip when slices share no contract — e.g. a batch of unrelated fixes.) This runs once, up front — it is not part of the loop below.

## Step 3 — The fan-out loop (repeat until dry)

Everything from here is a **loop**. Each pass is: partition the current work into disjoint slices → fan out → converge once → triage the convergence output into the *next* batch of work. Keep looping until a converge pass produces no new work.

### 3a — Partition the current batch

The "current batch" is whatever work is outstanding right now: round 1 it's the slices/sweep areas from Step 0; later rounds it's the build errors, test failures, review findings, and remaining sites surfaced by the previous converge pass. Partition it into units that own **disjoint files** (per feature folder, per layer, per component group, or per file). Print the split as a short block so the user sees it, then proceed — don't wait for approval.

### 3b — Fan out the batch

- **Moderate (2–5 slices):** spawn with the `Agent` tool, all in one message so they run concurrently.
- **Large or uniform (≥6, or "N similar things"):** author and run a **Workflow** (this skill's instructions are your opt-in) as a partition→implement→re-fan pipeline.

Per sub-agent:
- **Model: Sonnet** (`model: 'sonnet'` on the `Agent` call / `agent()` opts), per the global always-Sonnet sub-agent rule. Every worker gets a single tightly-scoped slice with the contracts, slice spec, and module README handed to it. The main window verifies every slice on the converge pass (build, tests, review), so the orchestrator — not the slice — is where convention drift gets caught. Which conventions those are is the project's business: its `CLAUDE.md` and the reviewer's own bindings name them, and a generic worker will not infer them.
- **No worktrees** when slices are file-disjoint — they write to the one working tree concurrently with no conflict. Use `isolation: 'worktree'` only if two slices must edit the same file, which a re-partition usually removes the need for.
- Give each agent: its slice spec, the locked contracts, and a pointer to the relevant module README. Do **not** paste the codebase — agents read it themselves per the docs-first rule.
- Each slice writes its own tests, in the framework and folder layout the project's test-writer bindings name. For heavy test work, delegate to that project's test-writer agent rather than the slice author. Where the test target is generated code, plan the test slice in this wave but dispatch it in the next — the generated surface does not exist while the implementation slices are still running.

### 3c — Converge once (the irreducible serial point)

Some things genuinely can't parallelise and gate the round — keep them thin:
- Build through the project's own entry-point script where the bindings name one — one invocation; you can't run it concurrently. Reach for a raw build/clean/test command only where the project has no such script: raw invocations may be blocked by a hook, and they dump toolchain noise into a context that re-reads all of it on every later turn.
- Run the affected test projects through that same entry point.
- Review the round's diff — catches the silent convention drift that compiles fine. Delegate it to the project's reviewer agent where one exists; reading a whole diff is exactly the work that belongs in a sub-agent context that gets discarded.
- Eyeball the integration seams the disjoint slices couldn't see across each other.

### 3d — Triage into the next batch, then re-fan (do NOT hand-fix serially)

Collect everything 3c surfaced — compiler errors, failing tests, review findings, sweep sites not yet reached — as one new work list. **This list is just another batch: go back to 3a, partition it by disjoint file/area, and fan it out.** Build errors across 6 files = 6 (or a few grouped) concurrent fixers, not you walking them one by one. Review findings across disjoint sites = re-fan. This is the step that is most tempting to do serially and the one where the most wall-clock is lost — resist it.

**Exit the loop when dry:** a converge pass yields a clean build, green tests, no unresolved review findings, and no remaining class sites. Then stop looping.

**Collapse to serial only at the tail:** when the remaining batch is 1–2 trivial, localised items where spawning + briefing an agent costs more wall-clock than just editing them yourself. Do those inline and re-run 3c. (Same <5% floor as Step 0, now applied per-round.) If a batch keeps regenerating the *same* failures across rounds with no progress, stop fanning and diagnose serially — that's a sign of a shared root cause a sweep can't fix, not more disjoint work.

## Step 4 — Report

Summarise each round: slices (or hypotheses) run, build status, test results, review findings, and how many fan-out rounds it took to go dry. Flag anything skipped or unverified — don't claim done on unverified work.

---

Decomposability is a property of the repository, not of this method. Where a project wires its own boilerplate and builds fast, slices stay disjoint cheaply and fan-out pays early; where a build is slow or every change touches a shared file, the converge pass dominates and the floors rise. Read the project's `CLAUDE.md` and re-assess before fanning out anywhere the bindings are silent.
