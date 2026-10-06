#!/usr/bin/env python3
"""hermes/ 플러그인 시험: Hermes 로더처럼 __init__.py 를 불러 가짜 ctx 에 register() 하고,
등록된 콜백을 Hermes 페이로드(hermes_cli/plugins.py 의 pre_tool_call kwargs 등)로 부른다.
Hermes 를 설치하지 않는다 (stdlib 만). Usage: python3 tests/hermes-plugin.py
"""

import importlib.util
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILS = []


def check(label, cond):
    print(("ok   " if cond else "FAIL ") + label)
    if not cond:
        FAILS.append(label)


class FakeCtx:  # hermes_cli/plugins.py PluginContext.register_hook / register_command 서명
    def __init__(self):
        self.hooks, self.commands = {}, {}

    def register_hook(self, hook_name, callback):
        self.hooks.setdefault(hook_name, []).append(callback)

    def register_command(self, name, handler, description="", args_hint="", argument_mode=None):
        self.commands[name] = handler


def load(plugin_dir, slug):  # hermes_cli/plugins_loader.py _load_directory_module 과 같은 방식
    spec = importlib.util.spec_from_file_location(
        f"hermes_plugins.{slug}", plugin_dir / "__init__.py", submodule_search_locations=[str(plugin_dir)])
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def hook(ctx, name, **kwargs):
    (cb,) = ctx.hooks[name]
    return cb(**kwargs)


def pre(ctx, tool, args):  # model_tools → _get_pre_tool_call_directive_details 가 넘기는 kwargs 전부
    return hook(ctx, "pre_tool_call", tool_name=tool, args=args, task_id="t1", session_id="s1",
                tool_call_id="c1", turn_id="u1", api_request_id="", middleware_trace=[],
                telemetry_schema_version=1)


def blocked(result, needle=""):
    return isinstance(result, dict) and result.get("action") == "block" and needle in result.get("message", "")


