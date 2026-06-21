import json
import sys

ALLOWED_GITHUB_REPOS = (
    "dotnet/roslyn",
    "dotnet/roslyn-analyzers",
)

GITHUB_CODE_PATH_SEGMENTS = ("blob", "tree", "raw")

ALLOWED_DOC_PREFIXES = (
    "https://code.claude.com/docs/en/",
)


def build_prefixes():
    prefixes = []
    for repo in ALLOWED_GITHUB_REPOS:
        prefixes.append(f"https://raw.githubusercontent.com/{repo}/")
        for segment in GITHUB_CODE_PATH_SEGMENTS:
            prefixes.append(f"https://github.com/{repo}/{segment}/")
    prefixes.extend(ALLOWED_DOC_PREFIXES)
    return tuple(prefixes)


ALLOWED_PREFIXES = build_prefixes()


def normalise(url):
    if url.startswith("http://"):
        return "https://" + url[len("http://"):]
    return url


def matches(url):
    for prefix in ALLOWED_PREFIXES:
        if url.startswith(prefix):
            return prefix
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return

    url = normalise(str(payload.get("tool_input", {}).get("url", "")))
    prefix = matches(url)
    if prefix is None:
        return

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": f"WebFetch code allowlist: {prefix}",
        }
    }))


main()
