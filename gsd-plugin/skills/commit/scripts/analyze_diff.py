#!/usr/bin/env python3
"""Analyze git diff for logical split candidates.

Detects when staged changes span multiple unrelated concerns and suggests
splitting into separate commits.

Usage:
    python3 scripts/analyze_diff.py [--staged]
"""

from __future__ import annotations

import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.stdout.strip()


def classify_file(path: str) -> str:
    """Classify a file by its role."""
    p = Path(path)
    name = p.name.lower()
    parts = p.parts

    if any(t in parts for t in ("tests", "test", "__tests__")):
        return "test"
    if any(t in parts for t in ("docs", "doc")):
        return "docs"
    if name in (
        "pyproject.toml",
        "package.json",
        "cargo.toml",
        "go.mod",
        "uv.lock",
        "package-lock.json",
        "requirements.txt",
        "setup.py",
        "setup.cfg",
    ):
        return "deps"
    if name.startswith(".") or name in (
        "makefile",
        "dockerfile",
        "docker-compose.yml",
        ".gitignore",
        ".env.example",
    ):
        return "config"
    if p.suffix in (".md", ".rst", ".txt"):
        return "docs"
    if name.endswith((".yml", ".yaml", ".json", ".toml")) and "src" not in parts:
        return "config"
    return "source"


def get_module(path: str) -> str:
    """Extract top-level module from a source path."""
    parts = Path(path).parts
    # Skip common prefixes
    for skip in ("src", "lib", "app"):
        if skip in parts:
            idx = parts.index(skip)
            if idx + 1 < len(parts):
                return parts[idx + 1]
    return parts[0] if parts else "root"


def analyze(staged: bool = True) -> dict:
    cmd = ["git", "diff", "--name-only"]
    if staged:
        cmd.append("--cached")

    files = [f for f in run(cmd).splitlines() if f.strip()]
    if not files:
        return {"splits": [], "total_files": 0, "recommendation": "NO_CHANGES"}

    # Group by category
    categories: dict[str, list[str]] = defaultdict(list)
    modules: dict[str, list[str]] = defaultdict(list)

    for f in files:
        cat = classify_file(f)
        categories[cat].append(f)
        if cat == "source":
            mod = get_module(f)
            modules[mod].append(f)

    # Detect splits
    splits = []
    for cat, cat_files in sorted(categories.items()):
        if cat == "source" and len(modules) > 1:
            for mod, mod_files in sorted(modules.items()):
                splits.append(
                    {
                        "type": "source",
                        "scope": mod,
                        "files": mod_files,
                        "suggested_prefix": f"feat({mod})" if cat == "source" else cat,
                    }
                )
        elif cat != "source":
            prefix_map = {
                "test": "test",
                "docs": "docs",
                "deps": "chore(deps)",
                "config": "chore",
            }
            splits.append(
                {
                    "type": cat,
                    "scope": cat,
                    "files": cat_files,
                    "suggested_prefix": prefix_map.get(cat, cat),
                }
            )

    # If source has only one module, keep it as single
    if len(modules) <= 1 and "source" in categories:
        mod_name = next(iter(modules.keys()), "root")
        splits = [s for s in splits if s["type"] != "source"]
        splits.insert(
            0,
            {
                "type": "source",
                "scope": mod_name,
                "files": categories["source"],
                "suggested_prefix": f"feat({mod_name})",
            },
        )

    recommendation = "SPLIT" if len(splits) > 1 else "SINGLE"

    return {
        "total_files": len(files),
        "categories": {k: len(v) for k, v in categories.items()},
        "splits": splits,
        "recommendation": recommendation,
    }


def main() -> None:
    staged = "--staged" in sys.argv or len(sys.argv) == 1
    result = analyze(staged=staged)
    print(json.dumps(result, indent=2, ensure_ascii=False))

    if result["recommendation"] == "SPLIT":
        print(f"\n# Suggested split into {len(result['splits'])} commits:", file=sys.stderr)
        for i, s in enumerate(result["splits"], 1):
            print(f"  {i}. {s['suggested_prefix']}: {len(s['files'])} file(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
