# router — One session to rule them all

Claude Code 전용 플러그인. 사용자는 **front 세션 하나**에서만 말한다. front가 메시지마다 주제를 판단해 그 주제를 맡은 백그라운드 작업 세션에 전달하거나, 새 작업 세션을 띄우거나, 여러 세션에 전파하고, 결과를 front로 모은다. 수렴한 세션은 명시적인 명령으로 하나로 병합한다. 다른 세션 화면을 볼 필요가 없다.

## 설치

```text
/plugin marketplace add SukbeomH/HExoskeleton
/plugin install router@hexoskeleton
```

사용자 범위로 설치한다. 작업 세션은 여러 저장소에서 뜨고, 각 세션이 `router:topic-worker` 에이전트를 찾을 수 있어야 한다. 훅은 front와 작업 세션에서만 동작하므로 다른 세션에는 영향이 없다.

## 사용

1. 대화할 세션에서 `/router:front`를 직접 입력한다 — 플러그인 훅이 이 세션을 front로 등록하고(세션 id·이름·권한 모드), 스킬이 등록된 작업 세션을 보여 준다. 모델은 이 명령을 실행할 수 없다.
2. 그다음은 평소처럼 말한다. front가 `router:route` 절차로 판단한다.
   - **forward**: 기존 주제면 그 세션에 `SendMessage`로 전달. 종료된 세션은 다시 깨운다.
   - **new**: 새 주제면 `claude --bg --agent router:topic-worker`로 작업 세션을 띄운다. 형제 세션 목록을 함께 준다.
   - **broadcast**: 여러 주제에 걸치면 대상마다 한 번씩 보내고, 본문에 참여 세션 목록을 넣어 서로를 알린다.
   - **status**: 진행 상황을 물으면 대장을 갱신해 보여 준다. 사용자 응답을 기다리는 작업 세션은 `WAITING`으로 보이고, front가 `/router:approve` 입력이나 `claude attach <job_id>`를 안내한다.
3. 작업 세션이 권한 확인에서 멈추면 front에 인자 없이 `/router:approve`를 입력해 열린 요청(id·정확한 명령)을 읽고, `/router:approve <id>`(허용) 또는 `/router:approve <id> deny`(거부)를 직접 입력한다(아래 "승인 전달").
4. 수렴한 세션 병합: `/router:merge <세션...> into <새 이름>` — 요약을 모아 병합 brief를 만들고, 그것으로 새 작업 세션을 띄우고, 원본은 `merged`로 표시한다.

`/clear` 후에는 세션 id가 바뀌므로 `/router:front`를 다시 입력한다.

front에는 `/rename <고정 이름>`(또는 `claude -n <고정 이름>`으로 시작)으로 이름을 붙여 둔다. 이름 없는 대화형 세션의 기본 표시 이름(`<디렉터리>-<두 글자>`)은 다시 띄울 때마다 바뀌어, 작업 세션의 보고가 옛 이름으로 간다. front를 다시 띄웠으면 `/router:front`를 다시 입력한다. 대장에 새 session id와 이름이 기록되고, 이후 생성·재개되는 작업 세션은 프롬프트 첫 줄로 현재 front 이름을 받는다.

## 동작 방식

- **대장**: `${CLAUDE_PLUGIN_DATA}/registry.json` (사용자 단위). 이름(유일, 실행에 실패해 id가 없는 이름만 다시 쓸 수 있음)·session_id·job id·cwd·주제·모델(지정한 경우)·상태(active/idle/waiting/exited/merged)·마지막 결과. `scripts/registry.py`만 읽고 쓴다(flock + 원자적 교체). 빈 id는 기록하지 않는다. 전달할 때 `active`, 작업 세션의 턴이 끝나면(Stop 훅) `idle`. 목록을 갱신할 때 살아 있는 세션의 턴을 확인 프롬프트가 붙잡고 있으면(`claude agents`의 `status: waiting`·`waitingFor`) `waiting`과 그 이유를 기록한다. 프롬프트 없이 `state: blocked`인 세션(질문하고 턴을 끝냄)은 `idle/blocked`로 두고, 답은 평소처럼 전달한다. 작업 세션이 승인 결정을 받거나, `claude attach`로 응답을 받거나, 보고를 보내거나(`SendMessage`), 턴을 끝내면(Stop) 그때 기록한 대기(`waiting`·`waiting_for`·`blocked`)를 지운다. 그래서 끝난 세션이 `WAITING`이나 `idle/blocked`로 남지 않는다.
- **front 등록**: 사용자가 입력한 `/router:front`의 UserPromptExpansion 훅이 그 입력의 `session_id`·`permission_mode`와 `claude agents`에서 찾은 그 세션의 이름을 대장에 기록한다. `registry.py`에는 front를 쓰는 명령이 없다.
- **UserPromptSubmit 훅**: `session_id`가 front일 때만 그 턴의 `permission_mode`를 대장에 기록하고(`front.permission_mode`·`mode_updated`), 대장 요약을 `additionalContext`로 주입한다(열린 승인 요청과 최근에 입력한 결정 포함, 아래 "승인 전달"). 다른 세션에서는 아무것도 하지 않는다. 시간 제한은 15초다(6차 시험의 부하에서 5초를 넘겨 그 턴의 문맥이 빠졌다).
- **작업 세션**: `agents/topic-worker.md`. 한 주제만 맡고, 완료·막힘 시 front에 `SendMessage`로 짧게 보고하고, 라우팅하지 않는다. 대장에 기록된 front의 권한 모드로 뜬다(아래 보안 모델).
- **Stop 훅**: 작업 세션(`session_id`, 아직 모르면 `$CLAUDE_JOB_DIR`의 job id가 대장에 있음)에서만 `last_assistant_message`를 `last_result`로 기록한다. 보고가 빠져도 front가 결과를 읽을 수 있다. 입력의 `background_tasks`에 아직 도는 subagent가 있으면 상태를 `idle`로 내리지 않고 `active`로 둔다(0.5.0, 문서: hooks "Stop input". 셸 백그라운드 작업만 있으면 `idle`).
- **승인 전달**: 작업 세션의 PermissionRequest 훅과 front의 `/router:approve` 훅(아래 "승인 전달").
- **보고 대상 고정**: 작업 세션의 PreToolUse(`SendMessage`) 훅이 front·형제가 아닌 살아 있는 세션(`claude agents`)으로의 전송을 거부한다. front가 사라진 뒤 보고하면 `SendMessage`가 "Did you mean <다른 세션>?"을 제안하고, 작업 세션이 그 제안을 따라 무관한 세션에 보고를 보낸 일이 있었다. 주소는 Claude Code가 쓰는 꼴을 벗겨 비교한다: `@`, `"공백 든 이름"`, 이름이 겹칠 때 붙는 ` [ref]`(예: `router-front-5 [09e9dd]`), 앞뒤 공백, 대소문자. ref는 `claude agents`에 없어 검증할 수 없으므로, front·작업 세션(id 기준)이 아닌 살아 있는 세션과 이름이 같으면 front 이름이라도 거부한다. 벗기고 나서 빈 주소(ref만)도 거부한다. 작업 세션 자신의 subagent 이름·id는 막지 않는다. front를 `/clear`하거나 다시 띄운 뒤 `/router:front`를 다시 입력하기 전에는 front의 새 session id가 대장에 없어 보고가 거부된다(0.2.1까지는 이름으로 전달됐다). 주소가 front 이름이면 거부 사유가 그 사정을 알린다: front가 아직 `/router:front`로 재등록하지 않았거나 다른 세션이 이름을 가져갔고, 결과는 Stop 훅으로 저장되니 다음 턴에도 계속 보고하라고(0.2.4. 6차 시험에서는 "another session" 거부 뒤 작업 세션이 다음 턴에 보고하지 않았다). 그동안 결과는 Stop 훅의 `last_result`로만 남는다. Claude Code는 이름이 하나뿐이어도 `name [ref]`로 주소를 쓴다(6차 시험).
- **백엔드**: 세션 생성·재개·목록·정지·요약은 `scripts/backend.sh` 한 파일만 Claude Code CLI를 부른다. 다른 백엔드(Orca 등)로 바꿀 때 이 파일만 교체한다. `registry.py`만 부르고, 인자 목록이 고정되어 있다(추가 claude 인자 없음, 권한 모드는 문서의 6개 값만). `spawn`/`resume`은 프롬프트를 표준 입력으로 받고, stdout은 job id 한 줄뿐이다(안내 문구는 stderr).
- **프롬프트 조립**: `registry.py spawn`/`resume`이 front의 요청 본문(`--request TEXT`, 또는 `--request -`와 heredoc 표준 입력)에 대장의 현재 front 이름·주제·형제 목록을 붙여 작업 세션 프롬프트를 만들고, 이름 예약·실행·job id 기록까지 한 명령으로 묶는다. 프롬프트 파일을 쓰지 않고, id를 모델이 옮겨 적지 않는다. `spawn`은 디렉터리(기본: front의 cwd)와 요청을 이름 예약 전에 확인한다.
- **재개**: 프로세스가 없는(`pid` 없음) 세션만 `claude --resume <session_id> --bg`로 깨운다. `registry.py resume`은 먼저 목록을 갱신하고, 살아 있는 세션이면 재개하지 않는다(오래된 문맥에서 사본을 띄우지 않게). 훅이 주입하는 목록은 `pid`를 그 프로세스가 있을 때만 보여 준다. 목록에 남은 세션은 플래그 없이 깨워야 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 이어진다. 플래그를 주면 사본이 생긴다. 목록에서 지워진 세션은 이름과 현재 front 모드를 다시 준다.

## 권한 프롬프트 줄이기

front는 `registry.py`를 플러그인 경로째 부르는 단일 명령만 쓴다. `front`/`route`/`merge` 스킬의 `allowed-tools`는 스킬을 불러온 그 턴에만 이 스크립트를 사전 승인한다. front는 `route`를 세션에 한 번만 불러오고, 작업 세션 보고처럼 메시지로 시작된 턴에는 스킬이 없다. 그래서 **사람이 지켜보지 않는 라우팅에는 아래 allow 규칙이 필수다.** 사용자 설정(`~/.claude/settings.json`)에 넣고, `<HOME>`은 홈 디렉터리의 절대 경로(`echo $HOME`)로, `<VERSION>`은 설치된 버전(예: `0.5.0`)으로 바꾼다. 마켓플레이스 설치본의 `${CLAUDE_PLUGIN_ROOT}`는 `~/.claude/plugins/cache/hexoskeleton/router/<version>/`이다. 버전 자리에 `*`를 쓰지 않는다(아래 보안 모델). 플러그인을 업데이트하면 규칙의 버전도 바꾼다. 바꾸지 않으면 확인이 다시 뜰 뿐이다. `Skill(...)` 규칙은 front가 스킬을 불러올 때의 `Use skill "router:route"?` 확인을 없앤다(`Skill(name)`은 정확히 그 이름, `Skill(name *)`은 인자가 붙은 호출까지). 사용자가 직접 입력한 `/router:front`·`/router:approve`는 Skill 도구 호출이 아니라서 확인이 없으므로 `front`·`approve` 규칙은 두지 않는다.

```json
{
  "permissions": {
    "allow": [
      "Bash(python3 \"<HOME>/.claude/plugins/cache/hexoskeleton/router/<VERSION>/scripts/registry.py\" *)",
      "Skill(router:route)",
      "Skill(router:merge *)"
    ]
  }
}
```

`backend.sh` 규칙은 두지 않는다. 스킬은 `backend.sh`를 직접 부르지 않고(`registry.py`가 안에서 부른다), 그 규칙이 있으면 모델이 권한 모드와 claude 인자를 직접 골라 작업 세션을 띄울 수 있다.

