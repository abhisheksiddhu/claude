---
name: prose-prune
description: Judge whether prose earns its keep across the working tree's changed files, their one-hop neighbours, and the docs beside them — comments, documentation comments, and markdown alike. Deletes what does not earn its keep anywhere in those files regardless of age, deletes whole doc sections and doc files that restate the code, and hard-compresses what survives. Manual invoke only; run it before writing a commit message.
---

Every line of prose has to earn its place. Documentation that restates the code, repeats itself across files, or pads a real point with filler makes a codebase harder to read, not easier — the reader now has more to hold and no more to go on. Judge what earns its keep, and tighten what survives.

**Squeeze words, never facts.** Compression that drops a constraint, a name, a number, or a condition is not compression — it is data loss. Terse is the goal; vague is a failure.

**Doubt resolves to delete.** A line you cannot justify out loud is a line that goes. Git holds the history, so a wrong deletion costs one `git show`; a wrong keep costs every future reader.

**The bar is "would a reader get this wrong without it", not "is this useful".** Useful-but-inferable is the single largest category of prose in a codebase and all of it goes. A line survives only where a competent reader looking at the declaration, the call site, or the code itself would reach the *wrong* conclusion in its absence. Merely saving them a few seconds is not enough.

**What survives is written telegraphically.** Not tightened English — fragments, dropped copulas, symbols for relations. Full sentences survive only in the carve-outs named under `## How to compress`.

## Scope

If the user named files or paths, that is the scope — skip the discovery step below.

Otherwise gather the working tree's changed files:

```bash
{ git diff HEAD --name-only --diff-filter=d; git ls-files --others --exclude-standard; } | sort -u
```

Then add **neighbours**: for each changed source file, the files it imports, includes, or references by module path — one hop only, resolved inside the repository. A neighbour reached from an excluded path is still excluded. Neighbours are judged and edited under exactly the same rules as changed files; the resulting commit will touch files the original change did not.

Then filter to what is worth reading:

- **Keep** source files: `.cs .razor .cshtml .fs .vb .java .kt .kts .scala .groovy .ts .tsx .js .jsx .mjs .cjs .vue .svelte .py .rb .go .rs .swift .c .h .cc .cpp .hpp .m .mm .php .sh .bash .zsh .ps1 .sql .lua .dart .ex .exs .r .jl`
- **Drop** vendored, generated, and build output: any path under `node_modules/ vendor/ dist/ build/ out/ target/ bin/ obj/ .venv/ venv/ __pycache__/ .next/ .nuxt/ coverage/`, any name matching `*.min.* *.bundle.* *.generated.* *.designer.* *.g.* *.pb.* *_pb2.*`, and `*.lock`
- **Documentation** (`.md .mdx .markdown .rst .adoc .asciidoc`) joins the pass only when a changed source file sits in the same directory or beneath it, so prose is judged against the code it describes
- **Never** `CLAUDE.md`, `CLAUDE.local.md`, or `lessons.md`. The first is instruction, the second a permanent record of rejected approaches; neither documents code

Nothing survives the filter → say so in one line and stop.

**Every file that survives the filter is judged in full.** The diff decides which files enter the pass; it does not bound what may be cut inside them. A comment that does not earn its keep is deleted whether this change introduced it or it has sat there for years.

## Read your bindings first

Read `.claude/bindings/prose-prune.md` in the project. It carries this project's parameters: which files to leave alone, what its docs are supposed to contain, and any local convention that overrides what follows. If there is no such file, the defaults below apply.

## Two kinds of comment

Every language separates a **documentation comment**, attached to a declaration and surfaced by tooling, from an **ordinary comment** inside or above code — `///` or `/** */` versus `//`, a docstring versus `#`. Identify which is which from the file's language before touching anything.

**Documentation comments carry no immunity.** They are the contract a caller reads without opening the body, which makes them worth having — not worth keeping unconditionally.

A documentation comment survives only where a caller reading the signature alone would **get it wrong**. Not where it helps, not where it saves a lookup — where the obvious reading of the declaration is the incorrect one. Everything else is deleted outright, including the whole comment when nothing in it clears that bar.

