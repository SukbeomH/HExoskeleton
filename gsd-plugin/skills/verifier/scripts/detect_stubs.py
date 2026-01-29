#!/usr/bin/env python3
"""Detect stub implementations in Python source files.

Scans for patterns that indicate incomplete implementations:
- `pass` in function/method bodies
- `raise NotImplementedError`
- `TODO`, `FIXME`, `HACK` comments
- `...` (Ellipsis) as function body

Usage:
    python3 scripts/detect_stubs.py [path] [--json]
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

STUB_PATTERNS = [
    (re.compile(r"^\s+pass\s*$"), "pass-body"),
    (re.compile(r"raise\s+NotImplementedError"), "not-implemented"),
    (re.compile(r"#\s*(TODO|FIXME|HACK|XXX)\b", re.IGNORECASE), "todo-comment"),
    (re.compile(r"^\s+\.\.\.\s*$"), "ellipsis-body"),
]

SKIP_DIRS = frozenset(
    (
        ".venv",
        "__pycache__",
        ".git",
        "node_modules",
        ".mypy_cache",
        ".ruff_cache",
        ".pytest_cache",
    )
)


class DocstringTracker:
    """Tracks whether current line is inside a docstring."""

    def __init__(self) -> None:
        self.in_docstring = False
        self.quote_char: str | None = None

    def update(self, line: str) -> bool:
        """Update state and return True if line is inside docstring."""
        for quote in ('"""', "'''"):
            count = line.count(quote)
            if count == 0:
                continue
            if not self.in_docstring:
                self.in_docstring = True
                self.quote_char = quote
                if count >= 2 or (count == 1 and line.endswith(quote) and len(line) > 3):
                    self.in_docstring = False
                    self.quote_char = None
            elif self.quote_char == quote:
                self.in_docstring = False
                self.quote_char = None
            break
        return self.in_docstring


def scan_file(filepath: Path) -> list[dict[str, str | int]]:
    findings: list[dict[str, str | int]] = []
    try:
        lines = filepath.read_text(encoding="utf-8").splitlines()
    except (UnicodeDecodeError, PermissionError):
        return findings

    tracker = DocstringTracker()
    for line_no, line in enumerate(lines, 1):
        stripped = line.strip()
        if tracker.update(stripped):
            continue
        for pattern, stub_type in STUB_PATTERNS:
            if pattern.search(line):
                findings.append(
                    {
                        "file": str(filepath),
                        "line": line_no,
                        "type": stub_type,
                        "content": stripped,
                    }
                )
    return findings


def scan_directory(root: Path) -> list[dict[str, str | int]]:
    findings: list[dict[str, str | int]] = []
    for py_file in sorted(root.rglob("*.py")):
        if SKIP_DIRS & set(py_file.parts):
            continue
        findings.extend(scan_file(py_file))
    return findings


def main() -> None:
    target = (
        Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("-") else Path(".")
    )
    output_json = "--json" in sys.argv

    if target.is_file():
        findings = scan_file(target)
    else:
        findings = scan_directory(target)

    # Separate TODO comments from actual stubs
    stubs = [f for f in findings if f["type"] not in ("todo-comment",)]
    todos = [f for f in findings if f["type"] == "todo-comment"]

    result = {
        "total_findings": len(findings),
        "stubs": len(stubs),
        "todos": len(todos),
        "status": "STUBS_FOUND" if stubs else "CLEAN",
        "findings": findings,
    }

    if output_json:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        if stubs:
            print(f"STUBS_FOUND: {len(stubs)} stub implementation(s)")
            for f in stubs:
                print(f"  {f['file']}:{f['line']}: [{f['type']}] {f['content']}")
        else:
            print("CLEAN: No stub implementations found")

        if todos:
            print(f"\nTODO_COMMENTS: {len(todos)}")
            for f in todos:
                print(f"  {f['file']}:{f['line']}: {f['content']}")

    sys.exit(1 if stubs else 0)


if __name__ == "__main__":
    main()
