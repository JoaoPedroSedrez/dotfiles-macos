"""Shared detection logic for the block-git-rewrites hooks (Claude/Codex/Gemini).

Blocks dangerous git commands: amend, force push, git add -A,
and gh pr merge. Most blocks are overridable: prefixing the command with
OVERRIDE_MARKER (only when the user explicitly approved the action in
conversation) lets the tool-specific adapter escalate or allow it.
git add -A/--all is never overridable.

This lives in claude/hooks as the canonical copy; the Codex hook is a symlink
to the adapter here, and the Gemini adapter imports this module by path.
"""

import re

OVERRIDE_MARKER = "EXPLICITLY_USER_APPROVED_HOOK_OVERRIDE=1"

# Regex pattern for git with optional global options before subcommand
# Matches: git push, git -C /path push, git --git-dir=/path push
# Does NOT match: git stash push, git log | grep push
# Options can be: -X, -X value, --long, --long=value
_GIT_OPT = r"(?:-[a-zA-Z](?:\s+[^-\s]\S*)?|--[\w-]+(?:=\S+)?)"
_GIT_OPTS = rf"(?:\s+{_GIT_OPT})*"  # zero or more option groups
_GIT_CMD = rf"\bgit\b{_GIT_OPTS}\s+"  # git followed by options then space

# Patterns to block dangerous git commands: (pattern, message, overridable)
BLOCKED_PATTERNS = [
    (rf"{_GIT_CMD}commit\b.*--amend\b", "git commit --amend is not allowed", True),
    (rf"{_GIT_CMD}push\b.*--force\b", "git push --force is not allowed", True),
    (rf"{_GIT_CMD}push\b.*-f\b", "git push -f (force) is not allowed", True),
    (rf"{_GIT_CMD}push\b.*--force-with-lease\b", "git push --force-with-lease is not allowed", True),
    (rf"{_GIT_CMD}add\b.*-A\b", "git add -A is not allowed - add files explicitly to avoid adding unrelated untracked files", False),
    (rf"{_GIT_CMD}add\b.*--all\b", "git add --all is not allowed - add files explicitly to avoid adding unrelated untracked files", False),
    (r"\bgh\s+pr\s+merge\b", "gh pr merge is not allowed - the user must merge PRs themselves, never the agent", True),
]

def strip_quoted_strings(command: str) -> str:
    """Remove quoted strings and heredocs to avoid false positives.

    This prevents matching 'git push' inside commit messages, PR bodies, etc.
    """
    # Remove heredocs: $(cat <<'EOF' ... EOF) or $(cat <<EOF ... EOF)
    result = re.sub(
        r"\$\(cat\s*<<'?(\w+)'?\s*\n.*?\n\s*\1\s*\)",
        " ",
        command,
        flags=re.DOTALL,
    )

    # Remove double-quoted strings (handling escaped quotes)
    result = re.sub(r'"(?:[^"\\]|\\.)*"', " ", result)

    # Remove single-quoted strings (no escaping in single quotes)
    result = re.sub(r"'[^']*'", " ", result)

    return result


def check_blocked_patterns(command: str) -> tuple[str, bool] | None:
    """Check if command matches any blocked pattern.

    Returns (error message, overridable) if blocked, None if allowed.
    """
    for pattern, message, overridable in BLOCKED_PATTERNS:
        if re.search(pattern, command, re.IGNORECASE):
            return message, overridable
    return None


def split_shell_commands(command: str) -> list[str]:
    """Split a shell command string on command separators.

    Splits on &&, ||, ;, and | to handle each command individually.
    This ensures 'git push && other' doesn't treat '&& other' as push args.
    """
    # Split on shell command separators, keeping it simple
    # This handles: cmd1 && cmd2, cmd1 || cmd2, cmd1 ; cmd2, cmd1 | cmd2
    parts = re.split(r"\s*(?:&&|\|\||[;|])\s*", command)
    return [p.strip() for p in parts if p.strip()]


def check_command(command: str) -> tuple[str, bool] | None:
    """Check a shell command for dangerous git operations.

    Returns (error message, overridable) if blocked, None if allowed.
    A non-overridable violation anywhere in the command wins over an
    overridable one, so a chained command can't ride an override past
    a hard block (e.g. "MARKER git commit --amend && git add -A").
    """
    stripped = strip_quoted_strings(command)
    first_overridable: tuple[str, bool] | None = None

    # Split on shell separators and check each command individually
    for cmd in split_shell_commands(stripped):
        result = check_blocked_patterns(cmd)
        if result:
            if not result[1]:
                return result
            first_overridable = first_overridable or result

    return first_overridable


def has_override(command: str) -> bool:
    """Check if the command carries the user-approved override marker."""
    return OVERRIDE_MARKER in command


def override_hint() -> str:
    """Standard hint appended to block messages for overridable rules."""
    return (
        f"\nIf (and only if) the user has explicitly approved this exact action, "
        f"re-run the command prefixed with {OVERRIDE_MARKER} to override this block."
    )