규칙을 두어도 남는 확인:
- 스크립트 밖의 즉흥 명령(예: `cd … &&`가 붙은 복합 명령, `cp`). 스킬은 이런 명령을 쓰지 않으며, 거절해도 흐름이 이어진다.
- 작업 세션 쪽에서 그 세션의 권한 모드가 허용하지 않는 도구 사용. 그 확인 프롬프트가 작업 세션의 턴을 붙잡아, 작업 세션은 보고할 수 없고 Stop 훅도 오지 않는다. 대장은 그 세션을 `WAITING`으로 표시하고, 사용자는 front에 `/router:approve <id> [deny]`를 입력하거나(아래 "승인 전달") 터미널에서 `claude attach <job_id>`로 열어 응답한다. 다른 세션의 메시지는 승인이 되지 못한다.

작업 세션은 front의 권한 모드로 뜬다. 지켜보지 않고 맡기려면 front를 `auto`(쓸 수 있는 계정에서)나 `acceptEdits`로 띄우고, 작업에 필요한 명령은 allow 규칙에 더한다.
- `default`(Manual): 작업 세션은 승인이 필요한 첫 도구에서 멈춘다.
- `acceptEdits`: 파일 편집과 흔한 파일 시스템 명령은 묻지 않지만, 그 밖의 셸 명령(예: `python3 -c …`)은 allow 규칙이 없으면 여전히 묻는다.
- `auto`: 분류기가 대부분의 동작을 사람 대신 검토한다.
- `dontAsk`: 물을 동작을 묻지 않고 거부한다(문서 기준). 작업 세션은 멈추지 않고 거부된 일을 `blocked`로 보고한다.

## 승인 전달

작업 세션이 권한 확인에서 멈추면, 그 확인을 front에서 사용자가 직접 입력한 명령으로 허용하거나 거부한다. 결정 경로에 모델이 없다.

1. **작업 세션**: PermissionRequest 훅(모든 도구, 시간 제한 600초)이 대장에 있는 작업 세션에서만 동작한다. 확인할 호출을 `approvals/pending/<id>.json`에 쓴다. 이 파일에는 8자리 임의 id, 작업 세션 이름, 도구, `tool_input` 원문, 만료 시각이 들어간다. 그다음 `approvals/decisions/<id>.json`을 최대 300초 기다린다. 결정은 같은 id를 담고 요청보다 나중에 쓰였을 때만 받으며, 읽는 즉시 지운다(한 번만 쓰임). 응답은 allow 또는 deny뿐이다. 입력 변경(`updatedInput`)이나 규칙 추가(`updatedPermissions`)는 하지 않는다. 결정이 없으면 출력 없이 끝나 일반 확인 창이 그대로 남으므로 `claude attach`로 계속 응답할 수 있다. 다른 세션, `dontAsk` 모드(묻지 않는다는 약속), front에서는 아무것도 하지 않는다.

   사용자가 `claude attach`로 먼저 응답해도 Claude Code는 이 훅을 멈추지 않는다(4차 시험). 그래서 훅은 3초마다 `claude agents`를 본다. 자기 작업 세션이 `status: waiting`·`waitingFor: permission prompt`인 것을 한 번 보면 요청에 `seen`을 기록하고, 그 뒤 더는 그 상태가 아니면 출력 없이 끝나 요청을 지운다. 첫 확인이 확인 창보다 먼저일 수 있어서, 본 적 없이 아니라고만 나오면 끝내지 않는다. 훅의 입력에는 `tool_use_id`가 없다(문서: PermissionRequest input).

   subagent 안의 확인(`agent_id`가 있는 요청)은 이 방법으로 알 수 없다. subagent가 확인 창에서 기다리는 동안 `claude agents`는 작업 세션을 `busy`로 보인다(6차 시험). 그래서 이런 요청은 `claude agents`를 보지 않고 subagent 자신의 transcript `<transcript_path에서 .jsonl을 뗀 경로>/subagents/agent-<agent_id>.jsonl`을 본다(문서: sub-agents의 transcript 위치, hooks의 SubagentStop. 6차 시험의 파일 위치. `claude -p` 실측: subagent 안의 PermissionRequest 입력에서 `transcript_path`는 본 세션의 것이고 `agent_id`가 있으며, Bash의 `tool_input`은 transcript의 `tool_use` 입력과 같다). 같은 도구·입력의 `tool_use`에 요청 시각 뒤의 `tool_result`가 생기면 응답된 것으로 보고, 훅은 출력 없이 끝난다. 요청 전에 끝난 같은 호출의 결과나 다른 호출의 결과는 세지 않는다. 파일 크기가 늘었을 때만 읽고, 일반 파일만 연다(0.2.4). 백그라운드 subagent는 아래처럼 훅이 기다리는 동안 attach에 확인 창이 뜨지 않으므로, 이 감지는 주로 만료 뒤의 기록을 닫는 데 쓰인다.

   **백그라운드 subagent의 확인(0.5.0)**: 7차 시험에서 `claude attach`는 백그라운드 subagent의 확인 창을 이 훅이 기다리는 동안 보여 주지 않았다(요청 3개, 본 화면·subagent 화면 모두). 훅이 대기 시간(300초)을 넘겨 끝난 뒤에야 확인 창이 떴다. 본 스레드의 확인 창은 훅이 기다리는 동안에도 보였다. 그래서 **대기 중에는 `/router:approve`로만 답하고, attach는 대기 시간이 지난 뒤에만 쓸 수 있다.** 결정 없이 대기 시간이 지나면 훅은 그 요청을 `approvals/expired/<id>.json`으로 남긴다. front 목록은 그 작업 세션을 `WAITING: subagent prompt — claude attach <job_id> to answer`와 요청 내용 한 줄로 보인다(Stop 훅이 `idle`로 적었어도). subagent transcript에 결과가 생기거나, 같은 subagent가 다시 묻거나, 작업 세션 프로세스가 사라지거나, 1시간이 지나면 더는 보이지 않는다. 그 id의 `/router:approve`는 `not sent. <id> expired: … claude attach <job_id>`로 거부된다. 만료 뒤에는 대기 중과 달리 `claude agents`가 작업 세션을 `waiting`·`permission prompt`로 보이므로(8차 시험), front의 refresh가 그 상태를 대장에 적는다. 이 `WAITING: permission prompt — user must run: claude attach <job_id>` 줄은 작업 세션의 보고, 결정, Stop, 다음 refresh에서만 지워진다. 그래서 attach로 답한 뒤에도 작업 세션이 보고하거나 다음 refresh가 올 때까지 몇 초 남을 수 있다(8차 시험 약 13초).

   병렬 도구 호출은 확인 창이 하나씩 뜬다. 첫 확인에 응답하면 다음 확인이 곧 떠서(5차 시험 0.6초, 6차 시험의 부하에서 2.3·4.3초), 작업 세션은 확인 창을 떠나지 않고 `claude agents`로는 응답을 알 수 없다. 그래서 같은 스레드의 더 새 요청이 있으면 이전 요청은 응답된 것으로 본다. 스레드는 `session_id`, 그리고 subagent 안이면 `agent_id`로 가른다(문서: 훅 공통 입력의 `agent_id`는 subagent 안에서만 있다). `seen` 요청의 훅은 0.5초 안에 출력 없이 끝나고, front 목록은 그 요청을 숨긴다. 작업 세션 본 스레드와 그 subagent의 요청은 서로 밀어내지 않는다.

   Codex 작업 세션(0.4.0)은 이 훅 대신 `scripts/codex-turn.py`가 같은 모양의 pending 파일을 쓰고 같은 규칙으로 결정을 읽는다. 그 `WAITING` 줄에는 `claude attach` 대신 `unanswered = denied when it expires`가 붙는다(아래 "Codex 작업 세션 → 승인 전달").
2. **표시**: 열린 요청이 있는 작업 세션은 refresh 없이도 `WAITING`으로 보이고, 그 아래에 요청 한 줄이 붙는다.

   ```text
   - relay1 [WAITING: permission prompt — user types /router:approve (bare: lists ids), or runs: claude attach fd6f02cb; …
     approval 2a53cf92: @relay1 Bash: echo relay-ok > /tmp/router-relay-test.txt
   ```

   승인·거부 명령 줄(`approve: /router:approve <id>   deny: /router:approve <id> deny …`)은 사용자가 인자 없이 입력한 `/router:approve`의 목록에만 나온다. 이 목록은 훅이 사용자에게만 보인다(0.5.1. 0.5.0까지는 front 문맥에도 있어, 9차 시험에서 front가 응답에 id를 쓰고 프롬프트 제안이 그 명령을 채웠다).

   모델이 쓴 `description`은 보이지 않고 `tool_input`만 보인다(Bash는 `command`, 그 밖의 필드는 `[input: {…}]`). 표시용으로 ANSI 시퀀스와 제어·zero-width·bidi 문자를 지우고, 지운 개수를 `[N hidden chars removed]`로 알린다. 줄바꿈은 `⏎`로 보여, 두 명령이 한 명령처럼 읽히지 않게 한다. 300자를 넘으면 `…[cut: 전체 길이 chars]`로 자른다. `seen` 요청인데 작업 세션이 더는 확인 창에 있지 않거나(`claude attach`로 응답됨), 같은 스레드의 더 새 요청이 있거나, subagent 요청의 결과가 그 transcript에 생기면 훅이 끝나기 전이라도 보이지 않는다. front 모델은 응답에 요청 id나 id가 든 승인 명령을 쓰지 않고, 인자 없는 `/router:approve`를 안내한다. 이 규칙은 `route`와 함께 매 턴 주입하는 문맥 끝의 안내에도 있다(0.5.1, 아래 "프롬프트 제안").

   front 문맥 끝에는 최근 10분 동안 front에 직접 입력한 결정이 최대 5개 붙는다. `/router:approve`는 프롬프트를 막아 front 모델이 보지 못하기 때문이다(6차 시험에서 front는 작업 세션이 인용한 거부를 의심했다). 기록은 표시 전용 `approvals/decided/<id>.json`이고, 결정 경로는 이 파일을 읽지 않는다. 실제로 무엇이 실행됐는지는 작업 세션의 보고가 알린다.

   ```text
   [router] decided by the user's typed /router:approve (last 10 min; the worker's report tells what then ran):
   - 11:09:09 denied 495ff640 @r6-par Bash: echo d > /tmp/router-r6-d.txt
   ```
3. **사용자 입력**: front에 `/router:approve <id>`(허용) 또는 `/router:approve <id> deny`(거부)를 직접 입력한다. UserPromptExpansion 훅이 다음을 차례로 확인한 뒤 결정 파일을 쓴다.
   - 입력한 세션이 대장의 front인지.
   - id가 8자리 소문자 hex이고 열린(만료 전) 요청인지.

   결정을 쓴 뒤 프롬프트를 막는다. 그래서 모델 턴이 없고, 화면에는 무엇을 허용·거부했는지(`router: approved <id>: @<세션> <도구>: <명령>`) 나온다. 거부하면 작업 세션의 도구 결과 끝에 `Report this as blocked to the front (not done).`가 붙는다(0.5.0. 6·7차 시험에서 거부가 `완료` 머리말 아래 보고됐다). Codex의 거부(`decline`)에는 메시지 칸이 없어, Codex 작업 지시에 같은 뜻을 적었다. 인자 없이 입력하면 열린 요청 목록을 보여 준다. front가 아니거나, 모르는 id·만료된 id면 `not sent`로 막는다. 이미 `claude attach`로 응답됐거나 같은 작업 세션의 다음 요청에 밀린 요청도 결정을 쓰지 않고 막는다. 보통은 훅이 먼저 끝나 요청이 지워졌으므로 `not sent. No open request <id> (answered, expired or unknown).`가 나온다(5·6차 시험). 훅이 아직 끝나지 않았으면 `not sent. <id> was already answered (e.g. via claude attach) or superseded by the same worker's next request; nothing approved.`가 나온다.

**끄기**: 사용자 설정의 `"env": {"ROUTER_APPROVAL_WAIT": "0"}`. 훅이 기다리지 않고 바로 끝나, 일반 확인 창과 `claude attach`만 남는다.