Concretely, the survivors are: nullability the type does not express, thrown exceptions, units, ranges, ownership and disposal, thread-safety, side effects, and empty-versus-absent semantics. That list is close to exhaustive. `/// <summary>Gets the user id.</summary>` on `int GetUserId()` is noise wearing a contract's clothes; so is `/// <summary>Returns the audit trail for a document.</summary>` on `GetAuditTrail(documentId)`. `/// UTC. Empty when never edited.` stays.

A surviving comment is the surprising fact and nothing around it. No summary line reintroduced to host it — if the only content is a `<remarks>`-grade fact, the comment is that fact. Parameter and returns tags survive one at a time, on their own merit, never as a set kept for symmetry. No usage narration, no restating the type system, no examples unless the call is genuinely non-obvious.

**Ordinary comments must earn their keep, and the bar is higher still.**

A surviving comment names one of these, and states it **in one clause** — the naming is the comment, not a preamble to it:

- **An external cause** — a named system, service, specification section, ticket, standard, version, or piece of hardware whose behaviour forced this code. The name must appear in the comment.
- **A specific failure** — what concretely breaks without the code as written. Named symptom, not a category.
- **An ordering constraint** — that this must run before or after something else. This one alone needs no external cause; intra-file sequencing is legitimately invisible in the code and stays.
- **A rejected approach**, stated as approach *and* what broke it. `// tried LINQ here — allocated per row in the hot path` survives. `// don't use LINQ` does not.

Everything else goes. In particular:

- Vague justification — "for safety", "to keep things consistent", "to avoid issues", "just in case", "for clarity". A justification that would fit above almost any line justifies nothing.
- Restating the code, in any paraphrase.
- Explaining _why this edit was made_ rather than why the code is as it is — that is the commit message's job.
- Structural narration: section dividers, "called by X", step numbers, banner headers.
- Duplicating the documentation comment on the same declaration.
- Commented-out code, and `TODO` / `FIXME` / `HACK` with no owner and no ticket.

The test is not "is this useful background" and no longer "would a reader be misled". It is: **can you state the external cause, the failure, the ordering, or the rejected approach that this comment records — naming it, in one clause, with no hedge?** If it takes two clauses to justify, or any hedge to state, the comment does not clear the bar and goes.

Two comments recording the same cause: keep the one nearest the code that cannot be understood without it, delete the other. A cause restated once per call site is one comment, repeated.

## Docs beside touched code

Do this explicitly, do not merely keep it in mind. For every statement in the doc that describes a specific type, member, field, function, or return value, open that declaration and read its documentation comment. Then classify:

- The doc comment already carries the same fact → the statement is **redundant**. Two copies of one fact drift apart, and the one next to the code is the one readers trust.
- Nothing carries it, and the fact is per-member → it belongs on the declaration, not here. Report it; do not migrate it yourself.
- It describes how parts relate, an invariant something enforces, or a workflow spanning several declarations → it belongs in the doc. Leave it.

**Delete** every redundant statement, regardless of whether this diff introduced it. Age is not a defence.

Whether a paragraph is load-bearing is a question you answer by reading the code, not one you defer. Read the declarations, decide, and act. Only genuine irreducible uncertainty — a claim about behaviour you cannot see from this repository, such as a deployment topology or an external contract — survives on the grounds that you could not check it.

**Judge whole sections, not only statements.** Classify every statement under a heading first. If none of them survives, the heading goes with its body — do not keep a heading alive for one surviving fragment that belongs somewhere else, and do not preserve an empty section as a placeholder for future prose. Headings are structure, not content: they earn their place only through what is under them.

These sections die whole, by construction, unless a specific statement in them clears the bar on its own:

- `## Fields`, `### Properties`, `## Members`, `## API` and any other bulleted member list — per-member meaning by construction, so every entry is either redundant with a doc comment or belongs in one.
- Installation or setup steps that restate the package manifest, lockfile, or a script the repository already exposes.
- Usage sections whose examples restate the signature, or duplicate a test or sample already in the tree.
- Structure or architecture sections that narrate the file tree, list directories, or describe what each folder holds.
- Changelogs, "recent changes", roadmaps, and status sections — git holds that, and a hand-maintained copy is wrong the day after it is written.
- Contributing, style, and workflow prose duplicating the repository's own tooling config — linter, formatter, editorconfig, CI file.

