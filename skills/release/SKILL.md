---
name: release
description: >
  Generate a promotion commit message for a dev→uat or dev→main release — a coverage-first roll-up of
  many commits into one message. Thin delta over the /commit skill: same Conventional base, flat unwrapped
  body, but exhaustive across modules; infers and emits directly, asking only on genuine ambiguity. Manual invoke only.
---

Base format = the `/commit` skill (Conventional Commits, flat unwrapped body lines, why over what, never-goes-in list, message-only boundary). This skill encodes ONLY the release deltas below — everything unstated is inherited from `/commit`.

Inverted bias — but on ONE axis only. `/commit` defaults SMALL because its recurring complaint is size. A release inverts that for **breadth**: every touched module earns a bullet, because a module dropped from the message is an undocumented production deploy. It does NOT invert for **depth** — each bullet stays as terse as a `/commit` body, seam-level, never a per-file inventory. Coverage = horizontal (no module missed), never vertical (every identifier listed). A release message is a roll-up, not a merged diff.

## 1. Gather context — one script
Run the bundled collector to pull the whole changeset in one read-only, pre-approvable command:
```
bash ~/.claude/skills/release/collect.sh              # auto-detects target
bash ~/.claude/skills/release/collect.sh uat          # or pass a target ref to override
```
It emits five labelled sections: **META** (branch, `version`, `target`, count), **CHANGESET** (author + subject per commit), **FULL BODIES**, **BODYLESS COMMITS — FILE STAT** (module resolved from files for `minor fix`/empty subjects), and **FORMAT REFERENCE** (last 3 `release-*` commits to mirror). It auto-detects target = `uat` if that branch exists else `main`, and `version` = current branch minus the `dev-` prefix (`dev-3.8` → `3.8`).

Do NOT hand-run ad-hoc `git log`/`git show` loops — they defeat the single-approval design. If the script is unavailable, everything it does is plain read-only git (`rev-parse`, `log`, `show --stat`, `show-ref`); reconstruct only as a fallback. Never commit, stage, tag, merge, or push.

## 2. Subject
`release-<version>: <comma-list of 3–5 key aspects>`
- Key aspects = the headline modules/themes of the release, comma-separated, most significant first
- Tag qualifiers in parens only where they apply: `(WIP)` for not-yet-general-use. `(priority)` is for a hotfix's lead fix only — a regular release is just a collection of work and carries no priority tag; omit it
- **No trailing `(#PR)`** — GitHub appends the promotion PR number on squash-merge
- No type/scope prefix (that is `/commit`'s shape); the `release-<version>:` prefix replaces it

## 3. Body
Same flat unwrapped `-` bullets as `/commit` — one bullet per line, never soft-wrap at 72.
- **One bullet per touched module/theme** — this is the coverage guarantee (breadth). Walk the whole changeset; every distinct area gets a bullet, nothing silently dropped.
- **Hard depth cap per bullet: 1–2 sentences.** Shape: `Module: the headline change + the why + the single load-bearing seam`. Stop there. A bullet that runs 4+ lines or names 5+ symbols has become a merged diff — cut it back to the seam.
- **At most 1–2 concrete identifiers per bullet**, and only the load-bearing one(s) (the type/flag/error-code the change turns on). NEVER a roster of handlers/components/files/request types — that is the per-file inventory `/commit` forbids on large diffs, and it applies here just as hard.
- **Order by significance**, most impactful module first. Never order or weight by commit volume — a one-commit contributor's module ranks by importance, not count. (Every contributor's work stays represented this way; GitHub's squash-merge adds the `Co-authored-by:` trailers automatically, so do not write them.) A hotfix release may lead with a `(priority)` bullet; a regular release just leads with its biggest piece of work, no priority marker.
- Tag WIP modules inline: `forms (WIP, not yet general-use): …`
- Terse ≠ vague — the ONE seam and the why survive; the file roster dies. Cluster issue refs at the bullet end: `(#124 #126)`
- Fold minor sibling changes into a single trailing bullet, not one bullet each — and keep that bullet to a bare list of names, no detail.
- **Trivial or junk-subject commits** (`minor fix`, `wip`, `fixup`, `typo`, empty/bodyless) never get their own bullet. Resolve the module they belong to from the files they touch (`git show --stat`) and fold them silently into that module's bullet. A `minor fix` touching `Repository.cs` is part of the Repository bullet, not a line of its own — but its change must still be reflected, never dropped.

## Size target
A release message is a roll-up someone skims to know what shipped, not an audit trail. Aim: subject + 5–8 bullets, each 1–2 sentences. If a module truly did many distinct things, name the 2–3 that matter and stop — the diff and the squashed commits hold the rest. When a bullet tempts you past 2 sentences, that is the signal you are transcribing the diff, not summarising it.

## 4. Clarifying questions — only when genuinely in doubt
Default: infer everything from the changeset and emit the message directly. Do NOT ask for confirmation of things the diff already answers — headline aspects, priority order, and WIP status are almost always readable from the commits (subjects, bodies, `git show --stat`, and how the previous `release-*` commits tagged the same modules).

Ask a question ONLY when a real ambiguity blocks a correct message and the diff cannot resolve it — e.g. two modules look equally headline and nothing signals which leads, or a module's general-use vs WIP status is genuinely unclear from the code. Then ask just that one question, not a fixed set. A run with no real ambiguity asks nothing.

## Never goes in
Inherits `/commit`'s list. Plus, specific to releases:
- `Co-authored-by:` trailers and the `(#PR)` suffix — GitHub adds both on squash-merge
- Per-file inventories — capture the why and the seams per module, not every file
- Intra-flow mechanics — "on step 2", "in the second wizard pane", "after clicking Next". Describe what shipped, not where in a flow it sits. `login echoes the username on step 2` → `login echoes the username`.
- "This release does X", "I", "we", "now"

## Example
Generic shape — real module/folder names, concrete mechanisms, no product-domain specifics.

Subject:
```
release-<version>: auth session hardening, forms response storage (WIP), config write path, CI parallelisation
```
Body (flat, one bullet per line — coverage across every module, priority first):
```
- Auth (priority): an expired token previously returned an empty profile as 200 OK so the client stored a bogus identity; the endpoint now requires authorization, an expired token yields 401 and the refresh interceptor engages. Callback verifies the returned account matches the user before pinning identity — a mismatched account returns a distinct error code instead of the alarming binding-conflict message.
- Forms (WIP, not yet general-use): response storage pivots from per-section documents to one per-assignment document, section resolved at read; oversize handled reactively by splitting on the store's size limit rather than capping in handlers.
- Config: expose the org write path so a setting can be enabled end-to-end; drop the redundant feature flag that silently gated it off.
- Repository: guard writes under an If-Match ETag and map a lost update to a concurrency-conflict response instead of last-write-wins (#124 #126).
- CI/tests/docs: build once and run test suites in parallel (wall-clock 4m→~15s); fold a shipped spec into its module README.
```

## Boundaries
Same as `/commit` — generates the message only. Never runs `git commit`, stage, amend, tag, merge, or push. Read-only git (`log`, `branch`, `rev-list`) to build the changeset is fine. Output as a code block ready to paste.
