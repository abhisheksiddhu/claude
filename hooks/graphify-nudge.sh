#!/usr/bin/env bash
[ -f graphify-out/graph.json ] || exit 0

mode=$1
input=$(cat)

emit() {
  jq -cn --arg e "$1" --arg m "$2" '{hookSpecificOutput:{hookEventName:$e,additionalContext:$m}}'
}

case "$mode" in
  session)
    emit SessionStart 'graphify: this repo has a knowledge graph at graphify-out/ and it is the source of truth. For any codebase question run `graphify query "<question>"`, `graphify explain "<concept>"` or `graphify path "<A>" "<B>"` before any Grep/Glob/Read discovery. Read raw files only to modify or debug specific code, or when the graph lacks the detail. Sub-agents do not inherit this: put the instruction in every spawn prompt that searches or explores.'
    ;;
  bash)
    cmd=$(printf '%s' "$input" | jq -r '(.tool_input // .).command // ""' 2>/dev/null)
    case "$cmd" in
      *grep*|*"rg "*|*ripgrep*|*"find "*|*"fd "*|*"ack "*|*"ag "*)
        emit PreToolUse 'graphify: knowledge graph at graphify-out/. For focused questions, run `graphify query "<question>"` (scoped subgraph, usually much smaller than GRAPH_REPORT.md) instead of grepping raw files. Read GRAPH_REPORT.md only for broad architecture context.'
        ;;
    esac
    ;;
  search)
    s=$(printf '%s' "$input" | jq -r '(.tool_input // .) | [.file_path, .pattern, .path] | map(. // "") | join(" ") | ascii_downcase | gsub("\\\\"; "/")' 2>/dev/null)
    case "$s" in
      *graphify-out/*) exit 0 ;;
      *)
        emit PreToolUse 'graphify: knowledge graph at graphify-out/. For codebase questions, run `graphify query "<question>"` (scoped subgraph, usually much smaller than searching files one by one), `graphify explain "<concept>"`, or `graphify path "<A>" "<B>"`, before Grep/Glob. Search raw files only to modify or debug specific code, or when the graph lacks the detail.'
        ;;
    esac
    ;;
esac

exit 0