What survives in a doc is the thing no declaration can hold: how parts relate, an invariant something enforces, a workflow spanning several declarations, a decision and what it rules out.

**A doc file whose every section dies is deleted outright.** Two exceptions, reduced to their surviving facts and reported rather than removed: the repository-root `README.md`, and any file the project's bindings name as required.

**Compress** the doc prose that survives to the same telegraphic standard as the comments, under `## How to compress` below. Markdown is not exempt: a README paragraph gets the same treatment as a `///` line. Keep every fact. Preserve the heading structure of what survives — deleting a dead section is not a structural change, but never renumber, reorder, or re-level the headings that remain. Match the file's existing line-wrapping — never reflow lines that were not already wrapped, and never unwrap ones that were. Re-wrapping makes diffs noisy and is not your call.

## How to compress

Applies to every surviving comment, documentation comment, and markdown paragraph alike. The target is a telegram, not a tightened sentence — roughly half the words of the original, and if a line came out at 80% of its former length it was not compressed.

**One line is the shape of a surviving comment.** One fact, one clause, no second sentence. A comment that needs a paragraph to state its fact is stating more than one fact, or stating one that the code should carry instead — split it down to the single surprising thing, or delete it. Length is judged against that shape, not against a word count: no numeric cap, and no comment is deleted merely for running long once it is genuinely down to one fact. Identifiers, paths, and quoted error strings are never shortened to fit, whatever they cost in length.

The carve-outs in the hard limits — security notes, data-loss and destructive-action warnings, ordering constraints — are exempt from the one-line shape entirely, and stay in full ordinary English across as many lines as they need.

**Cut outright:**

- Articles — `a`, `an`, `the`.
- Hedges and filler — `generally`, `typically`, `essentially`, `basically`, `simply`, `just`, `note that`, `it should be noted`, `in order to`, `please`, `we`, `you may want to`.
- Copulas and auxiliaries wherever the meaning survives without them — `X is faster` → `X faster`, `this will throw` → `throws`.
- Lead-ins that restate the subject — `This method is responsible for…` → start at the verb. `The purpose of this class is to…` → delete the clause.
- Conjunctions where a symbol or a line break carries the join.

**Fragments are correct, not sloppy.** `Caller owns disposal.` beats `The caller is responsible for disposing of this object.` One word where one word is enough.

**Digits always** — `3`, never `three`.

**Structure beats prose.** A table row, an arrow, or a bullet wherever a sentence was carrying a relation. A three-sentence paragraph describing how three things map to each other is a three-row table.

**Symbol substitutions, in prose only.** This is a closed set — nothing outside it, and never inside an identifier, path, error string, or code fence:

| Symbol | Means |
|---|---|
| → | causes / then / leads to |
| = | is / equals |
| & | and |
| > | more / better than |
| < | less / worse than |
| # | number / count |
| ~ | approximately |
| ≠ | differs from |
| vs | versus |
| e.g. / i.e. | for example / that is |

Spell `with`, `without` and `because` out in full — `w/`, `w/o` and `b/c` are ambiguous and banned. Do not use `!` for not, `@` for at, `/` for per, or any arrow other than `→`.

**Abbreviations are a closed set too.** Only these, and only where the surrounding file does not spell them out: `fn cfg repo impl req res val ret err msg ctx db auth dep env prod dev perf mem async ptr param arg init dupe idx`. Never invent one, never coin a project-specific short form, never abbreviate a domain noun.

Hard limits, no exceptions:

