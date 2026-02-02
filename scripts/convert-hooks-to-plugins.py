#!/usr/bin/env python3
"""
Hook to OpenCode Plugin Converter

Converts Claude Code hooks (Python/Shell) to OpenCode TypeScript plugins.
Usage: python convert-hooks-to-plugins.py <hooks_dir> <output_dir>
"""

import json
import re
import sys
from pathlib import Path

# Hook type to OpenCode event mapping
HOOK_EVENT_MAP = {
    "PreToolUse": "tool.execute.before",
    "PostToolUse": "tool.execute.after",
    "SessionStart": "session.created",
    "Stop": "session.idle",
    "Compact": "session.compacted",
}

# Hook file to type mapping
HOOK_FILE_TYPE_MAP = {
    "bash-guard.py": ("PreToolUse", "Blocks destructive commands and enforces package manager"),
    "file-protect.py": ("PreToolUse", "Protects sensitive files from read/write"),
    "auto-format.sh": ("PostToolUse", "Auto-formats source files after edits"),
    "session-start.sh": ("SessionStart", "Loads GSD state and git status at session start"),
    "post-turn-verify.sh": ("Stop", "Runs code quality checks after each turn"),
    "post-turn-index.sh": ("Stop", "Triggers code graph indexing after changes"),
    "pre-compact-save.sh": ("Compact", "Saves state before context compaction"),
    "save-session-changes.sh": ("Stop", "Saves session changes to files"),
    "save-transcript.sh": ("Stop", "Saves conversation transcript"),
    "mcp-store-memory.sh": ("Stop", "Stores learnings to memory graph"),
    "stop-context-save.sh": ("Stop", "Saves context on session end"),
    "track-modifications.sh": ("PostToolUse", "Tracks file modifications"),
}


def extract_regex_patterns(content: str) -> list[dict]:
    """Extract regex patterns from Python hook files (e.g., DESTRUCTIVE_GIT, PKG_MANAGER_BLOCKS)."""
    patterns = []

    # Pattern 1: Simple list of tuples like DESTRUCTIVE_GIT = [(r"...", "..."), ...]
    pattern_lists = re.findall(r"(\w+)\s*=\s*\[(.*?)\]", content, re.DOTALL)
    for name, items in pattern_lists:
        tuples = re.findall(r'\(\s*r["\']([^"\']+)["\'],\s*["\']([^"\']+)["\']', items)
        for pattern, message in tuples:
            patterns.append({"pattern": pattern, "message": message, "group": name})

    # Pattern 2: Dict values like PKG_MANAGER_BLOCKS = {"uv": [...], ...}
    # Extract patterns from default key (uv) if DEFAULT_BLOCKS exists
    if "DEFAULT_BLOCKS" in content and "PKG_MANAGER_BLOCKS" in content:
        # Look for uv key patterns (default)
        uv_match = re.search(r'"uv":\s*\[(.*?)\]', content, re.DOTALL)
        if uv_match:
            tuples = re.findall(
                r'\(\s*r["\']([^"\']+)["\'],\s*["\']([^"\']+)["\']', uv_match.group(1)
            )
            for pattern, message in tuples:
                patterns.append({"pattern": pattern, "message": message, "group": "PKG_MANAGER"})

    return patterns


def extract_string_patterns(content: str) -> list[str]:
    """Extract simple string patterns (e.g., BLOCKED_PATTERNS)."""
    patterns = []
    match = re.search(r"BLOCKED_PATTERNS\s*=\s*\[(.*?)\]", content, re.DOTALL)
    if match:
        patterns = re.findall(r'["\']([^"\']+)["\']', match.group(1))
    return patterns


def to_plugin_name(name: str) -> str:
    """Convert hook name to plugin name (e.g., bash-guard -> BashGuard)."""
    return "".join(word.title() for word in name.replace("_", "-").split("-"))


def generate_regex_guard_plugin(name: str, patterns: list[dict], description: str) -> str:
    """Generate plugin using regex patterns (for bash-guard)."""
    plugin_name = to_plugin_name(name)

    # Group patterns
    groups = {}
    for p in patterns:
        g = p.get("group", "PATTERNS")
        if g not in groups:
            groups[g] = []
        groups[g].append(p)

    # Build const declarations
    const_decls = []
    for group_name, items in groups.items():
        lines = [f"const {group_name} = ["]
        for item in items:
            pat = item["pattern"]
            msg = item["message"].replace('"', '\\"')
            lines.append(f'  {{ pattern: /{pat}/, msg: "{msg}" }},')
        lines.append("]")
        const_decls.append("\n".join(lines))

    consts_str = "\n\n".join(const_decls)
    groups_list = ", ".join(groups.keys())

    return f"""/**
 * {plugin_name} Plugin for OpenCode
 * {description}
 * Converted from: .claude/hooks/{name}.py
 */
import type {{ Plugin }} from "@opencode-ai/plugin"

{consts_str}

export const {plugin_name}Plugin: Plugin = async () => ({{
  "tool.execute.before": async (input, output) => {{
    if (input.tool !== "bash") return
    const cmd = output.args?.command || ""

    for (const group of [{groups_list}]) {{
      for (const {{ pattern, msg }} of group) {{
        if (pattern.test(cmd)) {{
          throw new Error(`Blocked: ${{msg}}`)
        }}
      }}
    }}
  }},
}})
"""


