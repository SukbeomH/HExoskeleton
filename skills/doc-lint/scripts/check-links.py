#!/usr/bin/env python3
"""Report relative markdown links whose target file does not exist (stdlib only).

Checks [text](target) and ![alt](target) in the given .md files, or in every
git-tracked *.md file of the current directory. Skips URLs (http:, mailto:, …),
anchor-only links (#section), ${VAR} templates and fenced code blocks; for
file.md#section only the file is checked.
Usage: python3 check-links.py [file.md ...]   → exit 1 if any link is broken
"""

import pathlib
import re
import subprocess
import sys
from urllib.parse import unquote

LINK = re.compile(r"!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+\"[^\"]*\")?\s*\)")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def md_files():
    try:
        out = subprocess.run(["git", "ls-files", "-z", "--", "*.md"], capture_output=True, check=True).stdout
        return [pathlib.Path(p) for p in out.decode().split("\0") if p]
    except (OSError, subprocess.CalledProcessError):
        return sorted(pathlib.Path(".").rglob("*.md"))


def broken_links(md):
    fence = None
    for n, line in enumerate(md.read_text(errors="replace").splitlines(), 1):
        mark = line.lstrip()[:3]
        if mark in ("```", "~~~"):
            fence = None if fence == mark else (fence or mark)
            continue
        if fence:
            continue
        for target in LINK.findall(re.sub(r"`[^`]*`", "", line)):
            path = unquote(target.split("#", 1)[0])
            if not path or SCHEME.match(path) or "${" in path:
                continue
            if not (md.parent / path).exists():
                yield n, target


def main(args):
    files = [pathlib.Path(a) for a in args] or md_files()
    bad = 0
    for md in files:
        for n, target in broken_links(md):
            print(f"{md}:{n}: {target}")
            bad += 1
    print(f"{'FAIL' if bad else 'PASS'}: {bad} broken relative links in {len(files)} markdown files")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
