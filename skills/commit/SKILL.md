---
name: commit
description: >
  Generate a commit message in the user's personal terse style. Conventional Commits, small by
  default, flat unwrapped body lines, scope = module/area name never a project name. Manual invoke only.
---

Write the commit message terse and exact. Conventional Commits. Why over what.

**Default is subject line only.** A body is the exception, not the norm. The recurring complaint is size: bodies come out far longer than wanted. When in doubt, ship the subject alone — a message that is too short is a smaller failure than one nobody reads.

Diff size does not justify a body. A 40-file refactor with an obvious purpose is still subject-only.

## Subject line
- `<type>(<scope>): <imperative summary>` — `<scope>` optional
- Types: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `style`, `revert`
- Imperative mood: "add", "fix", "remove" — not "added", "adds", "adding"
- ≤100 chars soft target, no hard cap. No trailing period
- Match the project's capitalisation convention after the colon
- **Scope is a module/area name** (`config`, `review`, `auditor`) — NEVER a project/`.csproj` name (`webhost`). Omit scope if no clean module fits

## Body — the exception

Before writing one, name the specific fact the body carries that the subject and the diff cannot. No such fact → no body.

Qualifying facts, and nothing else: a *why* a reader could not infer from the diff, a breaking change, a migration step, a security fix's impact, a revert's cause, an issue reference.

Does NOT qualify: what changed (the diff says), which files were touched, a list of the new types/methods/flags, how the change works, restating the subject at length, "this improves X".

- **Hard cap: 2 sentences, ~40 words.** Exceeding it means the extra material did not qualify — cut it, do not reflow it
- **One paragraph. No bullets** unless the user asks or there are genuinely 3+ independent breaking changes
- **NO line wrapping.** One paragraph per line, however long. Never soft-wrap at 72 — flat lines, matches the user's markdown style
- **Terse ≠ vague.** Squeeze words, not facts. On a small or bug-fix diff every concrete identifier (type/field/container name, root-cause mechanism) survives; only filler dies. On a large diff the facts are the why plus at most one load-bearing seam — never a per-file inventory
- Never enumerate sibling changes. They go in the diff, not the message
- Issue references go last, on their own line: `Closes #42`, `Refs #17`

## Never goes in
- "This commit does X", "I", "we", "now", "currently" — the diff says what
- "As requested by…" — use a `Co-authored-by` trailer
- "Generated with Claude Code" or any AI attribution
- Emoji, unless project convention requires
- Restating the file name when the scope already says it

## Always include a body for
Breaking changes, security fixes, data migrations, reverts. Never compress these to subject-only — future debuggers need the context. The 2-sentence cap still applies.

## Examples
Small fix — subject only:
```
fix(auditor): align Upload button height with Camera in evidence modal
```

Large feature, obvious purpose — still subject only:
```
feat(config): add single-entry org provisioning screens
```

Non-obvious why — one sentence, then stop:
```
fix(sync): retry queue drain on 429 with jittered backoff

Upstream rate-limits per-tenant, not per-key, so parallel workers collided and starved the smallest tenants.

Closes #128
```

Breaking change:
```
feat(api)!: rename /v1/orders to /v1/checkout

BREAKING CHANGE: clients on /v1/orders must migrate to /v1/checkout before 2026-06-01. Old route returns 410 after that date.
```

## Boundaries
Only generates the message — does not run `git commit`, stage, or amend. Output as a code block ready to paste.
