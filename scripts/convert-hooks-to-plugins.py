#!/usr/bin/env python3
"""Convert Claude Code hooks to OpenCode TypeScript plugin stubs.

Usage:
  python3 convert-hooks-to-plugins.py <hooks_src_dir> <plugins_dst_dir>

Each Claude Code hook is mapped to the equivalent OpenCode plugin event
and a TypeScript stub is generated that wraps the original shell script.
"""

import os
import sys

# Claude Code event → OpenCode event mapping
EVENT_MAP = {
    "SessionStart":  "session.created",
    "PreToolUse":    "tool.execute.before",
    "PostToolUse":   "tool.execute.after",
    "Stop":          "session.idle",
    "SessionEnd":    "session.idle",
    "PreCompact":    "session.idle",
}

# Hook filename → (Claude event, description)
HOOK_META = {
    "bash-guard.py":           ("PreToolUse",  "Block dangerous bash commands (force push, rm -rf, etc.)"),
    "file-protect.py":         ("PreToolUse",  "Protect sensitive files (.env, credentials, secrets)"),
    "auto-format.sh":          ("PostToolUse", "Auto-format Python files after edit"),
    "track-modifications.sh":  ("PostToolUse", "Track file modifications for session summary"),
    "pre-compact-save.sh":     ("PreCompact",  "Save context state before compaction"),
    "session-start.sh":        ("SessionStart","Initialize session: load STATE.md, inject git status"),
    "post-turn-verify.sh":     ("Stop",        "Verify task completion after each turn"),
    "stop-context-save.sh":    ("Stop",        "Save context and memory on session stop"),
    "save-session-changes.sh": ("SessionEnd",  "Record changed files on session end"),
    "save-transcript.sh":      ("SessionEnd",  "Save conversation transcript on session end"),
}

# Skip these utility scripts — not event hooks
SKIP_FILES = {
    "md-store-memory.sh",
    "md-recall-memory.sh",
    "_json_parse.sh",
    "scaffold-gsd.sh",
    "scaffold-hxsk.sh",
    "scaffold-infra.sh",
    "compact-context.sh",
    "organize-docs.sh",
}


def to_camel(name: str) -> str:
    base = os.path.splitext(name)[0]
    return "".join(p.capitalize() for p in base.replace("-", "_").split("_")) + "Plugin"


def oc_event_to_name(oc_event: str) -> str:
    return "".join(p.capitalize() for p in oc_event.replace(".", "-").split("-")) + "Plugin"


def generate_plugin(oc_event: str, hooks: list) -> str:
    """Generate a TypeScript plugin stub for one OpenCode event group."""
    claude_event = hooks[0][1]
    hook_comments = "\n".join(
        f" *   - {fname}: {desc}" for fname, _, desc in hooks
    )
    script_execs = "\n".join(
        f"    // await $`bash ${{import.meta.dir}}/../../scripts/{fname}`"
        for fname, _, _ in hooks
    )
    plugin_name = oc_event_to_name(oc_event)

    return f"""import type {{ Plugin }} from "@opencode-ai/plugin"

/**
 * Claude Code event : {claude_event}
 * OpenCode event    : {oc_event}
 *
 * Converted hooks:
{hook_comments}
 *
 * Original scripts are in scripts/ directory.
 * See MIGRATION-GUIDE.md for conversion patterns.
 */
export const {plugin_name}: Plugin = async ({{ $ }}) => ({{
  "{oc_event}": async (input: unknown, _output: unknown) => {{
{script_execs}
  }},
}})
"""


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: convert-hooks-to-plugins.py <hooks_dir> <plugins_dir>")
        return 1

    hooks_src = sys.argv[1]
    plugins_dst = sys.argv[2]

    if not os.path.isdir(hooks_src):
        print(f"Error: hooks directory not found: {hooks_src}")
        return 1

    os.makedirs(plugins_dst, exist_ok=True)

    # Group hooks by OpenCode event
    groups: dict[str, list] = {}
    unclassified: list[str] = []

    for fname in sorted(os.listdir(hooks_src)):
        if fname in SKIP_FILES or fname.startswith("_"):
            continue
        if not (fname.endswith(".sh") or fname.endswith(".py")):
            continue

        meta = HOOK_META.get(fname)
        if meta:
            claude_event, desc = meta
            oc_event = EVENT_MAP[claude_event]
            groups.setdefault(oc_event, []).append((fname, claude_event, desc))
        else:
            unclassified.append(fname)

    # Write one .ts file per OpenCode event
    count = 0
    for oc_event, hooks in sorted(groups.items()):
        plugin_filename = oc_event.replace(".", "-") + ".ts"
        out_path = os.path.join(plugins_dst, plugin_filename)
        content = generate_plugin(oc_event, hooks)
        with open(out_path, "w") as f:
            f.write(content)
        hook_names = ", ".join(h[0] for h in hooks)
        print(f"  [+] {plugin_filename} ({len(hooks)} hooks: {hook_names})")
        count += 1

    if unclassified:
        print(f"  [?] Unclassified (skipped): {', '.join(unclassified)}")

    print(f"  Total: {count} plugin files generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
