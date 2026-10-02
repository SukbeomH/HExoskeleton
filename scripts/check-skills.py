#!/usr/bin/env python3
"""Check skills/*/SKILL.md frontmatter against the Agent Skills spec (stdlib only).

Fails if: name != directory name or not kebab-case (<=64), description empty or
>1024 chars, or a top-level key outside ALLOWED (exactly the spec set).
--claude-only also admits CLAUDE_ONLY, for skills that run only in Claude Code (plugins/router).
Usage: python3 scripts/check-skills.py [--claude-only] [skills-dir]
"""

import json
import pathlib
import re
import sys

ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
# The spec cannot keep the model from invoking a skill. router's `front` must be user-typed only (its hook
# registers the front), so the Claude-only router plugin may use this one Claude Code key; nothing else is admitted.
CLAUDE_ONLY = {"disable-model-invocation"}
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def frontmatter(text):
    """Return {top-level key: raw value text} — only what the checks need, not a YAML parser."""
    lines = text.split("\n")
    if lines[0] != "---" or "---" not in lines[1:]:
        raise ValueError("missing --- frontmatter")
    keys, cur = {}, None
    for line in lines[1 : lines.index("---", 1)]:
        m = re.match(r"^([A-Za-z0-9_-]+):(.*)$", line)
        if m:
            cur = m.group(1)
            if cur in keys:
                raise ValueError(f"duplicate key '{cur}'")
            keys[cur] = m.group(2).strip()
        elif cur and line.strip():
            keys[cur] += " " + line.strip()
    return keys


def scalar(raw):
    if raw.startswith('"'):
        return json.loads(raw)
    if raw.startswith("'") and raw.endswith("'"):
        return raw[1:-1].replace("''", "'")
    return raw


def main():
    args = sys.argv[1:]
    allowed = ALLOWED | CLAUDE_ONLY if "--claude-only" in args else ALLOWED
    args = [a for a in args if a != "--claude-only"]
    root = pathlib.Path(args[0] if args else pathlib.Path(__file__).parent.parent / "skills")
    errors, count = [], 0
    for skill in sorted(p for p in root.iterdir() if p.is_dir()):
        count += 1
        f = skill / "SKILL.md"
        try:
            fm = frontmatter(f.read_text())
            name, desc = scalar(fm.get("name", "")), scalar(fm.get("description", ""))
        except (OSError, ValueError) as e:
            errors.append(f"{f}: {e}")
            continue
        if name != skill.name or not NAME_RE.match(name) or len(name) > 64:
            errors.append(f"{f}: name '{name}' must equal directory '{skill.name}' (kebab-case, <=64)")
        if not 1 <= len(desc) <= 1024:
            errors.append(f"{f}: description length {len(desc)} not in 1..1024")
        unknown = sorted(set(fm) - allowed)
        if unknown:
            errors.append(f"{f}: unknown keys {unknown}")
    for e in errors:
        print("FAIL", e)
    print(f"{'FAIL' if errors else 'PASS'}: {count} skills checked, {len(errors)} problems")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