- **Never** compress inside an identifier, symbol, API name, file path, error string, or code fence. Those are quoted exactly, in full, always.
- **Never** shorten past the point of ambiguity. A reader must not have to guess which of two readings you meant. Where terseness and precision conflict, precision wins and the sentence stays long. Caveman-terse is the default, not a licence — an ambiguous fragment is a worse outcome than the paragraph you started with.
- **Never** compress a security note, a data-loss or destructive-action warning, or an ordering constraint whose steps could be misread out of order. Those are written out in full, ordinary English with articles and conjunctions intact. Heavier compression everywhere else makes this carve-out matter more, not less: these are exactly the lines where a dropped conjunction changes the instruction. Resume telegraphic style on the next line.

## Scope of edits

Every comment in every file in scope is a candidate, whatever its age. Delete or compress under the rules above.

Remove any blank line a deletion strands: never leave two consecutive blank lines, or a blank line directly after an opening brace.

## Never touch

- Any comment inside a string literal — including raw or template strings in code generators, which legitimately contain comment markers in the text they emit. Read enough context to be sure a marker is code and not content.
- Preprocessor and tooling directives, pragmas, linter suppressions, type-checker hints, shebangs, encoding declarations.
- URLs, which contain `//`.
- Generated files: anything marked auto-generated by a header, or matching a generated-file pattern named in the project's bindings.
- Licence and copyright headers.
- Code fences, tables, ASCII diagrams, and frontmatter inside markdown.

Change nothing but prose and the whitespace it orphans. Do not reformat, reorder, rename, or improve any code you pass over. Do not add prose.

## Delegation

The pass runs in **Sonnet sub-agents**, never inline. The invariant is that prose edits and file contents never reach the main context — only the reports do. How many agents carry the pass is a sizing question, not a principle.

**One agent by default.** For an ordinary pass — a working tree's changed files and their neighbours — one agent working file by file is the whole pass, and spawning more costs coordination for nothing.

**Fan out when the partition is large enough to pay for it**, which in practice means a named scope of roughly a dozen files or more, or one whose bytes would not fit a single agent's context. Partition by **disjoint files** and spawn the agents concurrently in one message. Two agents must never hold the same file: prose edits are whole-line rewrites, and two writers on one file lose each other's work silently.

Partition by **area, not by size alone** — a module's README belongs in the same slice as the sub-READMEs beneath it, and a spec belongs with the docs it duplicates. Cross-file duplication is a large share of what this pass deletes, and an agent only sees the copies inside its own slice. Splitting related docs across slices hides exactly the redundancy the pass exists to find.

The invoking context may run discovery to build the partition — that reads **paths only**, never contents — and makes no edit itself. Every agent's brief is the same:

- this file's rules, verbatim, from the four bold principles above `## Scope` through to the end of the file. The principles are not preamble — they set the bar the rest of the rules are applied at, and a sub-agent that starts at `## Scope` prunes at the old, softer standard
- its own file list, or the user's named paths where the pass is not partitioned
- `.claude/bindings/prose-prune.md`, if it exists

Each agent does the reading, judging, editing and reporting for its own slice, one file at a time, and does not accumulate file contents it has finished with. Where the pass is not partitioned, the agent does discovery and neighbour resolution too.

Every agent's final message is its report and nothing else, in exactly the `## Output` shape. The invoking context relays those lines unchanged — concatenated in path order where several agents ran — and does not summarise them, count them, add a preamble, or comment on the pass. If the agents return nothing, the invoking context outputs nothing.

## Output

Plain lines only. One line per entry, each beginning with one of the two keywords below. A line in any other shape — a preamble, a closing summary, a code fence, a sentence explaining that nothing needed doing — is a violation of this spec, not a helpful addition.

    removed    <path>: <n> — <what it was, briefly>
    compressed <path>: <n> — <what it was, briefly>
    deleted    <path> — <why the whole file died>

`deleted` is for a doc file removed outright under `## Docs beside touched code`, and for nothing else. A file reduced to its surviving facts is `removed` plus `compressed`, not `deleted`. There is no `kept` line and no `stale` line. Nothing is reported for a future pass, because nothing is deferred to one: what does not earn its keep is gone in this pass, and the diff is the record.

Omit any keyword with no entries. If nothing warranted a change, output nothing at all — an empty response is the correct answer to a clean pass.