**프롬프트 제안**: Claude Code는 응답 뒤 다음 입력을 예측해 입력창에 회색으로 보여 준다(문서: Prompt suggestions). 4차 시험에서 front가 승인 명령을 쓰자 입력창에 `/router:approve <id>`가 제안됐다. 제안은 `Tab`이나 `→`로 입력창에 넣고 `Enter`로 보낸다(빈 입력에서 `Enter`만으로 제출되던 동작은 v2.1.136에서 고쳐졌다. 9차 시험에서 확인). 제안된 승인 명령을 요청 줄을 읽지 않고 보내지 않는다. front에서는 제안을 끄기를 권한다.
- 설정: `"promptSuggestionEnabled": false`(어느 설정 파일이든, `/config`의 **Prompt suggestions**가 쓰는 키).
- front 세션만: `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false claude -n <front 이름>`(설정보다 우선, v2.1.238+).

front는 응답에 요청 id나 id가 든 승인 명령을 쓰지 않는다. 9차 시험에서 front가 `route` 없이 답하며 id를 썼고 그 명령이 제안됐다. 그래서 0.5.1은 이 규칙을 `route`뿐 아니라 매 턴 주입하는 안내에도 두고, 주입 문맥에서 승인 명령 줄을 뺐다. 다만 요청 줄(`approval <id>: …`)에는 id가 남고 규칙은 모델이 따르는 데 달려 있어, 위험을 줄일 뿐 없애지 못한다.

**권장 deny 규칙** (사용자 설정). 이 규칙은 Claude의 파일 도구(Edit·Write 모두. 경로 규칙은 `Edit(...)`으로만 검사되고 `Write(path)` 규칙은 쓰이지 않는다)와 Claude Code가 알아보는 Bash 파일 명령·리다이렉션(`> file`, `tee` 등)으로 결정 파일을 쓰는 것을 막는다.

```json
{
  "permissions": {
    "deny": ["Edit(~/.claude/plugins/data/router-hexoskeleton/approvals/**)"]
  }
}
```

이 규칙은 스스로 파일을 여는 하위 프로세스(`python3 -c …`, node 스크립트)는 막지 못한다(문서 기준). OS 수준으로 막으려면 sandbox를 켜고 `sandbox.filesystem.denyWrite`에 같은 경로(`~/.claude/plugins/data/router-hexoskeleton/approvals`)를 넣는다.

**위조 방지**:
- 결정은 front 세션에서 직접 입력한 `/router:approve`의 훅만 쓴다.
  - 모델의 Skill 호출은 막힌다(`disable-model-invocation: true`, 실측 거절).
  - 다른 세션이 보낸 같은 글자의 메시지는 확장되지 않는다.
  - front가 아닌 세션에서 입력하면 거부된다(실측).
- `registry.py`에는 결정을 쓰는 명령이 없다. 위 allow 규칙은 `registry.py`의 모든 인자를 승인하므로, 그런 명령이 있으면 모델이 확인 없이 승인할 수 있다.
- id는 요청마다 새로 만들고, 만료가 있고, 한 번만 쓰인다.

**남는 위험**: 사용자가 확인 창에서 버튼을 누르는 것과 같은 신뢰 수준이다. 다만 아래 경우는 막지 못한다.
- 같은 OS 사용자로 셸을 제한 없이 쓰는 프로세스는 결정 파일을 직접 쓰거나 `claude -p --resume <front session id> "/router:approve <id>"`를 실행할 수 있다(`-p`의 프롬프트는 입력으로 확장된다). 셸이 제한 없는 경우는 다음과 같다.
  - `bypassPermissions` front, 또는 `auto` front에서 분류기가 허용한 명령.
  - 모델이 임의 코드를 실행하게 하는 allow 규칙은 무엇이든 그렇다. 예: `Bash(python3 -c *)`, `Bash(node:*)`(`node -e`), `Bash(rtk:*)`처럼 다른 명령을 대신 실행하는 래퍼(`rtk proxy …`), `Bash(claude --plugin-dir:*)`. 이런 규칙이 하나라도 있으면 작업 세션이나 front 모델이 확인 없이 결정을 위조할 수 있다. router를 쓸 때는 이런 규칙을 설정(사용자·프로젝트·로컬)에서 뺀다.
- 이 위험은 이 플러그인의 다른 훅 정책과 같다. 플러그인은 자동 승인되는 경로(allow 규칙이 승인하는 `registry.py`, Skill 호출, 세션 간 메시지)를 막고, OS 수준 경계는 sandbox에 맡긴다.
- 표시는 정리하고 잘라서 보이므로, 300자를 넘는 입력은 끝까지 보이지 않는다. 긴 명령은 `claude attach`로 원문을 보고 응답한다. 백그라운드 subagent의 요청은 router 대기 시간이 지난 뒤에야 attach에 보인다(위 "백그라운드 subagent의 확인").
- front는 다음 턴에야 새 요청을 안다. 인자 없는 `/router:approve`는 즉시 최신 목록을 보여 준다.
- 본 스레드의 확인을 `claude attach`로 응답한 뒤 훅이 알아채기 전(다음 확인 창이 뜨기 전, 또는 최대 약 3초)에 입력한 `/router:approve`는 `approved`라고 답하지만 아무 일도 일어나지 않는다(Claude Code는 이미 응답된 확인 창에 대한 늦은 훅 답을 무시했다, 4·5차 시험). subagent 요청은 그 결과가 transcript에 쓰이는 즉시 숨긴다(transcript는 비동기로 쓰여 조금 늦을 수 있다). 결과가 쓰이기 전에 입력한 승인은 같다.
- 같은 스레드의 확인 창은 하나씩 뜬다는 것은 5차 시험의 병렬 호출 관찰이다. 같은 스레드에 열린 확인 창이 둘 생기면 이전 요청은 relay되지 않고(거부도 승인도 아님) `claude attach`로만 응답한다.
- 입력창의 프롬프트 제안(위)이 승인 명령을 미리 채울 수 있다.

## 보안 모델

- **allow 규칙이 허용하는 것**: 버전을 고정한 경로의 `registry.py`를 어떤 인자로든. 그래서 `registry.py`는 인자로 다음을 받지 않는다: 작업 세션의 권한 모드, front, 세션 id·job id, 다른 대장 파일(`--data`는 `~/.claude/plugins/data/` 아래만), claude 인자. allow 규칙은 작업 세션에도 적용되므로 작업 세션이 이 스크립트를 불러도 같다.
- **작업 세션 모드는 front 모드로 고정**: front의 UserPromptSubmit 훅이 매 턴 기록한 `permission_mode`(기록이 없으면 `default`). `backend.sh`는 그 값만, 고정된 인자 목록으로 받는다. 재개는 router가 띄운 세션만 깨운다(id는 실행·`claude agents`·Stop 훅만 기록한다).
- **승인은 사람만**: 작업 세션의 권한 확인은 사용자가 front에 직접 입력한 `/router:approve`의 훅만 결정한다(위 "승인 전달").
- **front 등록은 사람만**: 사용자가 `/router:front`를 입력할 때의 UserPromptExpansion 훅만 front를 쓴다. 모델의 Skill 호출(`disable-model-invocation: true`)과 다른 세션이 보낸 같은 글자의 메시지는 확장되지 않아 등록하지 못한다. 이 경로는 Claude Code 2.1.287에서 확인했다. 이 훅이 없는 버전에서는 등록되지 않고, front 스킬이 그 사실을 알린다.
- **버전 `*` 금지**: Bash 규칙의 `*`는 `/`와 `..`까지 맞는다. 버전 자리에 `*`를 두면 `…/router/../../<임의 경로>.py` 같은 명령이 승인되어 모델이 쓴 아무 파이썬 파일이나 확인 없이 실행된다(2026-10-02 `-p` 실측: 규칙이 있으면 실행, 없으면 확인).
- **남는 위험**:
  - 같은 OS 사용자. 셸을 제한 없이 쓰는 세션(`bypassPermissions`, `auto` 분류기가 허용한 명령, 임의 코드를 실행하게 하는 allow 규칙: 위 "승인 전달"의 남는 위험)은 대장 파일을 고치거나, 승인 결정을 쓰거나, `claude -p "/router:front"`로 front를 등록하거나, `claude --bg`를 직접 부를 수 있다. 플러그인이 막는 것은 allow 규칙으로 자동 승인되는 경로다.
  - front가 `auto`나 `bypassPermissions`면 작업 세션도 그 모드로 뜬다.
  - 목록에 남은 세션의 제자리 재개는 처음 띄울 때의 모드(그때의 front 모드)를 유지한다. 플래그를 주면 사본이 생기기 때문이다. front 모드를 낮췄으면 새 세션을 띄운다.

## Codex 작업 세션

front는 그대로 Claude Code 세션이고, 작업 세션 하나하나를 Codex CLI로 띄울 수 있다(0.3.0). 0.4.0부터 Codex 작업 세션의 승인 요청도 front의 `/router:approve`로 전달된다(아래 "승인 전달").

Hermes 작업 세션은 지원하지 않는다 — 로컬 백엔드에 sandbox가 없어 작업 세션이 승인 결정·대장 파일을 써서 다른 작업 세션의 승인을 위조할 수 있다.

**요청하기**: front에 `코덱스로 …`, `codex로 …`, `with codex …`처럼 말한다. `route`가 `registry.py spawn <이름> --backend codex …`로 띄우고, 본문에서 그 지시는 뺀다. 지정하지 않으면 지금처럼 Claude 작업 세션이다. 백엔드는 작업 세션마다 대장에 `backend: codex`로 남고, 재개·정지·요약·병합은 그 값으로 나뉜다.

**필요한 것**: `codex`가 PATH에 있고 로그인돼 있어야 한다(`codex login status`). 작업 디렉터리가 git 저장소일 필요는 없다(0.4.0 실측). 사용자의 `~/.codex/config.toml`(모델, MCP, rules, 사용자 훅)은 그대로 적용된다.

**신뢰 항목**: 작업 디렉터리가 git 저장소 안이면 첫 실행의 `thread/start`가 `~/.codex/config.toml`에 `[projects."<저장소 루트>"] trust_level = "trusted"`를 더한다. Codex app-server는 cwd를 받은 `thread/start`에서 세 조건이 모두 맞을 때 이 항목을 쓴다(소스: codex-rs `app-server/src/request_processors/thread_processor.rs:1353-1378`, rust-v0.159.0).
- 그 프로젝트에 신뢰 항목(trusted·untrusted)이 아직 없다.
- 프로젝트 디렉터리다. `.git`이 있거나, 소스상 프로젝트 `.codex/` 폴더가 있다(`config/src/loader/mod.rs:408`).
- 실효 sandbox가 cwd에 쓸 수 있다(`workspace-write`·`danger-full-access`).

router에서는 front 모드가 `plan`(read-only)이 아닌 spawn이 해당한다. 키는 cwd가 아니라 저장소 루트다. 같은 `thread/start`를 쓰는 `codex exec`(0.3.0 경로, `exec/src/lib.rs:1372`)도 같은 조건에서 쓴다. 소스상 `thread/resume`과 `summarize`(read-only `exec fork`)는 쓰지 않는다. `codex sandbox`(`cli/src/debug_sandbox.rs`)에는 설정을 쓰는 코드가 없다. 격리 실측(2026-10-06, 빈 `CODEX_HOME`, 로그인 없이 턴 없이)의 결과는 다음과 같다. git 저장소의 `workspace-write` `thread/start`만 항목을 만들었다. git이 아닌 디렉터리의 `workspace-write`, git 저장소의 `read-only`, `codex sandbox`(기본·`workspace-write`)는 만들지 않았다. 8·9차 시험에서 시험 폴더(git 저장소)의 항목이 생긴 것도 이 경로다. Claude Code도 front와 Claude 작업 세션을 띄운 폴더를 `~/.claude.json`의 프로젝트 항목으로 남긴다(9차 시험). 버리는 폴더에서 시험했다면 시험 뒤 두 파일에서 그 항목을 지워도 된다.

