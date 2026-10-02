---
name: front
description: "Makes the current Claude Code session the router front: the plugin's hook records its session id, name and permission mode when the user types /router:front, and this skill shows the registered topic sessions. User-typed only (/router:front), again after /clear, which changes the session id."
disable-model-invocation: true
compatibility: "Claude Code only, v2.1.236+ (cross-session SendMessage/ListAgents, claude --bg with --agent); python3."
allowed-tools:
- Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" *)
---

# router: front

## Quick Reference
- 사용자가 직접 입력한 `/router:front`만 front를 등록한다. 등록은 플러그인의 UserPromptExpansion 훅이 하고(이 세션의 id·이름·권한 모드), 이 스킬은 등록을 기록하지 않는다. 모델은 이 스킬을 부를 수 없다.
- 레지스트리: `${CLAUDE_PLUGIN_DATA}/registry.json` — `registry.py`로만 읽는다.
- 이후 매 메시지는 `router:route` 절차를 따른다. 작업 세션은 front의 권한 모드로 뜬다(대장에 기록된 모드, 매 턴 갱신).

## Steps

1. **대장 갱신과 표시.**

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" refresh
   ```

2. **등록 확인.** 이번 턴에 훅이 주입한 `[router]` 문맥이 없으면 등록되지 않은 것이다(사용자에게 알리고 멈춘다). 출력 첫 줄 `[router] front: @<name> (mode <mode>)`의 이름이 `?`이면 이 세션의 이름을 찾지 못한 것이다. 사용자에게 `/rename <name>`(영문·숫자·`-`·`_`)을 실행한 뒤 `/router:front`를 다시 입력하라고 안내하고 멈춘다. front 등록을 다른 방법(스크립트, 파일 편집)으로 대신하지 않는다.

3. **사용자에게 보고.** front 이름과 권한 모드(작업 세션이 이 모드로 뜬다), 등록된 작업 세션(이름·상태·주제·마지막 결과 한 줄)을 짧게 보여 주고, 이제 평소처럼 말하면 주제별 세션으로 전달된다고 알린다.

## Notes
- front는 한 번에 하나다. 다른 세션에서 `/router:front`를 입력하면 그 세션이 front가 된다.
- `/clear` 후에는 세션 id가 바뀌므로 다시 입력한다.
