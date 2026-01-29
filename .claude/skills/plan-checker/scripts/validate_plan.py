#!/usr/bin/env python3
"""Validate PLAN.md YAML frontmatter and structural integrity.

Checks:
- Required frontmatter fields (phase, plan, wave, depends_on, files_modified, autonomous, must_haves)
- Task XML structure (<task>, <name>, <files>, <action>, <verify>, <done>)
- Task count (should be 2-3 per plan)
- Verification section existence

Usage:
    python3 scripts/validate_plan.py <plan_file>
    python3 scripts/validate_plan.py .gsd/phases/1/01-PLAN.md
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REQUIRED_FRONTMATTER = [
    "phase",
    "plan",
    "wave",
    "depends_on",
    "files_modified",
    "autonomous",
    "must_haves",
]
TASK_FIELDS = ["name", "files", "action", "verify", "done"]


def parse_frontmatter(content: str) -> tuple[dict, list[str]]:
    """Parse YAML frontmatter. Returns (fields_dict, errors)."""
    errors = []
    fields: dict = {}

    fm_match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not fm_match:
        return fields, ["No YAML frontmatter found (missing --- delimiters)"]

    fm_text = fm_match.group(1)
    for raw_line in fm_text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" in line:
            key = line.split(":")[0].strip()
            value = line.split(":", 1)[1].strip()
            fields[key] = value

    for field in REQUIRED_FRONTMATTER:
        if field not in fields:
            errors.append(f"Missing required frontmatter field: {field}")

    return fields, errors


def check_tasks(content: str) -> tuple[int, list[str]]:
    """Validate task XML structure. Returns (task_count, errors)."""
    errors = []

    tasks = re.findall(r"<task\b[^>]*>.*?</task>", content, re.DOTALL)
    task_count = len(tasks)

    if task_count == 0:
        errors.append("No <task> elements found")
        return 0, errors

    if task_count > 3:
        errors.append(f"Too many tasks ({task_count}). Maximum recommended: 3. Consider splitting.")

    for i, task_text in enumerate(tasks, 1):
        for field in TASK_FIELDS:
            if f"<{field}>" not in task_text:
                errors.append(f"Task {i}: Missing <{field}> element")
            else:
                # Check for empty fields
                field_match = re.search(rf"<{field}>(.*?)</{field}>", task_text, re.DOTALL)
                if field_match and not field_match.group(1).strip():
                    errors.append(f"Task {i}: Empty <{field}> element")

    return task_count, errors


def check_sections(content: str) -> list[str]:
    """Check for required plan sections."""
    errors = []
    required_sections = ["<objective>", "<context>", "<tasks>", "<verification>"]

    for section in required_sections:
        if section not in content.lower():
            errors.append(f"Missing section: {section}")

    return errors


def main() -> None:
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/validate_plan.py <plan_file>", file=sys.stderr)
        sys.exit(1)

    plan_path = Path(sys.argv[1])
    if not plan_path.exists():
        print(json.dumps({"error": f"File not found: {plan_path}"}))
        sys.exit(1)

    content = plan_path.read_text(encoding="utf-8")
    blockers = []
    warnings = []

    # Frontmatter
    fields, fm_errors = parse_frontmatter(content)
    blockers.extend(fm_errors)

    # Tasks
    task_count, task_errors = check_tasks(content)
    blockers.extend(task_errors)

    # Sections
    section_errors = check_sections(content)
    warnings.extend(section_errors)

    # Task count warning
    if task_count == 1:
        warnings.append("Only 1 task found. Consider if this is sufficient.")

    result = {
        "file": str(plan_path),
        "frontmatter_fields": list(fields.keys()),
        "task_count": task_count,
        "blockers": blockers,
        "warnings": warnings,
        "status": "BLOCKED" if blockers else ("WARNINGS" if warnings else "VALID"),
    }

    print(json.dumps(result, indent=2, ensure_ascii=False))

    if blockers:
        print(f"\nBLOCKED: {len(blockers)} blocker(s) found", file=sys.stderr)
        for b in blockers:
            print(f"  [BLOCKER] {b}", file=sys.stderr)
    if warnings:
        print(f"\nWARNINGS: {len(warnings)}", file=sys.stderr)
        for w in warnings:
            print(f"  [WARNING] {w}", file=sys.stderr)
    if not blockers and not warnings:
        print("\nVALID: Plan passes all checks", file=sys.stderr)

    sys.exit(1 if blockers else 0)


if __name__ == "__main__":
    main()