**동작**:
- 요청 하나가 실행(run) 하나다. `scripts/codex-turn.py`가 router 전용 `codex app-server`를 stdio 자식으로 띄워 턴 하나를 돌리고, 턴이 끝나면 app-server도 끝낸다. 첫 실행이 `thread/start`로 thread를 만들고(대장의 `session_id` = thread id), 이후 요청은 `thread/resume`으로 같은 thread에 이어진다. 실행마다 job id가 새로 생긴다. 공유 데몬(`codex app-server daemon`)은 쓰지 않는다(아래 "게이트 실측").
- `scripts/backend-codex.sh`가 `backend.sh`와 같은 인터페이스(고정 인자, stdout은 job id만)로 Codex를 부른다. 다만 `resume`은 모델도 받는다. `thread/resume`은 모델을 주지 않으면 설정의 모델을 쓰므로, `--model`로 띄운 세션은 재개 때마다 같은 모델을 다시 준다.
- `scripts/codex-run.py`가 실행을 감독한다. 자기 세션으로 떨어져 front의 Bash 호출보다 오래 살고, 실행 기록을 `<데이터 디렉터리>/codex/<job>/`(`run.json`, `last.txt`, `stderr`)에 둔다. 실행이 끝나면 마지막 메시지(`last.txt`)를 그 작업 세션의 `last_result`로 기록하고 `idle`로 바꾼다. Claude 작업 세션에서 Stop 훅이 하는 일이다. 실패하면 `codex run failed (exit N): <오류>`가 기록되고 목록에 `idle/failed`로 보인다. `codex-turn.py`는 `codex exec --json`과 같은 줄(`thread.started`, `turn.failed`)을 내므로 감독 쪽은 0.3.0과 같다.
- 실행은 `codex-turn.py`가 `thread.started`(thread 시작이나 재개가 받아들여짐)를 낸 뒤에야 시작된 것으로 본다(0.5.1). 그 전에 끝난 실행(재개 거절 `already has an active writer`, sandbox 불일치, 로그인 안 됨)은 `spawn`·`resume` 명령이 그 오류로 실패한다. `resume`이면 그 요청을 보류된 후속 요청 뒤에 대장의 `held`로 남겨 다음 전달 때 먼저 보낸다. 0.5.0까지는 재개의 thread id를 미리 넣어 거절된 재개도 시작된 것으로 보았고, 요청과 보류된 후속 요청이 사라졌다(9차 시험 C4).
- 감독 프로세스가 강제로 끝나면(SIGKILL, `stop`이 아님) `codex-turn.py`가 부모 pid가 바뀐 것을 보고(0.5초 간격) app-server를 끝내고 나간다(0.5.1). 그 실행의 결과는 어차피 기록되지 않고, 남은 app-server는 턴이 끝날 때까지 thread 쓰기 잠금을 쥔다(9차 시험). Linux의 parent-death signal(`prctl`)은 macOS에 없어 폴링한다. 대장은 다음 refresh까지 `active`로 남고(그 실행은 `crashed`로 보여 `exited`가 된다), 실행 기록 디렉터리는 지우지 않는다.
- 대장에 쓰는 것은 router 자신의 필드뿐이다. Codex 훅은 sandbox 안의 exec도 `permission_mode: bypassPermissions`로 보고하는데, 이 값을 대장에 옮기지 않는다. 옮기면 다음 Claude 작업 세션이 진짜 bypass로 뜬다.
- 작업 지시는 `topic-worker` 에이전트 대신 프롬프트 머리에 들어간다. 내용은 다음과 같다. 한 주제만 한다. 세션을 만들거나 라우팅하지 않는다. sandbox가 막으면 승인을 요청하고, 거부되거나 요청할 수 없으면 우회하지 않고 `blocked`로 끝낸다. 마지막 메시지에 `[<topic>] done|blocked: …` 보고를 쓴다.

**Claude 작업 세션과 다른 점**:
- **결과 알림(0.5.0)**: Codex 작업 세션은 `SendMessage`를 쓸 수 없어 보고 메시지가 오지 않는다. 대신 `route`가 Codex 세션에 `spawn`·`resume`한 뒤 `registry.py wait <이름>`을 Bash 도구의 `run_in_background: true`(문서: tools reference "Background commands", hooks의 Bash `tool_input`)로 돌린다. 이 명령은 그 세션이 결과를 기록하거나, 실행을 멈추거나, 새 승인 요청을 열 때 한 줄을 출력하고 끝난다. 끝난 백그라운드 명령은 유휴 front에 입력 없이 새 턴을 연다(7차 시험 H5: 25초 뒤). 사용자에게는 전달 직후 `→ @<이름>(Codex)로 보냈습니다. 끝나면 알려 드립니다.`가 보이고, 실행이 끝나면 따로 입력하지 않아도 front가 결과(`[<topic>] done|blocked: …`)나 승인 대기(`WAITING`)를 알린다.
  - `wait`는 읽기만 한다. 대장 파일과 `approvals/pending`의 mtime을 보고(기본 0.5초 간격), 잠금을 잡거나 파일을 쓰지 않는다. 그래서 위 `registry.py` allow 규칙 밖의 권한이 늘지 않는다.
  - 출력: `[router] wait <이름> (codex): idle — last: <결과>`, `… active (held follow-ups are running now: wait again) — last: …`(보류된 후속 요청이 이어서 실행 중, front가 다시 건다), `… WAITING: approval @<이름> Bash: <명령> — …`(front가 다시 건다. wait 시작 전에 열린 요청으로는 끝나지 않는다), `… still running after 600 s …`. 결과 글은 승인 요청 표시처럼 정리하고 300자로 자른다.
  - 기본 600초, `--timeout`은 최대 1800초(비대화형 세션은 백그라운드 명령을 기본 30분에 멈춘다. 대화형 세션에는 제한이 없다). `still running`이면 결과는 다음 메시지나 상태 확인 때 대장에서 보인다.
  - Claude Code는 이 알림 앞에 사람 입력이 아니라는 안내를 붙인다(문서: Agent SDK task notification). 알림은 사용자 동의가 아니다.
- **실행 중 후속 요청은 보류된다**: `route`는 Codex 세션에 늘 `registry.py resume`으로 보낸다. 실행이 진행 중이면 요청이 대장의 `held`에 쌓이고(목록에 `held N`), 감독 프로세스가 실행이 끝나면 쌓인 요청을 묶어 다음 실행으로 보낸다. 그때의 front 모드를 쓴다. 한 thread에 실행 두 개를 겹쳐 띄우지 않는다. 다음 실행을 띄우지 못하면(재개 거절 포함, 0.5.1) 요청은 대장에 남아, 다음 전달 때 함께 간다. 그 다음 실행의 결과가 `last_result`를 바꾸기 전에 front가 앞 결과를 읽지 못할 수 있어(7차 시험에서 17초 만에 덮어썼다), 대장은 실행마다 결과를 최근 3개(`results`)로 남기고 목록은 연쇄의 앞 결과를 그 세션 줄 아래 `earlier result (its held follow-ups ran right after): …`로 보인다(0.5.0). front가 직접 보낸 실행이 끝나면 그 줄은 사라진다. 주제가 넓어졌으면 `resume`에 `--topic`을 주어 대장 주제와 프롬프트를 함께 바꾼다(0.5.0. 0.4.0까지는 `unrecognized arguments`로 실패했다).
- **승인은 front로만 온다(attach 없음)**: 아래 "승인 전달". 요청 하나의 답은 front에서 직접 입력한 `/router:approve`뿐이다. app-server의 클라이언트가 `codex-turn.py` 하나라 `claude attach`나 Codex 화면으로 답할 길이 없고, 대기 시간(`ROUTER_APPROVAL_WAIT`, 기본 300초) 안에 답이 없으면 거부로 끝난다. 작업 세션은 `blocked`로 보고하고, 다시 보내면 새 요청이 온다.
- **router 훅이 없다**: router는 Claude Code 플러그인으로 설치되므로 Codex 작업 세션은 router 훅을 실행하지 않는다. Stop·PermissionRequest·`SendMessage` 가드가 돌지 않는다. 승인 전달도 Codex 훅이 아니라 `codex-turn.py`(app-server 클라이언트)가 한다. Codex에 router를 플러그인으로 따로 설치하면 Codex가 `hooks.json`을 읽지만, 사용자가 신뢰하기 전까지 훅은 꺼져 있다. 켜져도 `CLAUDE_PLUGIN_DATA`가 Codex 쪽 디렉터리(`~/.codex/plugins/data/router-<marketplace>`)라 front의 대장을 보지 못한다. 가드가 필요 없는 이유는 Codex 세션이 `SendMessage`를 쓸 수 없기 때문이다. front 쪽 훅과 보안 모델(front 등록, 모드 기록, 승인 위조 방지)은 그대로다.
- **정지·요약**: `registry.py stop <이름>`은 실행의 프로세스 그룹(감독 프로세스, `codex-turn.py`, app-server)에 SIGTERM을 보낸다. 열린 승인 요청 파일도 지운다. 대장은 바로 `exited`가 되어 걸어 둔 `wait`가 끝난다(Claude 작업 세션의 `stop`도 같다. 0.5.1. 0.5.0까지는 refresh 전까지 `active`라 `wait`가 시간 제한까지 돌았다, 9차 시험 C2b). 보류된 후속 요청은 지우지도 자동으로 보내지도 않고, 다음 전달 때 먼저 간다(목록에 `held N`). 병합된 원본은 `merged`로 남는다. thread는 남아 다시 보내면 재개된다. `summarize`는 `codex exec fork --ephemeral`을 read-only sandbox로 실행해 원본 thread를 건드리지 않고 요약한다(실행이 끝나면 app-server가 끝나 thread가 풀려 있다). `merge`는 Codex 원본에 메시지를 보내지 않고 `last_result`나 `summarize`로 요약을 얻는다.

**권한 모드 → sandbox, 승인 정책** (`thread/start`·`thread/resume`마다 둘 다 명시하고, Codex가 돌려준 값이 다르면 턴 없이 실패):

| front 모드(대장 기록) | Codex sandbox | Codex 승인 정책 |
|---|---|---|
| `plan` | `read-only` | `never` |
| `default`, `acceptEdits`, `auto` | `workspace-write` | `on-request` (front로 전달) |
| `dontAsk` | `workspace-write` | `never` |
| `bypassPermissions` | `danger-full-access` | `never` |

모드는 늘 front의 UserPromptSubmit 훅이 기록한 값이다(인자로 받지 않는다). 그래서 `danger-full-access`는 front 자신이 `bypassPermissions`일 때만 나온다. `--dangerously-bypass-approvals-and-sandbox`는 쓰지 않는다. `workspace-write`는 작업 디렉터리와 임시 디렉터리에만 쓸 수 있다. `auto`도 분류기 없이 `on-request`로 간다. 자동 검토(`approvals_reviewer = auto_review`)는 쓰지 않는다.

### 승인 전달 (0.4.0)

`on-request` 실행에서 Codex가 명령(sandbox 밖 쓰기, 네트워크 등)이나 파일 변경의 승인을 물으면:

1. app-server가 클라이언트인 `codex-turn.py`에 `item/commandExecution/requestApproval`(또는 `item/fileChange/requestApproval`)을 보낸다. 답이 올 때까지 턴은 멈춰 있다.
2. `codex-turn.py`가 Claude 작업 세션의 PermissionRequest 훅과 같은 모양으로 `approvals/pending/<nonce>.json`을 쓴다. 도구는 `Bash`(실제로 돌 명령과 cwd, 네트워크 요청이면 host) 또는 `apply_patch`(바뀔 파일)이고, 모델이 쓴 `reason`은 보이지 않는다.
3. front 목록에 `WAITING: permission prompt — user types /router:approve (bare: lists ids; unanswered = denied when it expires)`와 `approval <id>: @<이름> Bash: <명령>` 줄이 보인다. 사용자가 front에 직접 `/router:approve <id>`(허용) 또는 `/router:approve <id> deny`를 입력한다.
4. front의 UserPromptExpansion 훅만 결정을 쓰고, `codex-turn.py`가 그 결정을 한 번 읽어(nonce 일치, 요청 이후 작성) `accept` 또는 `decline`으로 답한다. `acceptForSession`이나 실행 정책 변경은 보내지 않는다.

