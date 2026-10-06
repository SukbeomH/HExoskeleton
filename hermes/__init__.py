"""hxsk on Hermes Agent: runs the repo's Claude Code hook scripts from Hermes plugin hooks.

The scripts read Claude Code's hook JSON, so each Hermes tool call is translated:
terminal -> Bash, write_file -> Write, patch -> Edit, read_file -> Read (Hermes `path` -> `file_path`).
A guard's exit 2 becomes {"action": "block"}; other exits allow the call, as in Claude Code.
A guard that cannot run (timeout, missing script) raises, and Hermes blocks the call (fail closed).
State hooks run only in projects that have .hxsk/ (opt-in, same as Claude Code).
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Hermes tool -> (Claude Code tool name, guard scripts in hooks/), as in hooks/hooks.json.
# read-before-edit is not ported: Hermes write_file already refuses unread files; patch only warns.
GUARDS = {
    "terminal": ("Bash", ("bash-guard.py",)),
    "write_file": ("Write", ("file-protect.py", "write-guard.py")),
    "patch": ("Edit", ("file-protect.py",)),
    "read_file": ("Read", ("file-protect.py",)),
}
TRACKED = ("terminal", "write_file", "patch")  # PostToolUse Edit|Write|Bash -> track-modifications.sh
HINT = "\n(hxsk on Hermes: Edit = patch, Write = write_file, Bash = terminal, Read = read_file)"
ROOT = None  # HExoskeleton checkout, set by register()


def _find_root():
    """HXSK_ROOT, else the checkout this file sits in (git clone + symlink into ~/.hermes/plugins)."""
    for cand in (os.environ.get("HXSK_ROOT"), Path(__file__).resolve().parent.parent):
        if cand and (Path(cand).expanduser() / "hooks" / "file-protect.py").is_file():
            return Path(cand).expanduser().resolve()
    return None


def _project():
    # Hermes' working directory: TERMINAL_CWD (worktree mode sets it), else the process cwd (cli.py).
    return os.environ.get("TERMINAL_CWD") or os.getcwd()


def _hxsk(project):
    return os.path.isdir(os.path.join(project, ".hxsk"))


def _claude_payload(tool_name, args, project):
    name = GUARDS[tool_name][0]
    if tool_name == "terminal":
        return {"tool_name": name, "tool_input": {"command": str(args.get("command") or "")}}
    # V4A patch text may come with or without `path`; file-protect checks its `*** ... File:` headers too.
    tool_input = {"command": str(args.get("patch") or "")}
    if args.get("path"):
        # ponytail: relative paths join the launch dir; Hermes joins the session cwd after a `cd`
        # (tools/file_tools_paths.py _authoritative_workspace_root). Matters only to write-guard.
        tool_input["file_path"] = os.path.join(project, os.path.expanduser(str(args["path"])))
    return {"tool_name": name, "tool_input": tool_input}


def _run(script, payload, project, timeout=5, capture=True):
    path = ROOT / "hooks" / script
    out = subprocess.PIPE if capture else subprocess.DEVNULL  # DEVNULL: don't wait on background children
    return subprocess.run(
        [sys.executable if script.endswith(".py") else "bash", str(path)],
        input=json.dumps(payload), stdout=out, stderr=out, text=True, cwd=project, timeout=timeout,
        env={**os.environ, "CLAUDE_PROJECT_DIR": project, "CLAUDE_PLUGIN_ROOT": str(ROOT)},
    )


def pre_tool_call(tool_name="", args=None, **_):
    if tool_name not in GUARDS:
        return None
    project = _project()
    payload = _claude_payload(tool_name, args or {}, project)
    for script in GUARDS[tool_name][1]:
        result = _run(script, payload, project)
        if result.returncode == 2:
            return {"action": "block", "message": (result.stderr.strip() or f"Blocked by hxsk {script}") + HINT}
    return None


def post_tool_call(tool_name="", args=None, **_):
    project = _project()
    if tool_name in TRACKED and _hxsk(project):  # sets .hxsk/.modified-this-session for on_session_end
        _run("track-modifications.sh", _claude_payload(tool_name, args or {}, project), project, capture=False)


def pre_llm_call(is_first_turn=False, **_):
    project = _project()
    if not (is_first_turn and _hxsk(project)):
        return None
    result = _run("session-start.sh", {"source": "startup"}, project, timeout=10)
    try:
        return {"context": json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]}
    except (ValueError, KeyError, TypeError):  # no output, or {"status": "error"}
        return None


def on_session_end(**_):
    # Hermes fires this at the end of every turn (agent/turn_finalizer.py) = Claude Code Stop.
    project = _project()
    if _hxsk(project):
        _run("stop-context-save.sh", {}, project, timeout=10, capture=False)


def hxsk_init(raw_args=""):
    project = os.path.abspath(os.path.expanduser(raw_args.strip() or _project()))
    result = subprocess.run(["bash", str(ROOT / "scripts" / "init-project.sh"), "--skills", project],
                            capture_output=True, text=True, timeout=60)
    output = (result.stdout + result.stderr).strip()
    if result.returncode:
        return f"hxsk-init failed (exit {result.returncode}):\n{output}"
    return (f"{output}\n\nNext: run `hermes skills trust {project}` in a shell so Hermes loads "
            ".agents/skills, start a new session, then fill .hxsk/SPEC.md (skill: hxsk-init).")


def register(ctx):
    global ROOT
    ROOT = _find_root()
    if ROOT is None:
        raise RuntimeError("hxsk: HExoskeleton checkout not found. Clone "
                           "https://github.com/SukbeomH/HExoskeleton and set HXSK_ROOT to it in ~/.hermes/.env")
    for hook in (pre_tool_call, post_tool_call, pre_llm_call, on_session_end):
        ctx.register_hook(hook.__name__, hook)
    ctx.register_command("hxsk-init", hxsk_init, description="Create .hxsk/ and copy hxsk skills to "
                         ".agents/skills in this project", args_hint="[project-dir]")
