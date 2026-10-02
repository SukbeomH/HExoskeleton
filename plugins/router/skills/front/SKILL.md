---
name: front
description: "Makes the current Claude Code session the router front: records its session id and name in the router registry and shows the registered topic sessions. Use only when the user explicitly asks (/router:front), or again after /clear, which changes the session id."
compatibility: "Claude Code only, v2.1.236+ (cross-session SendMessage/ListAgents, claude --bg with --agent); python3."
---

# router: front

## Quick Reference
- 이 세션만 front가 된다. 라우팅 문맥 주입(UserPromptSubmit 훅)은 front 세션에서만 일어난다.
- 레지스트리: `${CLAUDE_PLUGIN_DATA}/registry.json` — `registry.py`로만 읽고 쓴다.
- 이후 매 메시지는 `router:route` 절차를 따른다.

## Steps

1. **이 세션의 이름 확인.** `ListAgents`를 호출한다. 첫 줄이 이 세션의 이름(다른 세션이 메시지를 보낼 주소)이다. 첫 줄이 없으면 사용자에게 `/rename <name>`(영문·숫자·`-`·`_`)을 실행한 뒤 `/router:front`를 다시 부르라고 안내하고 멈춘다.

2. **front 기록.** `<name>`을 1의 이름으로 바꿔 실행한다.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" set-front "${CLAUDE_SESSION_ID}" --name "<name>"
   ```

   세션 id 인자가 비어 있어도 그대로 실행한다. `registry.py`가 Bash 환경의 `CLAUDE_CODE_SESSION_ID`(훅의 `session_id`와 같은 값)를 쓴다.

3. **대장 갱신과 표시.**

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/backend.sh" list | python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" refresh -
   ```

4. **사용자에게 보고.** front 이름, 등록된 작업 세션(이름·상태·주제·마지막 결과 한 줄)을 짧게 보여 주고, 이제 평소처럼 말하면 주제별 세션으로 전달된다고 알린다.

## Notes
- front는 한 번에 하나다. 다른 세션에서 `/router:front`를 실행하면 그 세션이 front가 된다.
- `/clear` 후에는 세션 id가 바뀌므로 다시 실행한다.