위조 방지는 Claude 작업 세션과 같다. 결정은 front 훅만 쓰고, Codex 작업 세션은 결정을 쓰거나 승인 통로에 닿을 수 없다(2026-10-06 실측: `workspace-write`의 모델 셸은 `~/.claude/plugins/data/…` 쓰기, `~/.codex` 쓰기, 유닉스 소켓 연결, `codex queue`가 모두 `Operation not permitted`). app-server는 stdio로만 열려 소켓이 없으니 같은 사용자의 다른 프로세스도 이 요청에 답할 수 없다. 추가 안전장치:

- 승인 디렉터리가 그 thread의 sandbox 안에서 쓰기 가능하면(작업 디렉터리·writable roots·`/tmp`·`$TMPDIR` 아래, 예: 작업 디렉터리가 홈) 요청을 front에 올리지 않고 바로 거부한다. 작업 세션이 자기 결정을 쓸 수 있기 때문이다.
- `never` 정책 실행에 요청이 오면 거부한다. 다른 server request(추가 권한, MCP elicitation, 사용자 입력 등)는 거절해 턴이 멈추지 않게 한다.
- 승인된 명령은 사용자가 본 그대로 sandbox 밖에서 돈다. 목록에 보인 명령을 읽고 승인한다.

### 게이트 실측 (2026-10-06, codex-cli 0.159.0)

A2(Claude front + app-server에서 도는 Codex thread + 승인 전달)를 만들기 전에 확인한 것. 시험 thread는 모두 지웠다.

- **G1 승인 경로**: app-server thread(`untrusted`)에서 Codex PermissionRequest 훅은 승인 요청이 클라이언트에 가기 **전에** 돈다(훅이 15초 기다린 뒤에야 `requestApproval`과 `waitingOnApproval`이 나왔다. 훅이 도는 동안 상태는 `active`, 표시 없음). 훅의 allow는 클라이언트 없이도 명령을 돌렸고, deny는 막았다. 훅이 답하지 않고 클라이언트도 없으면 턴은 `active`+`waitingOnApproval`로 기다리고, 나중에 `thread/resume`한 클라이언트에게 같은 요청이 다시 와서 그 클라이언트가 답할 수 있었다. router는 훅 대신 클라이언트 답을 쓴다(G3).
- **G2 격리**: 위 "위조 방지"의 결과(`never`·`on-request` 모두). 공유 데몬 소켓을 쓰면 sandbox 밖의 같은 사용자 프로세스는 답할 수 있으므로, 소켓 없는 stdio를 골랐다.
- **G3 Codex 플러그인 훅**: 신뢰 키는 `router@<marketplace>:hooks/hooks.json:<event>:<group>:<handler>`(버전 없음), 신뢰는 handler 정의의 hash에 걸린다. 업그레이드 뒤에도 `hooks.json`의 handler가 같으면 신뢰가 유지되고(스크립트 내용은 hash에 들지 않는다), handler가 바뀌면 `modified`로 꺼진다. `CLAUDE_PLUGIN_DATA`는 Codex 쪽 데이터 디렉터리라 front의 대장을 보지 못한다. 그래서 훅 경로는 쓰지 않는다.
- **G4 대화형 Codex 화면과 데몬**: 시험하지 않았다. 소스상 TUI는 기본 데몬 소켓이 있으면 붙는다. 이 사용자의 Codex TUI는 `--no-daemon`으로 떠 있어 router가 데몬을 띄우면 환경이 바뀐다. 그래서 데몬을 쓰지 않는다.
- **G5 동시 쓰기**: app-server가 thread를 올려 둔 동안(유휴든 실행 중이든) `codex exec resume`은 `thread-store conflict: … already has an active writer`로 곧바로 실패한다(손상 없음). 데몬은 구독이 끊긴 thread도 30분 올려 두므로 그동안 다른 실행과 부딪힌다(`exec fork`는 시험하지 않았다). 실행마다 끝나는 stdio app-server는 실행 직후 쓰기 잠금을 풀었다(실측).

### 실측 확인 (2026-10-06, codex-cli 0.159.0)

대화형 front로 본 Codex 승인·정지·병합·강제 종료는 아래 "실측 확인 (대화형 9차 시험)"의 C1–C5.

0.5.1 재개 거절·감독 강제 종료 (2026-10-07, CLI로 front 역할을 대신함, `gpt-6-luna`, front 모드 `plan`, `ROUTER_REGISTRY`로 임시 대장, git 저장소가 아닌 임시 작업 디렉터리):

- `sleep 40`을 시킨 실행 중 감독 프로세스만 SIGKILL: 0.41초 뒤 그 프로세스 그룹(`codex-turn.py`, app-server)이 사라졌고, 1초 안에 `sleep`도 끝났으며 thread 쓰기 잠금(`lsof`)도 풀렸다.
- 다른 app-server 클라이언트가 같은 thread를 `thread/resume`해 쥔 동안 `resume`: exit 1, `… already has an active writer`와 `Its request is kept (held 1)`, 대장은 `exited`·`held` 1개. 그 클라이언트를 닫은 뒤의 전달은 job id를 받았고, 한 실행에 보류된 요청과 새 요청이 함께 가(답 `R1 slept`) `held`가 비었다.
- 시험 thread 둘은 `codex delete --force <id>`로 지웠다. 남은 프로세스는 없었고, `session_index.jsonl`과 `~/.codex/config.toml`의 신뢰 항목 수는 시험 전과 같았다.

10차 (CLI, `ROUTER_REGISTRY`로 작업 디렉터리 안의 임시 대장(cwd와 `/tmp` 둘 다 해당), git 저장소가 아닌 작업 디렉터리, front 모드 `default`): sandbox 밖 `curl`의 `require_escalated` 재요청이 174 ms 만에 거부됐다. 승인 디렉터리는 만들어지지 않았고(pending 없음), 작업 세션은 `blocked`로 보고했다.

0.5.0 `wait` (CLI로 front 역할을 대신함, `gpt-6-luna`, front 모드 `default`, 대장은 `~/.claude/plugins/data/` 아래 임시 디렉터리, git 저장소가 아닌 임시 작업 디렉터리):

- `spawn … --request "reply with the word pong"` 직후 `wait`: 5.5초 뒤 `[router] wait live1 (codex): idle — last: [live wait check] done: pong`, exit 0.
- 보류 연쇄: `sleep 8`을 시킨 `resume` 3초 뒤 `resume --topic "live wait chain"`이 `held: …`. 첫 `wait`가 19.3초에 `active (held follow-ups are running now: wait again) — last: … first-done`, 다시 건 `wait`가 24.5초에 `idle — last: [live wait chain] done: second-done`. 목록은 `last`에 둘째 결과, 그 아래 `earlier result …`에 첫 결과를 보였다. 보류된 요청에 준 `--topic`이 다음 실행의 프롬프트 주제가 됐다.
- 시험 thread는 `codex delete --force <id>`로 지웠다. 남은 프로세스는 없었다. 작업 디렉터리가 git 저장소가 아니어서 `~/.codex/config.toml`에 신뢰 항목도 더해지지 않았다. git 저장소에서는 더해진다(위 "신뢰 항목", 8차 시험).
- 대화형 front가 `route`대로 `wait`를 백그라운드로 걸고 알림에 결과·승인 대기를 전하는 흐름은 8차 시험에서 확인했다(아래 "실측 확인 (대화형 8차 시험)"의 I1·I2).

0.4.0 (app-server, `gpt-6-luna`, front 모드 `default`, 대장은 `~/.claude/plugins/data/` 아래 임시 디렉터리, 작업 디렉터리는 git 저장소가 아닌 임시 디렉터리):

- spawn(`pong`): job id가 바로 나오고 3.5초 뒤 `idle`, `last_result` `pong`, `pid` 없음. 실행이 끝난 뒤 그 thread의 쓰기 잠금(`~/.codex/thread-writer-locks/<id>.lock`)은 없었다.
- 허용: sandbox 밖 `touch`를 시키자 5초 안에 `pending`이 생기고 front 목록에 `WAITING … user types /router:approve below`와 정확한 명령(`/bin/zsh -lc 'touch …'`, cwd)이 보였다. 훅에 `/router:approve <id>`를 넣자 `router: approved …`로 막히고 2초 안에 파일이 생겼으며 작업 세션은 `done`을 보고했다.
- 거부: `/router:approve <id> deny` 뒤 파일은 생기지 않았고 작업 세션은 `blocked: The escalated command was rejected …`를 보고했다.
- 요약: 실행 직후 `summarize`가 성공했다. front 모드는 `default` 그대로였고 `permission_mode`를 가진 작업 세션은 없었다. `codex-turn.py`·`codex-run.py`·`codex app-server` 프로세스는 남지 않았다. `codex-turn.py`를 SIGKILL해도 app-server는 stdin EOF로 끝났다.

0.3.0 (`codex exec`, 기본 모델):

- `registry.py spawn live-cx --backend codex --request "reply with the word pong"`: 0.6초 만에 job id를 출력했다. 6.1초 뒤 대장에 thread id(`session_id`), `last_result`(`pong …`), `idle`, `pid` 없음이 기록됐다. `run.json`은 `done`·exit 0, stderr는 비어 있었다.
- `resume`(`… pang`): 같은 thread, 새 job id, 5.0초 뒤 `last_result`가 `pang` 보고로 바뀌었다(`-c sandbox_mode="workspace-write"` 수용).
- 보류: `sleep 8`을 시킨 실행 중 refresh는 `[active codex pid N]`이었다. 그동안 보낸 `resume`은 `held: …`를 출력했고, 실행이 끝나자 감독 프로세스가 그 요청을 다음 실행으로 보냈다. 20초 안에 `held-done` 보고가 기록되고 `held`가 비었다.
- 대장에 `permission_mode`를 가진 작업 세션은 없었고, front 모드는 `default` 그대로였다. 남은 프로세스는 없었고, 시험 thread는 `codex delete --force <id>`로 지웠다.

### 미검증 (Codex 작업 세션)

- `danger-full-access` 실행(단위 테스트만).
- 사용자 config의 권한 프로필(`permissions`)이 요청한 sandbox를 바꾸는 경우. router는 Codex가 돌려준 sandbox·정책이 요청과 다르면 실행을 실패시킨다(단위 테스트만).
- 감독의 연쇄 실행이 거절될 때의 재보류(stub app-server 단위 테스트만). 감독 강제 종료는 CLI 실측만.
- 사용자 Codex 훅(`~/.codex/hooks.json`)의 PermissionRequest가 먼저 allow/deny하면 그 요청은 router에 오지 않고 그 훅이 결정한다(게이트 실측 G1, 설계상 한계).

## 한계