TMP = Path(tempfile.mkdtemp())
try:
    os.environ.pop("HXSK_ROOT", None)
    # 1. 매니페스트: Hermes 검증기가 요구하는 name/version/description (hermes_cli/plugin_validate.py), 버전 = plugin.json
    manifest = dict(re.findall(r'^(\w+): "?([^"\n]*)"?$', (ROOT / "hermes/plugin.yaml").read_text(), re.M))
    version = re.search(r'"version": "([^"]+)"', (ROOT / ".claude-plugin/plugin.json").read_text()).group(1)
    check("plugin.yaml name/version/description", manifest.get("name") == "hxsk" and manifest.get("description"))
    check("plugin.yaml version = plugin.json", manifest.get("version") == version)

    # 2. 저장소 체크아웃 찾기: 서브디렉터리 설치(hermes/ 만 복사)는 HXSK_ROOT 없으면 로드 실패
    alone = TMP / "plugins" / "hxsk"
    shutil.copytree(ROOT / "hermes", alone)
    try:
        load(alone, "alone").register(FakeCtx())
        check("subdir install without HXSK_ROOT refuses to load", False)
    except RuntimeError as exc:
        check("subdir install without HXSK_ROOT refuses to load", "HXSK_ROOT" in str(exc))
    os.environ["HXSK_ROOT"] = str(ROOT)
    load(alone, "alone_env").register(FakeCtx())
    check("subdir install with HXSK_ROOT loads", True)
    os.environ.pop("HXSK_ROOT")

    ctx = FakeCtx()
    load(ROOT / "hermes", "hxsk").register(ctx)
    check("hooks registered", sorted(ctx.hooks) == ["on_session_end", "post_tool_call", "pre_llm_call", "pre_tool_call"])
    check("/hxsk-init registered", "hxsk-init" in ctx.commands)

    NO, HX = TMP / "no-hxsk", TMP / "hxsk"
    for p in (NO, HX):
        p.mkdir()
        (p / "existing.txt").write_text("existing\n")
    (HX / ".hxsk").mkdir()
    (HX / ".hxsk/SESSION_HANDOFF.md").write_text("# Handoff\nnext: hermes-smoke\n")

    # 3. 가드: .hxsk/ 유무와 무관하게 차단 (Claude Code 와 같음)
    for P in (NO, HX):
        os.environ["TERMINAL_CWD"] = str(P)
        tag = P.name
        check(f"{tag} write_file .env blocked", blocked(pre(ctx, "write_file", {"path": ".env", "content": "A=1"}), ".env"))
        check(f"{tag} read_file .env blocked", blocked(pre(ctx, "read_file", {"path": str(P / ".env")})))
        check(f"{tag} read_file .env.example allowed", pre(ctx, "read_file", {"path": ".env.example"}) is None)
        check(f"{tag} patch .env blocked", blocked(pre(ctx, "patch", {"path": ".env", "old_string": "a", "new_string": "b"})))
        v4a = "*** Begin Patch\n*** Update File: notes.txt\n@@\n-a\n+b\n*** Move File: notes.txt -> .env\n*** End Patch\n"
        check(f"{tag} V4A patch move onto .env blocked", blocked(pre(ctx, "patch", {"mode": "patch", "patch": v4a})))
        v4a_ok = "*** Begin Patch\n***Update File:  notes.txt\n@@\n-a\n+b\n*** End Patch\n"
        check(f"{tag} V4A patch notes.txt allowed", pre(ctx, "patch", {"mode": "patch", "patch": v4a_ok}) is None)
        check(f"{tag} write_file existing blocked (write-guard)",
              blocked(pre(ctx, "write_file", {"path": "existing.txt", "content": "x"}), "NO WRITE TO EXISTING FILES"))
        check(f"{tag} write_file new allowed", pre(ctx, "write_file", {"path": "new.txt", "content": "x"}) is None)
        check(f"{tag} terminal rm -rf blocked", blocked(pre(ctx, "terminal", {"command": "rm -rf build"}), "rm -r"))
        check(f"{tag} terminal ls allowed", pre(ctx, "terminal", {"command": "ls -la"}) is None)
        check(f"{tag} other tool ignored", pre(ctx, "web_search", {"query": ".env rm -rf"}) is None)

    # 4. 상태 훅: .hxsk/ 없으면 아무것도 만들지 않음
    first = dict(session_id="s1", task_id="t1", turn_id="u1", user_message="hi", conversation_history=[],
                 model="m", platform="cli", parent_session_id="", sender_id="", telemetry_schema_version=1)
    os.environ["TERMINAL_CWD"] = str(NO)
    check("no-hxsk first-turn context skipped", hook(ctx, "pre_llm_call", is_first_turn=True, **first) is None)
    hook(ctx, "post_tool_call", tool_name="write_file", args={"path": "new.txt"}, result="{}", task_id="t1")
    hook(ctx, "on_session_end", session_id="s1", completed=True, interrupted=False, model="m", platform="cli")
    check("no-hxsk .hxsk/ not created", not (NO / ".hxsk").exists())

    os.environ["TERMINAL_CWD"] = str(HX)
    got = hook(ctx, "pre_llm_call", is_first_turn=True, **first)
    check("hxsk first-turn context injected", isinstance(got, dict) and "hermes-smoke" in got.get("context", ""))
    check("hxsk later turn not injected", hook(ctx, "pre_llm_call", is_first_turn=False, **first) is None)
    hook(ctx, "post_tool_call", tool_name="terminal", args={"command": "npm test"}, result="{}", task_id="t1")
    flag = HX / ".hxsk/.modified-this-session"
    log = (HX / ".hxsk/.track-modifications.log").read_text() if flag.exists() else ""
    check("hxsk post_tool_call terminal tracked as Bash", flag.exists() and "\tBash\tnpm test" in log)
    hook(ctx, "on_session_end", session_id="s1", completed=True, interrupted=False, model="m", platform="cli")
    check("hxsk on_session_end runs stop-context-save (flag claimed)", not flag.exists())

    # 5. /hxsk-init: 임시 프로젝트에 .hxsk/ 와 .agents/skills 를 만든다
    proj = TMP / "fresh"
    proj.mkdir()
    out = ctx.commands["hxsk-init"](str(proj))
    check("/hxsk-init scaffolds .hxsk/SPEC.md", (proj / ".hxsk/SPEC.md").is_file())
    check("/hxsk-init copies skills", (proj / ".agents/skills/hxsk-init/SKILL.md").is_file())
    check("/hxsk-init tells user to trust skills", f"hermes skills trust {proj}" in out)
finally:
    shutil.rmtree(TMP, ignore_errors=True)  # stop-context-save 의 백그라운드 작업이 남아 있을 수 있다

print(f"{len(FAILS)} failure(s)" if FAILS else "all passed")
sys.exit(1 if FAILS else 0)
