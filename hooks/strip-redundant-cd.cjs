// PreToolUse hook: when a Bash/PowerShell command is needlessly prefixed with
// `cd <current working dir> && ...`, drop the prefix. The rewrite is always
// applied; the command is additionally auto-approved IF every segment of the
// inner command is something Claude Code already auto-allows on its own
// (read-only shell built-ins + git read-only subcommands). Anything else keeps
// the rewrite but goes through normal permission handling.
//
// Written in Node (not a shell/pwsh script) so it runs on any machine that can
// run Claude Code — Node is always present; PowerShell/bash may not be.
//
// The cd target is compared against the hook's own cwd, so there is no
// hardcoded repo path; it normalises backslash / forward-slash / git-bash
// (/c/...) forms. It grants NO new privilege — it only restores the auto-allow
// the redundant prefix broke. Execution vectors (dotnet/npm/npx/find -exec/
// xargs) are intentionally NOT in the safe set and still prompt normally.

const fs = require('fs');

// No stdout => normal permission flow runs on the original command.
const fallthrough = () => process.exit(0);

let raw = '';
try { raw = fs.readFileSync(0, 'utf8'); } catch { fallthrough(); }
if (!raw || !raw.trim()) fallthrough();

let data;
try { data = JSON.parse(raw); } catch { fallthrough(); }

const cmd = data && data.tool_input && data.tool_input.command;
if (!cmd || !cmd.trim()) fallthrough();

const normPath = (p) => {
  if (!p) return null;
  p = p.trim().replace(/^["']|["']$/g, '');
  const m = p.match(/^\/([A-Za-z])\/(.*)$/); // git-bash /c/x -> c:/x
  if (m) p = `${m[1]}:/${m[2]}`;
  return p.replace(/\\/g, '/').replace(/\/+$/, '');
};

const rootRaw = data.cwd || process.env.CLAUDE_PROJECT_DIR;
const root = normPath(rootRaw);
if (!root) fallthrough();

// Leading `cd [/d] <path> && ...` (or `; ...`, or newline-separated); path may
// be quoted or bare. `/d` is a cmd.exe-ism (switch drive) that is inert here but
// breaks the match; `-Path`/`-LiteralPath` are the PowerShell equivalents.
const CD = String.raw`(?:cd|chdir|sl|Set-Location)\s+(?:(?:\/d|-(?:Literal)?Path)\s+)?(?:"([^"]*)"|'([^']*)'|([^\s&;]+))`;
const lead = new RegExp(String.raw`^\s*${CD}\s*(?:&&|;|\r?\n)\s*([\s\S]+)$`, 'i');
// A cd with nothing after it: the whole command is the no-op, so it is replaced
// by the shell's own cwd echo rather than stripped to an empty command.
const solo = new RegExp(String.raw`^\s*${CD}\s*$`, 'i');

const m = cmd.match(lead) || cmd.match(solo);
if (!m) fallthrough();

const cdTarget = normPath((m[1] || '') + (m[2] || '') + (m[3] || ''));
const isPwsh = data.tool_name === 'PowerShell';
const inner = (m[4] || '').trim() || (isPwsh ? 'Get-Location' : 'pwd');
if (!cdTarget) fallthrough();

// Redundant only if the cd targets the cwd itself. Windows paths compare
// case-insensitively; POSIX paths case-sensitively.
const isWin = /^[A-Za-z]:/.test(root);
const same = isWin ? cdTarget.toLowerCase() === root.toLowerCase() : cdTarget === root;
if (!same) fallthrough();

// Anything below only decides auto-approval; the rewrite is emitted either way.
// Command substitution / multi-line bodies can't be reasoned about segment-by-
// segment, so they never auto-approve.
const opaque = inner.includes('$(') || inner.includes('`') || inner.includes('\n');

// Single-token commands Claude Code auto-allows unconditionally (no execution
// side-channel). Excludes find/xargs/sed (-exec / e / w channels) and all
// build/package/run commands. `graphify` writes only to graphify-out/ (the
// knowledge graph, rebuildable), never source — safe to include.
const singleSafe = new Set([
  'grep', 'egrep', 'fgrep', 'rg', 'ls', 'dir', 'cat', 'head', 'tail', 'wc', 'sort', 'uniq',
  'echo', 'jq', 'cut', 'tr', 'nl', 'date', 'tree', 'diff', 'cmp', 'which', 'type', 'printf',
  'basename', 'dirname', 'realpath', 'rev', 'tac', 'fold', 'column', 'comm', 'paste',
  'stat', 'strings', 'od', 'hexdump', 'readlink', 'seq',
  'pwd', 'get-location',
  'get-childitem', 'get-content', 'select-string', 'test-path', 'resolve-path',
  'graphify',
]);
// Two-token: git read-only subcommands (the set Claude Code auto-allows).
const multiSafe = new Set([
  'git diff', 'git log', 'git status', 'git show', 'git branch', 'git blame',
  'git remote', 'git rev-parse', 'git ls-files', 'git describe', 'git tag',
  'git shortlog', 'git reflog', 'git for-each-ref', 'git cat-file',
  'git worktree list', 'git stash list', 'git config',
]);

const segSafe = (seg) => {
  seg = seg.trim();
  if (seg === '') return true;
  const tokens = seg.split(/\s+/);
  let i = 0;
  while (i < tokens.length && /^[A-Za-z_][A-Za-z0-9_]*=/.test(tokens[i])) i++; // env prefixes
  if (i >= tokens.length) return false;
  const t0 = tokens[i].toLowerCase();
  const t1 = i + 1 < tokens.length ? tokens[i + 1].toLowerCase() : '';
  if (singleSafe.has(t0)) return true;
  if (t1 && multiSafe.has(`${t0} ${t1}`)) return true;
  return false;
};

const allSafe = !opaque && inner.split(/(?:&&|\|\||\||;)/).every(segSafe);

const out = {
  hookEventName: 'PreToolUse',
  updatedInput: { command: inner },
};
if (allSafe) {
  out.permissionDecision = 'allow';
  out.permissionDecisionReason = 'Stripped redundant cd into cwd; every segment is a read-only command Claude Code already auto-allows.';
}

process.stdout.write(JSON.stringify({ hookSpecificOutput: out }));
process.exit(0);