- **Claude Code 전용**: cross-session `SendMessage`/`ListAgents`와 `claude --bg`가 필요하다. 최소 버전은 각 `SKILL.md`의 `compatibility`를 본다.
- 신뢰하지 않은 디렉터리에서는 작업 세션을 띄울 수 없다(`Workspace not trusted`).
- 유휴·미연결 작업 세션은 약 1시간 뒤 프로세스가 멈춘다. 멈춘 세션은 `SendMessage`로 깨어나지 않으므로 다음 전달 때 `route`가 `resume`으로 다시 깨운다.
- 작업 세션마다 독립 세션이라 비용이 세션 수에 비례한다. 전달된 메시지도 프롬프트처럼 사용량에 잡힌다.
- 결과 보고는 작업 세션이 지시를 따르는 데 달려 있다. 백업은 Stop 훅의 `last_result`다. `notify_when_idle`은 선택 사항으로, 오래 걸리는 작업에만 건다(평소에는 보고와 겹쳐 같은 결과가 한 턴 더 온다).
- 플러그인을 제거하거나(`/plugin`, `claude plugin uninstall`) 마켓플레이스를 제거하면 플러그인 데이터 디렉터리(`~/.claude/plugins/data/router-hexoskeleton/`)가 대장 `registry.json`째 지워진다. 남기려면 `claude plugin uninstall --keep-data`(문서 기준).
- `claude --bg --name`은 이름 중복을 막지 않는다. 유일성은 대장이 보장한다.
- `bypassPermissions` 세션은 다른 권한 class의 메시지를 보류한다. 작업 세션은 front와 같은 모드로 뜨므로 서로의 메시지가 보류되지 않는다.
- `claude stop`한 세션은 `claude agents --json --all`에 `done`으로 남는다. 목록에서 지우려면 `claude rm`.

### 실측 확인 (임시 대장, `--plugin-dir` 로드)

- `backend.sh spawn` → 작업 세션이 `router:topic-worker`로 실행, Stop 훅이 `$CLAUDE_JOB_DIR` job id로 찾아 `last_result`와 `session_id`를 기록.
- `-p` 세션에서 front 등록(`/router:front`)과 UserPromptSubmit 주입, 그 세션의 `SendMessage`가 유휴 작업 세션에 새 턴을 시작시킴.
- `stop` 후 `backend.sh resume`가 같은 id·이름·에이전트로 재개, `claude rm` 뒤 재개도 이름 유지.
- `backend.sh summarize`(`-p --resume --fork-session`)가 원본 transcript를 건드리지 않고 요약.

### 실측 확인 (interactive test 2026-10-02, Orca terminal, marketplace install)

- 대화형 front의 전체 흐름: `/router:front` 등록 → 분류 → 생성(new)·전달(forward)·전파(broadcast)·상태(status) → 보고 중계.
- `merge` 절차 끝까지: brief 작성, 새 세션 생성, 원본 `merged` 표시.
- 작업 세션이 매 턴 front에 스스로 `SendMessage`로 보고했고, 작업 세션 쪽 권한 프롬프트는 없었다.
- 메시지로 시작된 턴(작업 세션 보고, idle 알림)에서도 UserPromptSubmit 훅이 실행되어 대장 문맥이 주입됐다.
- 마켓플레이스 설치본에서는 dispatch 시 `no agent named 'router:topic-worker'` 경고가 없다(`--plugin-dir`로는 경고가 나지만 세션은 에이전트로 정상 실행된다).
- 대화형에서 스킬 본문의 `${CLAUDE_SESSION_ID}`가 치환되어 실제 세션 id가 기록됐다(`-p`에서는 빈 값이라 `CLAUDE_CODE_SESSION_ID` 폴백).
- `notify_when_idle`은 요청 시 동작하지만 보고 뒤에 같은 결과를 한 턴 더 보낸다. 그래서 `route`가 더는 걸지 않는다.

### 실측 확인 (대화형 재시험, Orca terminal, marketplace install)

- `registry.py spawn`/`resume` 경유 생성·재개와 단일 명령 템플릿, 대장 상태 갱신(전달 시 `active`, 턴 종료 시 `idle`)이 대화형 흐름에서 동작했다.
- 위 Bash allow 규칙이 마켓플레이스 캐시 경로(버전 디렉터리)와 맞아, 스킬을 불러오지 않은 턴에서도 router 스크립트 확인이 사라졌다. 규칙이 없으면 그런 턴마다 물었다(`allowed-tools`는 스킬을 불러온 턴에만 적용된다).
- `SendMessage`와 `ListAgents`는 확인을 묻지 않았다.
- 유휴 작업 세션의 프로세스는 약 1시간 뒤 멈췄다(supervisor 로그의 `bg retire … idle`).
- 그렇게 멈춘 세션은 `claude agents`에서 `pid`·`status`가 빠지고 `state`는 그대로 남는다(직접 `claude stop`한 세션은 `stopped`). front의 `ListAgents`에 보이지 않고, `SendMessage`는 `No agent named … is reachable`을 돌려줄 뿐 깨우지 않는다. 다시 쓰려면 `resume`이 필요하다.
- `claude stop` 뒤, `claude rm` 뒤, 1시간 유휴로 멈춘 뒤 모두 refresh → `resume`으로 같은 session id·새 pid·같은 이름·에이전트·모델로 깨어났고, 중복 항목은 없었다.
- front를 다시 띄우자 기본 표시 이름이 바뀌었고, 재개된 작업 세션이 옛 이름으로 보고하다 오류 힌트로만 새 이름을 찾았다. 그래서 재개 프롬프트에도 현재 front 이름을 넣고, front에 `/rename`을 권한다.

### 실측 확인 (대화형 3차 시험, Orca terminal, marketplace install)

- 표준 입력 heredoc이 든 `registry.py spawn`/`resume` 명령(여러 줄 본문 포함)이 위 Bash allow 규칙과 맞아, 스킬을 불러오지 않은 턴에서도 확인 없이 실행됐다. 두 Bash 규칙만 뺀 대조 시험에서는 같은 형태의 명령이 확인을 물었다.
- `Skill(router:route)`·`Skill(router:merge *)` 규칙으로 스킬 확인이 사라졌다(규칙이 없던 이전 시험에서는 `route`가 물었다). 사용자가 입력한 `/router:front`는 Skill 도구 호출 없이 실행되어 확인이 없었다.
- 작업 세션은 지연 로드된 `SendMessage`를 `ToolSearch`로 불러와 첫 턴에 front에 보고했다. 보고 단계까지 간 모든 경우(병합으로 띄운 세션, 재개한 턴 포함)가 그랬고, 프롬프트의 `@<front 이름>` 표기도 전달에 지장이 없었다.
- `default` 모드 작업 세션이 셸 명령 확인에서 멈추자 `claude agents`는 `status: waiting`, `waitingFor: permission prompt`, `state: blocked`를 보였고, 보고도 Stop 훅도 오지 않았다.

### 실측 확인 (0.1.4 보안 수정, `--plugin-dir`, 임시 대장)

- `claude -p --permission-mode dontAsk "/router:front"`: UserPromptExpansion 훅이 front를 등록했다(session id, `claude agents`의 이름, `permission_mode: dontAsk`). 프롬프트는 막히지 않고 front 스킬이 이어서 실행됐다.
- 모델에게 Skill 도구로 `router:front`를 부르게 하자 거절됐고(`disable-model-invocation`), 대장은 바뀌지 않았다.
- 그 front 모드로 `registry.py spawn`한 haiku 작업 세션: `claude --bg … --permission-mode dontAsk --model haiku`만 받았고, 작업 세션 자신의 훅 입력도 `permission_mode: dontAsk`였다. Stop 훅이 `last_result`를 기록했다.

### 실측 확인 (0.2.0 승인 전달, `--plugin-dir`, 임시 대장, Claude Code 2.1.287)

- `claude -p --session-id <uuid> --permission-mode default "/router:front"`로 front를 등록했다. `-p --resume <uuid>`로 이어 입력한 `/router:approve`도 같은 session id로 훅에 들어와 front로 인정됐고, 프롬프트는 막혀 모델 턴이 없었다(약 4초).
- `registry.py spawn`으로 띄운 haiku 작업 세션(`default`)이 `echo relay-ok > /tmp/…`에서 멈췄다. `claude agents` 상태는 `waiting / permission prompt`였다. PermissionRequest 훅이 6초 안에 pending 파일을 썼고, refresh 없는 `registry.py list`가 `WAITING`, 요청 id, 명령, approve/deny 줄을 보였다.
- front의 `/router:approve <id>`: 화면에 `router: approved <id>: @relay1 Bash: echo relay-ok > …`가 나왔다. 약 4초 뒤 파일이 생겼고, 결정 파일은 소비됐으며 pending도 지워졌다. 작업 세션 transcript에는 `Allowed by PermissionRequest hook`이 남았다.
- `/router:approve <id> deny`: 파일은 생기지 않았다. 작업 세션의 도구 결과는 `The user denied this in the router front (…)`였고, 작업 세션은 재시도하지 않고 턴을 끝냈다.
- 위조 시도: front가 아닌 `-p` 세션에서 같은 id로 입력하자 `not sent … only in the router front session`으로 막혔고 결정 파일이 없었다. front 모델에게 보통 턴으로 "대신 승인해 달라"고 하자 Skill 도구로 `router:approve`를 불렀다. 그 호출은 `disable-model-invocation`으로 거절됐고, 모델은 사용자에게 직접 입력하라고 답했다. 결정 파일은 없었고 요청은 열린 채였다.
- 보고 대상: front(`-p`)가 종료된 뒤 작업 세션이 보고하자 `SendMessage`가 `no agent named '<front>' is reachable. Did you mean: <무관한 대화형 세션>?`을 돌려줬다. 작업 세션은 그 제안대로 그 세션에 보고를 보냈다(수정 전, 받는 쪽 세션의 승인 대기로 보류됨). 수정 후에는 대장에 없는 살아 있는 세션(시험용 decoy)으로 보낸 `SendMessage`가 PreToolUse 훅에서 거부됐고, decoy는 아무것도 받지 않았다.

### 실측 확인 (대화형 4차 시험 2026-10-06, 0.2.0, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.287), 작업 세션은 haiku(시험 중 자동 업데이트로 2.1.290).

- 대화형 front의 승인 전달: 상태 턴이 요청 id와 명령을 보였고, 인자 없는 `/router:approve`가 그 요청을 나열했다. `/router:approve <id>`는 모델 턴 없이 `router: approved <id>: @r4-allow-file Bash: echo r4-allow > …`를 보였다. 결정 소비 → pending 삭제(0.5초) → 파일 생성 → 보고 순이었고, 작업 세션에는 `hook_permission_decision allow`가 남았다. `/router:approve <id> deny`는 `router: denied <id>`, 작업 세션은 거부 메시지를 받고 `blocked`로 보고했으며 파일은 없었다.
- 300초 만료: 결정 없이 300.4초 뒤 pending이 지워지고 훅이 끝났다. 작업 세션은 그 뒤에도 `waiting / permission prompt`였다(확인 창 유지). 인자 없는 목록은 `(none)`, 만료된 id는 `not sent. No open request … expired or unknown`. 그 뒤 `claude attach`로 승인하자 명령이 실행되고 턴이 이어져 보고가 왔다.
- 라우팅 지시 제거: `… haiku 모델로 새 작업 세션을 띄워 줘` 같은 요청이 `spawn … --model haiku`와 지시를 뺀 본문(예: `3의 거듭제곱 5개 알려줘.`)으로 나갔다. 작업 세션 5개 모두 지시 없는 본문을 받았고 거절하지 않았다.
- `merge` 순서: 살아 있는 원본 2개에 `SendMessage`로 요약 요청 → 턴 종료(`요약을 요청했습니다…`) → 답장 2개 → `spawn merged-4 --merged-from powers-of-three,r4-allow-file --model haiku`. 원본은 `merged → merged-4`가 됐다.
- `claude attach`로 먼저 응답(0.2.0): 명령은 한 번 실행됐고 보고가 왔다. 하지만 훅은 계속 기다려 pending이 남았고, front가 그 요청을 계속 보였으며, 늦은 `/router:approve`가 `approved`라고 답했다. 두 번째 실행은 없었다(파일 한 줄, Bash 결과 하나): Claude Code는 이미 응답된 확인 창에 대한 늦은 훅 답을 무시했다. 0.2.1에서 고쳤다(위 "승인 전달").
- 보고 턴의 주입 문맥에 응답이 끝난 세션이 `WAITING … claude attach`로 남았고, Stop 뒤에는 `idle/blocked`로 보였다. 0.2.1에서 고쳤다(위 "대장").
- front가 승인 명령을 쓴 뒤 입력창에 `/router:approve <id>`가 프롬프트 제안으로 미리 채워졌다(위 "프롬프트 제안").
- front가 `/router:approve`로 보류된 세션 간 메시지를 풀 수 있다고 잘못 안내했다. 0.2.1에서 `route`에 그렇지 않다고 적었다.

