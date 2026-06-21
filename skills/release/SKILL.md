---
name: release
description: >
  Generate a promotion commit message for a dev→uat or dev→main release — a coverage-first roll-up of
  many commits into one message. Thin delta over the /commit skill: same Conventional base, flat unwrapped
  body, but exhaustive across modules; infers and emits directly, asking only on genuine ambiguity. Manual invoke only.
---

Base format = the `/commit` skill. This skill encodes ONLY the release deltas below (bulleted bodies included) — everything unstated is inherited from `/commit`.

Inverted bias on ONE axis: **breadth**. Every touched module earns a bullet, because a module dropped from the message is an undocumented production deploy. Depth is not inverted (see Body). A release message is a roll-up, not a merged diff.

## 1. Gather context — one script, via sub-agent
A Haiku sub-agent runs the bundled collector (one read-only, pre-approvable command) and returns a per-module digest covering EVERY commit — none dropped. The main window writes the message from the digest.
```
bash ~/.claude/skills/release/collect.sh              # auto-detects target
bash ~/.claude/skills/release/collect.sh uat          # or pass a target ref to override
```
The script emits five labelled sections: **META** (branch, `version`, `target`, count), **CHANGESET** (author + subject per commit), **FULL BODIES**, **BODYLESS COMMITS — FILE STAT** (module resolved from files for `minor fix`/empty subjects), and **FORMAT REFERENCE** (last 3 `release-*` commits to mirror). It auto-detects target = `uat` if that branch exists else `main`, and `version` = current branch minus the `dev-` prefix (`dev-3.8` → `3.8`).

Do NOT hand-run ad-hoc `git log`/`git show` loops — they defeat the single-approval design. If the script is unavailable, everything it does is plain read-only git (`rev-parse`, `log`, `show --stat`, `show-ref`); reconstruct only as a fallback.

## 2. Subject
`release-<version>: <comma-list of 3–5 key aspects>`
- Key aspects = the headline modules/themes of the release, comma-separated, most significant first
- Tag qualifiers in parens only where they apply: `(WIP)` for not-yet-general-use. `(priority)` is for a hotfix's lead fix only — a regular release is just a collection of work and carries no priority tag; omit it
- **No trailing `(#PR)`** — GitHub appends the promotion PR number on squash-merge
- No type/scope prefix (that is `/commit`'s shape); the `release-<version>:` prefix replaces it

## 3. Body
`-` bullets, one per line (overrides `/commit`'s no-bullets rule).
- **One bullet per touched module/theme** — this is the coverage guarantee (breadth). Walk the whole changeset; every distinct area gets a bullet, nothing silently dropped.
- **Hard depth cap per bullet: 1–2 sentences.** Shape: `Module: the headline change + the why + the single load-bearing seam`. Stop there. A bullet that runs 4+ lines or names 5+ symbols has become a merged diff — cut it back to the seam.
- **At most 1–2 concrete identifiers per bullet**, and only the load-bearing one(s) (the type/flag/error-code the change turns on). NEVER a roster of handlers/components/files/request types — that is the per-file inventory `/commit` forbids on large diffs, and it applies here just as hard.
- **Order by significance**, most impactful module first. Never order or weight by commit volume — a one-commit contributor's module ranks by importance, not count. A hotfix release may lead with a `(priority)` bullet; a regular release leads with its biggest piece of work.
- Tag WIP modules inline: `forms (WIP, not yet general-use): …`
- Cluster issue refs at the bullet end: `(#124 #126)`
- **Minor or junk-subject commits** (`minor fix`, `wip`, `fixup`, `typo`, empty/bodyless) never get their own bullet. Resolve the module from the files they touch (`git show --stat`) and fold them silently into that module's bullet — change reflected, never dropped. Minor sibling changes fold into one trailing bullet, a bare list of names.

Aim: subject + 5–8 bullets — a target, not a cap; coverage wins. When the list runs long, merge sibling modules' bullets under their parent module, keeping every change covered. If a module did many distinct things, name the 2–3 that matter and stop.

## 4. Clarifying questions
Infer everything from the changeset and emit directly. Ask ONE question only when a real ambiguity blocks a correct message and the diff cannot resolve it (e.g. two equally headline modules, unclear WIP status).

## Never goes in
Inherits `/commit`'s list. Plus, specific to releases:
- `Co-authored-by:` trailers and the `(#PR)` suffix — GitHub adds both on squash-merge
- Intra-flow mechanics — "on step 2", "in the second wizard pane", "after clicking Next". Describe what shipped, not where in a flow it sits. `login echoes the username on step 2` → `login echoes the username`.

## Example
Generic shape — real module/folder names, concrete mechanisms, no product-domain specifics.

Subject:
```
release-<version>: auth session hardening, forms response storage (WIP), config write path, CI parallelisation
```
Body (flat, one bullet per line — coverage across every module, most significant first):
```
- Auth: an expired token previously returned an empty profile as 200 OK so the client stored a bogus identity; the endpoint requires authorization, an expired token yields 401 and the refresh interceptor engages. Callback verifies the returned account matches the user before pinning identity — a mismatched account returns a distinct error code instead of the alarming binding-conflict message.
- Forms (WIP, not yet general-use): response storage pivots from per-section documents to one per-assignment document, section resolved at read; oversize handled reactively by splitting on the store's size limit rather than capping in handlers.
- Config: expose the org write path so a setting can be enabled end-to-end; drop the redundant feature flag that silently gated it off.
- Repository: guard writes under an If-Match ETag and map a lost update to a concurrency-conflict response instead of last-write-wins (#124 #126).
- CI/tests/docs: build once and run test suites in parallel (wall-clock 4m→~15s); fold a shipped spec into its module README.
```

## Boundaries
Same as `/commit`, and also never tag, merge, or push.
