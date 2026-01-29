#!/usr/bin/env python3
"""Convert PLAN.md to JSON format for automation and PRD integration.

Usage:
    python3 scripts/plan_to_json.py <plan_file>
    python3 scripts/plan_to_json.py .gsd/phases/1/01-PLAN.md
    python3 scripts/plan_to_json.py .gsd/phases/1/01-PLAN.md --output plan.json
    python3 scripts/plan_to_json.py .gsd/phases/1/ --all  # Convert all plans in directory

Output: JSON structure compatible with prd-active.json task format.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

# YAML frontmatter pattern
FRONTMATTER_PATTERN = re.compile(r"^---\n(.*?)\n---", re.DOTALL)

# Task block pattern
TASK_PATTERN = re.compile(
    r'<task\s+type=["\'](\w+)["\']>\s*'
    r"<name>(.*?)</name>\s*"
    r"<files>(.*?)</files>\s*"
    r"<action>(.*?)</action>\s*"
    r"<verify>(.*?)</verify>\s*"
    r"<done>(.*?)</done>\s*"
    r"</task>",
    re.DOTALL,
)

# Sections pattern
OBJECTIVE_PATTERN = re.compile(r"<objective>(.*?)</objective>", re.DOTALL)
CONTEXT_PATTERN = re.compile(r"<context>(.*?)</context>", re.DOTALL)
VERIFICATION_PATTERN = re.compile(r"<verification>(.*?)</verification>", re.DOTALL)
SUCCESS_PATTERN = re.compile(r"<success_criteria>(.*?)</success_criteria>", re.DOTALL)


def _parse_yaml_value(value: str) -> Any:
    """Parse a single YAML value."""
    if value.startswith("[") and value.endswith("]"):
        items = value[1:-1].split(",")
        return [item.strip().strip('"').strip("'") for item in items if item.strip()]
    if value.lower() in ("true", "false"):
        return value.lower() == "true"
    if value.isdigit():
        return int(value)
    return value.strip('"').strip("'")


def _process_yaml_line(
    raw_line: str,
    result: dict[str, Any],
    current_key: str | None,
    current_list: list[str],
) -> tuple[str | None, list[str]]:
    """Process a single YAML line and return updated state."""
    stripped = raw_line.rstrip()
    if not stripped:
        return current_key, current_list

    # List item
    if stripped.startswith("  - "):
        if current_key:
            current_list.append(stripped[4:].strip().strip('"').strip("'"))
        return current_key, current_list

    # Key-value pair
    if ":" in stripped:
        if current_key and current_list:
            result[current_key] = current_list
            current_list = []

        key, _, value = stripped.partition(":")
        key = key.strip()
        value = value.strip()

        if value:
            result[key] = _parse_yaml_value(value)
            return None, []
        return key, []

    return current_key, current_list


def parse_yaml_frontmatter(content: str) -> dict[str, Any]:
    """Parse YAML frontmatter from PLAN.md."""
    match = FRONTMATTER_PATTERN.match(content)
    if not match:
        return {}

    yaml_content = match.group(1)
    result: dict[str, Any] = {}
    current_key: str | None = None
    current_list: list[str] = []

    for raw_line in yaml_content.split("\n"):
        current_key, current_list = _process_yaml_line(raw_line, result, current_key, current_list)

    if current_key and current_list:
        result[current_key] = current_list

    return result


def parse_tasks(content: str) -> list[dict[str, Any]]:
    """Extract tasks from PLAN.md content."""
    tasks = []

    for match in TASK_PATTERN.finditer(content):
        task_type, name, files, action, verify, done = match.groups()

        # Parse files list
        files_list = [f.strip() for f in files.strip().split("\n") if f.strip()]
        if len(files_list) == 1 and "," in files_list[0]:
            files_list = [f.strip() for f in files_list[0].split(",")]

        tasks.append(
            {
                "type": task_type.strip(),
                "name": name.strip(),
                "files": files_list,
                "action": action.strip(),
                "verify": verify.strip(),
                "done": done.strip(),
            }
        )

    return tasks


def extract_section(content: str, pattern: re.Pattern) -> str:
    """Extract a section from content."""
    match = pattern.search(content)
    return match.group(1).strip() if match else ""


def extract_checklist(content: str) -> list[str]:
    """Extract checklist items from content."""
    items = []
    for raw_line in content.split("\n"):
        stripped = raw_line.strip()
        if stripped.startswith("- [ ]") or stripped.startswith("- [x]"):
            items.append(stripped[6:].strip())
    return items


def parse_plan(file_path: Path) -> dict[str, Any]:
    """Parse a PLAN.md file into structured JSON."""
    content = file_path.read_text(encoding="utf-8")

    # Parse frontmatter
    frontmatter = parse_yaml_frontmatter(content)

    # Parse sections
    objective = extract_section(content, OBJECTIVE_PATTERN)
    context = extract_section(content, CONTEXT_PATTERN)
    verification = extract_section(content, VERIFICATION_PATTERN)
    success_criteria = extract_section(content, SUCCESS_PATTERN)

    # Parse tasks
    tasks = parse_tasks(content)

    # Build plan ID
    phase = frontmatter.get("phase", 0)
    plan = frontmatter.get("plan", 0)
    plan_id = f"{phase}.{plan}"

    # Extract title from first heading after frontmatter
    title_match = re.search(r"^#\s+(?:Plan\s+\d+\.\d+:\s+)?(.+)$", content, re.MULTILINE)
    title = title_match.group(1).strip() if title_match else f"Plan {plan_id}"

    return {
        "id": plan_id,
        "title": title,
        "phase": phase,
        "plan": plan,
        "wave": frontmatter.get("wave", 1),
        "depends_on": frontmatter.get("depends_on", []),
        "files_modified": frontmatter.get("files_modified", []),
        "autonomous": frontmatter.get("autonomous", True),
        "user_setup": frontmatter.get("user_setup", []),
        "must_haves": frontmatter.get("must_haves", {}),
        "objective": objective,
        "context": context,
        "tasks": tasks,
        "verification": extract_checklist(verification),
        "success_criteria": extract_checklist(success_criteria),
        "source_file": str(file_path),
        "parsed_at": datetime.now().isoformat(),
    }


def convert_to_prd_tasks(plan: dict[str, Any]) -> list[dict[str, Any]]:
    """Convert plan tasks to PRD-compatible task format."""
    prd_tasks = []
    plan_id = plan["id"]

    for idx, task in enumerate(plan["tasks"], 1):
        task_id = f"TASK-{plan_id.replace('.', '')}-{idx:02d}"

        prd_tasks.append(
            {
                "id": task_id,
                "plan_ref": f"{plan_id}.{idx}",
                "title": task["name"],
                "type": task["type"],
                "files": task["files"],
                "action": task["action"],
                "verify": task["verify"],
                "done_criteria": task["done"],
                "status": "pending",
                "commit": None,
                "created_at": datetime.now().isoformat(),
            }
        )

    return prd_tasks


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert PLAN.md to JSON format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s .gsd/phases/1/01-PLAN.md
  %(prog)s .gsd/phases/1/01-PLAN.md --output plan.json
  %(prog)s .gsd/phases/1/ --all
  %(prog)s .gsd/phases/1/01-PLAN.md --prd-format
        """,
    )
    parser.add_argument("path", help="PLAN.md file or directory")
    parser.add_argument("-o", "--output", help="Output file (default: stdout)")
    parser.add_argument("--all", action="store_true", help="Convert all PLAN.md files in directory")
    parser.add_argument(
        "--prd-format",
        action="store_true",
        help="Output in PRD task format (for prd-active.json)",
    )
    parser.add_argument("--compact", action="store_true", help="Compact JSON output")

    args = parser.parse_args()
    path = Path(args.path)

    if not path.exists():
        print(f"Error: {path} does not exist", file=sys.stderr)
        sys.exit(1)

    # Collect files to process
    files: list[Path] = []
    if path.is_file():
        files = [path]
    elif path.is_dir() and args.all:
        files = sorted(path.glob("**/PLAN.md")) + sorted(path.glob("**/*-PLAN.md"))
    else:
        print("Error: Specify a file or use --all for directories", file=sys.stderr)
        sys.exit(1)

    if not files:
        print(f"No PLAN.md files found in {path}", file=sys.stderr)
        sys.exit(1)

    # Parse all plans
    results = []
    for file in files:
        try:
            plan = parse_plan(file)
            if args.prd_format:
                results.extend(convert_to_prd_tasks(plan))
            else:
                results.append(plan)
        except Exception as e:
            print(f"Error parsing {file}: {e}", file=sys.stderr)
            continue

    # Output
    output = results[0] if len(results) == 1 and not args.all else results
    indent = None if args.compact else 2
    json_output = json.dumps(output, indent=indent, ensure_ascii=False)

    if args.output:
        Path(args.output).write_text(json_output, encoding="utf-8")
        print(f"Written to {args.output}", file=sys.stderr)
    else:
        print(json_output)


if __name__ == "__main__":
    main()