### 실측 확인 (대화형 5차 시험 2026-10-06, 0.2.1, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.290), 작업 세션은 haiku. 로컬 설정에 고정 allow 규칙, 권장 deny 규칙, `"promptSuggestionEnabled": false`를 두었다.

- 승인 전달: 목록과 `/router:approve <id>`가 동작했고 훅이 `allow`를 돌려줬다. 파일은 한 줄이었다. 보고 턴의 문맥은 `WAITING`이 아니라 `[active]`였고, Stop 뒤에는 `[idle]`이었으며 대기 기록은 지워졌다.
- `claude attach`로 먼저 응답(0.2.1): 응답 뒤 **2.4초 안에** pending이 지워졌다(재시험 2.6초 안). 늦은 `/router:approve <id>`는 `not sent. No open request … Open requests: (none)`으로 막혔다. 결정 파일은 없었고, 파일은 한 줄, Bash 결과는 하나였다. 훅이 먼저 끝나 `already answered`는 나오지 않았다(위 "사용자 입력").
- 병렬 호출(0.2.1, 수정 전): haiku가 Bash 호출 둘을 한 메시지로 보냈다. 확인 창은 하나씩 떴다. 첫 확인에 응답하고 0.6초 뒤 둘째 요청이 생겼고, `claude agents`의 `busy`는 그 사이 한 번뿐이었다. 첫 요청은 훅이 살아 있는 채 계속 열려 있었고(10:06:24 확인), 승인하자 `approved`라고 **잘못** 답했다. Claude Code는 그 답을 무시했고 첫 파일은 한 줄 그대로였다. 둘째 명령은 실행되지 않았고, 둘째 요청을 승인하자 `allow`로 한 번 실행됐다. 0.2.2에서 고쳤다(위 "승인 전달").
- 프롬프트 제안: `promptSuggestionEnabled: false`에서 60회 넘게 화면을 잡았는데, 입력창은 직접 친 글자 말고는 늘 비어 있었다. 요청이 열린 동안 상태 턴의 문맥에는 id가 있었지만 응답에는 없었다. 설정과 `route` 변경이 함께 적용돼 있어 어느 쪽 효과인지는 가르지 못했다. `/router:approve <id> deny`는 동작했다(파일 없음).
- 작업 세션은 front를 `router-front-5 [09e9dd]`로 불렀다(Claude Code가 준 이름·ref 토큰). 이 주소로 보고가 전달됐다. 0.2.1 가드는 이 꼴을 비교하지 못했다(stub 재현: `notion-wbs-98`는 거부, `notion-wbs-98 [b451e5]`는 통과). 0.2.2에서 고쳤다(위 "보고 대상 고정"). ref는 session id 앞자리가 아니었다(`router-front-5 [09e9dd]` ↔ front session id `06e4734a-…`).
- haiku 작업 세션이 Bash 호출과 같은 메시지로 `done` 보고를 보냈다. 거부된 뒤에는 `done`과 `blocked`가 둘 다 front에 갔다. 0.2.2에서 `topic-worker`에 도구 결과가 돌아온 뒤에만 보고하라고 적었다.
- front 턴 중에 입력한 `/router:approve`는 그 턴이 끝날 때까지 대기열에서 기다렸다(약 2.7초).

### 실측 확인 (대화형 6차 시험 2026-10-06, 0.2.2, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.290), 작업 세션은 haiku. 다른 작업의 CPU 부하(load 65–128)가 걸린 채 진행했다.

- G1 보고 주소: 작업 세션은 front를 `router-front-6 [75d2bb]`로 불렀다. 그 이름의 세션은 하나뿐이었는데도(`peer_mention total: 1`) Claude Code가 ref를 붙였고, `/clear` 뒤에도 ref는 같았다. 이름만 쓴 보고도 전달됐다.
- G1 decoy: 대장에 없는 살아 있는 세션 `decoy-6`으로 보낸 `SendMessage`는 `router: 'decoy-6' is another session …`으로 거부됐고, decoy의 transcript는 그대로였다(43줄). 0.2.2 가드가 실제 `name [ref]` 주소를 통과시키고 다른 세션을 거부했다(따옴표·대소문자, 이름을 공유한 다른 세션은 단위 테스트만).
- G1 `/clear` 뒤: 이름은 남고 session id가 바뀌었다. `/router:approve`는 `works only in the router front session`으로 막혔다. 작업 세션의 보고는 `/router:front`를 다시 입력할 때까지 거부됐고 front는 아무것도 받지 못했다. Stop 훅의 `last_result`는 남아 `/router:front` 뒤 front가 보였다. 거부 뒤 다음 턴에 작업 세션이 보고하지 않았다. 0.2.4에서 거부 사유를 고쳤다(위 "보고 대상 고정").
- G2 늦은 승인: attach로 먼저 응답한 뒤 같은 스레드의 다음 요청이 4.3초(1회차)·2.3초(2회차) 뒤에 떴다. 이전 요청은 1회차에 `claude agents`로 0.5초 만에, 2회차에 다음 요청과 같은 0.1초 안에(superseded) 지워졌다. 늦은 `/router:approve`는 둘 다 `not sent. No open request …`였고 결정 파일은 없었다. 파일은 모두 한 줄이었다.
- G3 보고 시점: 4턴 모두 `SendMessage`가 모든 `tool_result` 뒤에 나왔다. 거부는 한 번 보고됐지만 `완료` 머리말 아래였다. 0.2.4에서 `topic-worker`에 `blocked`를 명시했다.
- G4 subagent: Agent 도구가 백그라운드로 띄운 subagent의 확인 요청에 `agent_id`(`a1cd1b52c8806f0d5`)가 있었다. 목록에 보였고, 거부가 subagent에 전달돼 파일은 생기지 않았다. 요청이 열린 동안 `claude agents`는 작업 세션을 `busy`(`waitingFor` 없음)로 보였다. subagent transcript는 `<세션 id>/subagents/agent-<agent_id>.jsonl`에 있었고, 거부 시각에 `tool_result` 줄이 쓰였다. 0.2.4에서 이것으로 응답을 알아챈다(위 "승인 전달").
- 부하에서 UserPromptSubmit 훅이 5초 시간 제한을 넘겨 출력이 버려졌다(front `timed out after 5s`, 작업 세션 `hook_cancelled`). 0.2.4에서 15초로 늘렸다.

### 실측 확인 (대화형 7차 시험 2026-10-06, 0.3.0, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.290), 작업 세션은 haiku와 Codex 0.159.0(`gpt-6-luna`, 0.3.0의 `codex exec` 경로. 0.4.0 app-server 경로는 위 "Codex 작업 세션 → 실측 확인"). 로컬 설정에 고정 allow 규칙, 권장 deny 규칙, `"promptSuggestionEnabled": false`를 두었다.

- H1 백그라운드 subagent의 확인: 작업 세션이 Agent 도구로 띄운 subagent는 늘 백그라운드였다. PermissionRequest 훅이 기다리는 동안 `claude attach`는 그 확인 창을 보이지 않았다(요청 3개, 본 화면·subagent 화면 모두). 훅이 만료로 끝나 pending이 지워진 뒤 15초 안에 확인 창이 떴고, attach로 승인하자 파일은 한 줄이었다. 늦은 `/router:approve <id>`는 `No open request … (answered, expired or unknown)`로 막혔고 결정 파일은 없었다. 본 스레드의 확인 창은 훅이 기다리는 동안에도 보였다. `answered()`는 잘못 숨기지 않았다(transcript에 앞선 같은 Bash의 결과가 있어도 요청은 남았다). 만료 뒤에는 요청이 목록에서 빠지고 작업 세션이 refresh 전 `idle`(Stop이 이미 돎), refresh 뒤 `active`로만 보였다(`claude agents`는 `busy`, `waitingFor` 없음). 0.5.0에서 고쳤다(위 "백그라운드 subagent의 확인", Stop의 `background_tasks`). 동기 subagent는 시험하지 않았다.
- H2 최근 결정: 허용 2·거부 1 뒤 "방금 승인/거부한 것 확인해줘"에 front가 도구 호출 없이 주입된 `[router] decided …` 블록과 같은 3행 표로 답했다. 10분 창도 맞았다(13:03:18에는 12:53:31 항목만 남음).
- H3 재등록 전 보고: `/clear`로 session id가 바뀐 뒤 작업 세션의 보고는 `… is your front's name, but that session is not registered as the front: the front has not re-registered yet … keep reporting …`으로 거부됐다. attach 응답 2.1초 뒤 pending이 지워졌고, `/router:front`가 `last_result`를 보였으며, 다음 전달의 보고는 front에 왔다.
- H4 Codex(0.3.0 `codex exec`): spawn은 6초에 끝나 `last_result`가 기록되고 다음 턴에 보였다. 유휴 `resume`은 같은 thread에 `exec resume -c sandbox_mode="workspace-write" -m gpt-6-luna`였다. 실행 중 전달은 `held`로 쌓였다가 실행이 끝난 0.5초 뒤 새 실행으로 나갔다. sandbox는 홈의 파일과 플러그인 데이터 `approvals/` 아래 파일 쓰기를 모두 `operation not permitted`로 막았고, 작업 세션은 `blocked`로 보고했다(두 파일 모두 없음). rollout의 모든 실행이 `sandbox_policy: workspace-write`였다. 보류 연쇄가 읽지 않은 결과를 17초 만에 덮어쓴 것과 `resume --topic`이 `unrecognized arguments`로 실패한 것은 0.5.0에서 고쳤다. `codex exec`는 작업 디렉터리의 신뢰 항목을 `~/.codex/config.toml`에 더했다. app-server 경로도 git 저장소에서는 더한다. 0.5.0 실측은 git이 아닌 디렉터리라 더하지 않았다(위 "Codex 작업 세션 → 신뢰 항목").
- H5 백그라운드 알림: front가 띄운 백그라운드 Bash가 끝나자 입력 없이 25.0초 뒤 `<task-notification>`이 와 유휴 front에 새 턴이 열렸다(문맥 주입 0.2초 뒤, 응답 약 4초 뒤). 0.5.0의 결과 알림(`wait`)이 이것을 쓴다.
- 거부된 호출이 있는 보고가 또 `완료` 머리말 아래 왔다(6차와 같음). 0.5.0에서 거부 메시지에 `Report this as blocked to the front (not done).`를 붙였다.

### 실측 확인 (대화형 8차 시험 2026-10-06, 0.5.0, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.291), 작업 세션은 haiku와 Codex 0.159.0(모델을 지정하지 않아 설정 기본값 `gpt-6.1-sol`, 작업 디렉터리는 git 저장소). 로컬 설정에 고정 allow 규칙, 권장 deny 규칙, `"promptSuggestionEnabled": false`를 두었다.