def generate_string_guard_plugin(name: str, patterns: list[str], description: str) -> str:
    """Generate plugin using string includes() (for file-protect)."""
    plugin_name = to_plugin_name(name)
    patterns_json = json.dumps(patterns, indent=2)

    return f"""/**
 * {plugin_name} Plugin for OpenCode
 * {description}
 * Converted from: .claude/hooks/{name}.py
 */
import type {{ Plugin }} from "@opencode-ai/plugin"

const BLOCKED_PATTERNS = {patterns_json}

export const {plugin_name}Plugin: Plugin = async () => ({{
  "tool.execute.before": async (input, output) => {{
    if (!["read", "write", "edit"].includes(input.tool)) return
    const filePath = output.args?.filePath || output.args?.file_path || ""

    for (const pattern of BLOCKED_PATTERNS) {{
      if (filePath.includes(pattern)) {{
        throw new Error(`Protected: Cannot access files containing '${{pattern}}'`)
      }}
    }}
  }},
}})
"""


def generate_session_plugin(name: str, event: str, description: str) -> str:
    """Generate session event plugin."""
    plugin_name = to_plugin_name(name)

    return f'''/**
 * {plugin_name} Plugin for OpenCode
 * {description}
 * Converted from: .claude/hooks/{name}.sh
 */
import type {{ Plugin }} from "@opencode-ai/plugin"

export const {plugin_name}Plugin: Plugin = async ({{ $, directory }}) => ({{
  event: async ({{ event }}) => {{
    if (event.type !== "{event}") return

    try {{
      // TODO: Adapt shell logic to TypeScript
      console.log("[{name}] triggered:", event.type)
    }} catch (error) {{
      console.error("[{name}] Error:", error)
    }}
  }},
}})
'''


def generate_post_tool_plugin(name: str, description: str) -> str:
    """Generate PostToolUse plugin."""
    plugin_name = to_plugin_name(name)

    return f"""/**
 * {plugin_name} Plugin for OpenCode
 * {description}
 * Converted from: .claude/hooks/{name}.sh
 */
import type {{ Plugin }} from "@opencode-ai/plugin"

export const {plugin_name}Plugin: Plugin = async ({{ $ }}) => ({{
  "tool.execute.after": async (input, output) => {{
    if (!["edit", "write"].includes(input.tool)) return
    const filePath = input.args?.filePath || input.args?.file_path
    if (!filePath) return

    // TODO: Adapt shell logic
  }},
}})
"""


def convert_hook(hook_path: Path) -> tuple[str, str] | None:
    """Convert a single hook file to TypeScript plugin."""
    name = hook_path.stem
    if name.startswith("_"):
        return None

    content = hook_path.read_text(encoding="utf-8", errors="ignore")
    hook_type, description = HOOK_FILE_TYPE_MAP.get(
        hook_path.name, ("Stop", f"Converted from {hook_path.name}")
    )
    event = HOOK_EVENT_MAP.get(hook_type, "session.idle")

    if hook_path.suffix == ".py":
        regex_patterns = extract_regex_patterns(content)
        if regex_patterns:
            ts_code = generate_regex_guard_plugin(name, regex_patterns, description)
        else:
            string_patterns = extract_string_patterns(content)
            if string_patterns:
                ts_code = generate_string_guard_plugin(name, string_patterns, description)
            else:
                ts_code = generate_session_plugin(name, event, description)
    elif hook_type == "PostToolUse":
        ts_code = generate_post_tool_plugin(name, description)
    else:
        ts_code = generate_session_plugin(name, event, description)

    return (f"{name}.ts", ts_code)


def main():
    if len(sys.argv) < 3:
        print("Usage: python convert-hooks-to-plugins.py <hooks_dir> <output_dir>")
        sys.exit(1)

    hooks_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])

    if not hooks_dir.exists():
        print(f"Error: Hooks directory not found: {hooks_dir}")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    converted = []
    for hook_file in sorted(hooks_dir.iterdir()):
        if hook_file.suffix not in (".py", ".sh"):
            continue

        result = convert_hook(hook_file)
        if result:
            ts_name, ts_code = result
            (output_dir / ts_name).write_text(ts_code, encoding="utf-8")
            converted.append(ts_name)
            print(f"  [+] {hook_file.name} -> {ts_name}")

    # Generate index.ts
    index_lines = ["// Auto-generated plugin index\n"]
    for ts_name in converted:
        mod = ts_name.replace(".ts", "")
        plugin = to_plugin_name(mod) + "Plugin"
        index_lines.append(f'export {{ {plugin} }} from "./{mod}"')
    (output_dir / "index.ts").write_text("\n".join(index_lines), encoding="utf-8")
    print(f"  [+] index.ts ({len(converted)} plugins)")

    # Generate package.json
    pkg = {
        "name": "opencode-plugins",
        "type": "module",
        "dependencies": {"@opencode-ai/plugin": "latest"},
    }
    (output_dir.parent / "package.json").write_text(json.dumps(pkg, indent=2), encoding="utf-8")

    print(f"\n  Total: {len(converted)} converted")
    return 0


if __name__ == "__main__":
    sys.exit(main())
