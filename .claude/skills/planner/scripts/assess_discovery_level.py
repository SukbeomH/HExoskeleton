#!/usr/bin/env python3
"""Assess discovery level for a planning task.

Analyzes task description and project context to determine the appropriate
discovery level (0-3) per GSD methodology.

Usage:
    python3 scripts/assess_discovery_level.py "<task_description>"
    python3 scripts/assess_discovery_level.py "Add JWT authentication to API endpoints"
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

# Keywords that indicate higher discovery levels
LEVEL_3_KEYWORDS = [
    "architecture",
    "design",
    "system",
    "migrate",
    "migration",
    "auth",
    "authentication",
    "authorization",
    "oauth",
    "database schema",
    "data model",
    "infrastructure",
    "microservice",
    "distributed",
    "event-driven",
]

LEVEL_2_KEYWORDS = [
    "choose",
    "select",
    "evaluate",
    "compare",
    "integrate",
    "integration",
    "external api",
    "third-party",
    "new library",
    "new package",
    "new dependency",
    "websocket",
    "graphql",
    "grpc",
    "queue",
    "cache",
]

LEVEL_1_KEYWORDS = [
    "upgrade",
    "update version",
    "syntax check",
    "single library",
    "confirm",
    "verify api",
]

LEVEL_0_PATTERNS = [
    r"\badd\s+(field|column|button|link|route)\b",
    r"\bcrud\b",
    r"\brefactor\b",
    r"\brename\b",
    r"\bdelete\s+(unused|old)\b",
    r"\bfix\s+(typo|style|format)\b",
]


def check_external_deps(description: str) -> bool:
    """Check if task likely requires new external dependencies."""
    dep_indicators = [
        "install",
        "add package",
        "new library",
        "npm install",
        "uv add",
        "pip install",
    ]
    return any(ind in description.lower() for ind in dep_indicators)


def check_existing_patterns(root: Path) -> dict:
    """Check what patterns already exist in the project."""
    patterns = {
        "has_tests": (root / "tests").is_dir(),
        "has_pyproject": (root / "pyproject.toml").is_file(),
        "has_package_json": (root / "package.json").is_file(),
        "has_docker": (root / "Dockerfile").is_file() or (root / "docker-compose.yml").is_file(),
    }

    # Check for existing auth patterns
    try:
        result = subprocess.run(
            ["grep", "-rl", "auth", str(root / "src"), str(root / "app")],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        patterns["has_auth"] = bool(result.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        patterns["has_auth"] = False

    return patterns


def assess(description: str, root: Path = Path(".")) -> dict:
    """Determine discovery level for the given task."""
    desc_lower = description.lower()
    reasons = []

    # Level 3 check
    level_3_hits = [kw for kw in LEVEL_3_KEYWORDS if kw in desc_lower]
    if level_3_hits:
        # Check if patterns already exist (might downgrade)
        patterns = check_existing_patterns(root)
        if "auth" in desc_lower and patterns.get("has_auth"):
            reasons.append("Auth patterns exist — downgraded from Level 3")
            level = 2
        else:
            reasons.append(f"Level 3 keywords: {', '.join(level_3_hits)}")
            level = 3
    # Level 2 check
    elif any(kw in desc_lower for kw in LEVEL_2_KEYWORDS) or check_external_deps(description):
        hits = [kw for kw in LEVEL_2_KEYWORDS if kw in desc_lower]
        reasons.append(f"Level 2 keywords: {', '.join(hits) or 'external dependency'}")
        level = 2
    # Level 1 check
    elif any(kw in desc_lower for kw in LEVEL_1_KEYWORDS):
        hits = [kw for kw in LEVEL_1_KEYWORDS if kw in desc_lower]
        reasons.append(f"Level 1 keywords: {', '.join(hits)}")
        level = 1
    # Level 0 check
    elif any(re.search(pat, desc_lower) for pat in LEVEL_0_PATTERNS):
        reasons.append("Matches Level 0 pattern (simple internal change)")
        level = 0
    else:
        reasons.append("No strong indicators — defaulting to Level 1")
        level = 1

    level_names = {
        0: "Skip (pure internal work)",
        1: "Quick Verification",
        2: "Standard Research",
        3: "Deep Dive",
    }

    actions = {
        0: "Proceed directly. All work follows established patterns.",
        1: "Quick docs check. No RESEARCH.md needed.",
        2: "Route to /research-phase. Produces RESEARCH.md.",
        3: "Full research with RESEARCH.md. Consider /research-phase first.",
    }

    return {
        "task": description,
        "level": level,
        "level_name": level_names[level],
        "action": actions[level],
        "reasons": reasons,
    }


def main() -> None:
    if len(sys.argv) < 2:
        print(
            'Usage: python3 scripts/assess_discovery_level.py "<task description>"', file=sys.stderr
        )
        sys.exit(1)

    description = " ".join(sys.argv[1:])
    result = assess(description)

    print(json.dumps(result, indent=2, ensure_ascii=False))
    print(f"\nDiscovery Level: {result['level']} — {result['level_name']}", file=sys.stderr)
    print(f"Action: {result['action']}", file=sys.stderr)


if __name__ == "__main__":
    main()