- I1 Codex 결과 알림: front가 `spawn … --backend codex` 뒤 `wait`를 `run_in_background`로 걸고 턴을 끝냈다. 1.4초 뒤 입력 없이 알림이 와 결과를 전했다. 후속 요청은 `resume --topic`과 새 `wait`로 보냈고, 9초 뒤의 둘째 후속 요청은 `held`가 되어 `wait`를 더 걸지 않았다. `wait`가 `active (held follow-ups are running now: wait again) — last: …`로 끝나자 front가 그 결과를 전하고 다시 걸었고, 다음 `wait`의 `idle — last: …`도 전했다.
- I2 Codex 승인 전달: `workspace-write`는 작업 디렉터리 안이어도 `.git/` 쓰기를 막아(EPERM) `touch .git/…`로 요청을 냈다. 알림으로 깨어난 front가 정확한 명령(`/bin/zsh -lc 'touch .git/r8-allow.txt'`)을 보였다. `/router:approve <id>` 2.7초 뒤 실행이 끝나 `done`이 전해졌고 파일이 생겼다. `… deny`는 파일 없이 `blocked` 보고로 끝났다.
- I3 Claude 거부: 도구 결과 끝에 `Report this as blocked to the front (not done).`가 붙었고, 작업 세션은 `[…] blocked: Bash denied — …`로 보고했다. 파일은 없었다.
- I4 백그라운드 subagent: `agent_id`가 있는 요청이 열린 동안 작업 세션의 Stop이 지나도 상태는 `active`였다. 300초 뒤 요청이 `expired/`로 옮겨지고, 목록에 `WAITING: subagent prompt — claude attach <job_id> to answer`와 요청 줄이 보였다. 그 id의 `/router:approve`는 `not sent. … expired: … claude attach <job_id> (answer it there)`로 거부됐고 결정 파일은 없었다. attach에 확인 창이 보였고, 승인 6초 안에 subagent 줄이 사라졌으며 파일은 한 줄이었다. 그 뒤 약 13초 남은 `WAITING: permission prompt` 줄은 위 "백그라운드 subagent의 확인".

### 실측 확인 (대화형 9차 시험 2026-10-06, 0.5.0, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.291), 작업 세션은 haiku와 Codex 0.159.0(`gpt-6-luna`), 시험 폴더는 git 저장소. 로컬 설정에 고정 allow 규칙, 권장 deny 규칙, `"promptSuggestionEnabled": false`를 두었다(L4에서만 뺐다). 훅만 보는 작업 세션(C2b, L2–L7)은 셸에서 `registry.py spawn`으로 띄웠다(front에 기록된 모드). 시험 뒤 시험 폴더의 항목이 `~/.codex/config.toml`과 `~/.claude.json`에 남았다(위 "신뢰 항목").

- C1 Codex 파일 변경: `.git/` 아래 쓰기가 `apply_patch: [input: {"changes": …}]` 요청(경로·`add`·diff)으로 보였고, 승인하자 한 번 적용됐다(파일 한 줄).
- C1b 네트워크: sandbox 안의 `curl`이 실패(exit 6)한 뒤 `require_escalated` 재요청이 일반 명령 승인(`Bash`)으로 왔다.
- C1c 병렬: 1 ms 간격의 두 요청이 함께 열려 목록에 둘 다 보였고, 차례로 승인돼 두 파일이 생겼다.
- C1d 만료: 답 없는 요청은 300.6초에 지워졌고 작업 세션은 `blocked`로 보고했다.
- C2 read-only: plan 턴(계획 승인 직후 같은 턴 포함)의 실행은 `read-only`·`never`였다. 쓰기는 EPERM으로 막혔고, 요청 없이 `blocked`로 끝났다.
- C2b stop: pending과 감독 프로세스, `codex-turn.py`, app-server, 실행 중이던 `sleep`까지 끝냈다. 대장은 refresh 전까지 `active`였고, 미리 건 `wait`는 시간 제한까지 돌았다. 0.5.1에서 고쳤다(위 "정지·요약", 10차 R2에서 실측).
- C2c merge: Codex 원본의 `last_result`·`results`를 썼고 원본에 메시지를 보내지 않았다. 새 세션이 떴고 원본은 `merged`가 됐다.
- C4 감독 SIGKILL(보류 1건): 고아 `codex-turn.py`·app-server가 턴 끝까지 thread 쓰기 잠금을 쥐었고, 그 결과는 기록되지 않았다. 그사이 전달은 `already has an active writer`로 실패했고, 보류 요청과 새 요청이 함께 사라졌다. 턴이 끝난 뒤의 전달은 시험하지 않았다. 0.5.1은 재개가 받아들여진 뒤에야 실행을 시작된 것으로 보고, 거절되면 두 요청을 `held`로 남긴다. 감독이 죽으면 `codex-turn.py`가 app-server를 끝낸다(위 "동작". 실측은 위 "Codex 작업 세션 → 실측 확인"의 0.5.1 CLI 실측).
- C5 on-request: 4건 모두 승인을 요청했다(2건은 프롬프트로 유도).
- L1 dontAsk: Bash 거부(79 ms)가 `blocked`로 보고됐다. pending은 없었다. 20–40 ms 샘플러에 router 훅 프로세스는 보이지 않았다(작업 세션의 다른 훅은 보였다).
- L2 실패 이름 재사용·resume: 없는 `--cwd`는 `name not reserved`로 끝났다. 실행 실패는 `exited`(id 없음)였고, 같은 이름이 다시 떴다. 살아 있는 세션의 `resume`은 `is running`으로 거절됐다.
- L3 `already answered`: attach 응답 0.3초 뒤의 `/router:approve` 3번이 모두 `already answered … nothing approved`로 막혔다. 결정 파일은 없었고 파일은 한 줄씩이었다.
- L4 프롬프트 제안: `Enter`만으로는 제안된 `/router:approve <id>`를 보내지 않았고 `Tab`+`Enter`가 보냈다(그 id는 이미 끝나 `not sent`). 제안은 front가 `route` 없이 답하며 id를 쓴 데서 나왔다. 0.5.1에서 줄였다(위 "프롬프트 제안").
- L5 ref만 쓴 주소: 이름 없는 ref(`eecdaf`)는 가드를 지났지만 Claude Code가 `No agent named … reachable`로 전달하지 않았다. `[eecdaf]`는 가드가 거부했다.
- L7b subagent 요청의 만료 뒤 attach 응답: Bash·Write 요청 모두 transcript에 결과가 생긴 1초 안에 목록에서 숨겨졌다.

### 실측 확인 (대화형 10차 시험 2026-10-07, 0.5.1, Orca terminal, marketplace install)

front는 sonnet `default` 모드(Claude Code 2.1.291), 작업 세션은 haiku(2.1.292)와 Codex 0.159.0(`gpt-6-luna`), 시험 폴더는 git 저장소. 로컬 설정에 고정 allow 규칙과 권장 deny 규칙을 두었고, 프롬프트 제안은 R1에서만 켰다.

- R1 front 문맥: 승인 요청이 열린 front 턴 5번(Codex `wait` 알림 2번, '복사해 붙일 승인 명령' 요청 포함)의 응답에 요청 id도, id가 든 승인 명령도 없었다(`<id>` 자리표시만). 알림 턴에도 문맥과 안내가 주입됐다. 프롬프트 제안을 켠 채 제안은 인자 없는 `/router:approve`뿐이었고, 그 목록의 id로 Codex·Claude 요청을 승인했다.
- R2 stop: 실행 중(보류 1건) `stop` 뒤 1초 안에 대장이 `exited`(`held` 유지)가 됐고, 걸어 둔 `wait`가 `exited — last: -`로 끝났다. 다음 전달은 보류 요청을 새 요청 앞에 붙여 한 실행으로 보냈다.
- R3 재개 거절: 다른 app-server 클라이언트가 thread를 쥔 동안 front의 전달은 `already has an active writer`, `held 1`로 끝났다. front는 다시 보내지 않았고 `wait`도 걸지 않았다. 잠금이 풀린 뒤의 전달은 두 요청을 차례로 한 실행에 보냈다.

### 미검증 (Claude 작업 세션)

- 같은 스레드의 새 요청이 이전 요청을 밀어내는 경로(훅 종료, 목록 숨김, `superseded` 거부). 6차 G2의 2회차 관찰과 맞지만 그 경로임을 가르지는 못했다. 9차 L6에서는 다음 확인 창이 3.3초 늦게 떠, 첫 요청이 `seen` 경로(`claude agents`)로 먼저 닫혔다. 10차에서도 다음 확인 창이 attach 응답 3.9초 뒤에 떴다. 첫 Bash 호출의 `tool_result`가 그 0.2초 전에 기록돼 지연은 그 호출 자체의 실행이었다(기록된 훅은 43–57 ms). 그래서 3초 간격의 `claude agents` 확인이 먼저 닫았다.
- 동기(foreground) subagent의 확인. `--bg` 작업 세션의 subagent는 7·9차 모두 비동기였다. 10차에서 `run_in_background: false`를 지시한 haiku 작업 세션 둘이 인자 없이, 그리고 문자열 `"false"`로 Agent를 불렀다. 둘 다 `Async agent launched`였다(attach에는 `Backgrounded agent`, 대기 중 확인 창 없음).
- UserPromptSubmit 15초 시간 제한이 부하에서 충분한지(직접 관찰하지 않음).

## 개발

```bash
python3 plugins/router/tests/test_registry.py   # 대장: 유일 이름·실패 이름 재사용, 갱신(id로만), merged, 원자적 쓰기, stub claude로 spawn/resume·프롬프트 조립, front 모드 고정, CLI로 front·id·모드·대장 파일 지정 불가, backend.sh 고정 인자, 승인 대기(WAITING) 표시(승인 명령 줄 없음), 승인 요청 표시 정리(ANSI·bidi·줄바꿈·절단), claude attach로 응답된 요청 숨김, 같은 스레드의 새 요청에 밀린 요청 숨김(subagent 요청은 유지), Stop 뒤 대기 기록 정리, wait(결과·WAITING·연쇄 wait again·시간 초과·즉시·파일 무변경), stop 뒤 바로 exited(merged 원본은 유지)
python3 plugins/router/tests/test_hooks.py      # 훅: 입력한 /router:front만 front 등록, front만 모드 기록·주입(살아 있는 pid만 표시, id가 든 승인 명령 없음, 응답에 id를 쓰지 말라는 안내), 작업 세션만 기록, 승인 전달(PermissionRequest 대기·allow/deny·오래된/다른 id/잘못된 결정 무시·시간 초과, front에서 입력한 /router:approve만 결정, claude attach 먼저 응답 → 훅 종료·already answered, 병렬 호출의 새 요청 → 이전 요청 훅 종료·superseded 거부, subagent 요청은 유지, subagent 요청은 그 transcript의 새 결과로 훅 종료·숨김·already answered — 이전 같은 호출·다른 호출의 결과·FIFO는 무시), 결정·보고 뒤 대기 기록 정리, front 문맥의 최근 10분 결정 표시, SendMessage 보고 대상 가드(name [ref]·따옴표·대소문자, 이름을 공유한 다른 세션, 재등록 전 front 이름은 사유를 알리고 계속 보고), 거부 메시지의 blocked 지시, 백그라운드 subagent가 돌면 Stop 뒤에도 active, 만료된 subagent 요청의 attach 대기 표시(거부·superseded·1시간·종료된 세션·응답 뒤 숨김, 본 스레드는 기록 없음)
python3 plugins/router/tests/test_codex.py      # Codex 작업 세션(stub codex app-server): backend-codex.sh 고정 인자, spawn/resume/list/stop/summarize, 모드 → sandbox·승인 정책(bypass는 front가 bypass일 때만, 돌려준 값이 다르면 실패), 결과·실패 기록, 실행 중 요청 보류와 종료 뒤 전달, 거절된 재개(쓰기 잠금)의 요청·보류 요청 재보류(resume·연쇄 실행), 감독 SIGKILL 뒤 codex-turn·app-server 종료, stop 직후 exited·wait 종료·보류 요청 유지, 백엔드 분기, Codex의 permission_mode를 대장에 쓰지 않음, 승인 전달(허용·거부·파일 변경·오래된 결정·만료·쓰기 가능 sandbox·never·다른 요청 거절·정지), 보류 연쇄의 앞 결과 표시, resume --topic, 거부 시 blocked 지시
claude --plugin-dir plugins/router              # 작업 트리를 플러그인으로 로드
```

셸 환경 변수는 백그라운드 세션에 전달되지 않는다. 대장 경로를 바꿔 시험하려면 `PATH` 앞에 `claude` 래퍼를 두어 `--bg` 호출에만 `--plugin-dir`와 `--settings '{"env":{"ROUTER_REGISTRY":"…"}}'`를 더한다(`backend.sh`는 추가 인자를 받지 않는다).
