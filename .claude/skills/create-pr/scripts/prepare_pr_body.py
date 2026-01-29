#!/usr/bin/env python3
"""Generate structured PR body from git log and diff stats.

Produces a markdown PR body with summary, changes, and test plan sections
following the GSD PR template.

Usage:
    python3 scripts/prepare_pr_body.py [base_branch]
    python3 scripts/prepare_pr_body.py main
"""

from __future__ import annotations

import subprocess
import sys


def run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return result.stdout.strip()


def detect_base_branch() -> str:
    """Detect the base branch (main or master)."""
    branches = run(["git", "branch", "--list"]).splitlines()
    branch_names = [b.strip().lstrip("* ") for b in branches]
    if "main" in branch_names:
        return "main"
    if "master" in branch_names:
        return "master"
    return "main"


def main() -> None:
    base = sys.argv[1] if len(sys.argv) > 1 else detect_base_branch()
    _current = run(["git", "branch", "--show-current"])  # noqa: F841

    # Commits
    commits = run(["git", "log", f"{base}..HEAD", "--oneline"]).splitlines()
    if not commits:
        print("No commits found between {} and HEAD".format(base), file=sys.stderr)
        sys.exit(1)

    # Diff stats
    stat = run(["git", "diff", f"{base}...HEAD", "--stat"])
    changed_files = run(["git", "diff", f"{base}...HEAD", "--name-only"]).splitlines()

    # Classify changes
    feat_commits = [c for c in commits if "feat" in c.lower()]
    fix_commits = [c for c in commits if "fix" in c.lower()]
    other_commits = [c for c in commits if c not in feat_commits and c not in fix_commits]

    # Detect test files
    test_files = [f for f in changed_files if "test" in f.lower()]
    source_files = [f for f in changed_files if f not in test_files]

    # Generate summary bullets
    summary_lines = []
    if feat_commits:
        summary_lines.append(f"- Add {len(feat_commits)} new feature(s)")
    if fix_commits:
        summary_lines.append(f"- Fix {len(fix_commits)} issue(s)")
    if other_commits:
        summary_lines.append(f"- {len(other_commits)} other change(s)")
    summary = "\n".join(summary_lines) if summary_lines else "- Changes in this PR"

    # Generate body
    body = f"""## Summary
{summary}

## Changes
{stat}

### Commits ({len(commits)})
"""
    for c in commits:
        body += f"- {c}\n"

    body += f"""
### Files Changed ({len(changed_files)})
"""
    for f in source_files[:20]:
        body += f"- `{f}`\n"
    if test_files:
        body += "\n### Tests\n"
        for f in test_files:
            body += f"- `{f}`\n"

    body += """
## Test plan
- [ ] All existing tests pass
- [ ] New tests added for changed functionality
- [ ] Manual verification completed
"""

    # GSD context
    gsd_spec = run(["git", "log", f"{base}..HEAD", "--grep=phase", "--oneline"])
    if gsd_spec:
        body += f"""
## GSD Context
```
{gsd_spec}
```
"""

    print(body)


if __name__ == "__main__":
    main()
