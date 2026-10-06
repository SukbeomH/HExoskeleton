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
- **UserPromptSubmit 훅**: `session_id`가 front일 때만 그 턴의 `permission_mode`를 대장에 기록하고(`front.permission_mode`·`mode_updated`), 대장 요약을 `additionalContext`로 주입한다. 다른 세션에서는 아무것도 하지 않는다.
- **작업 세션**: `agents/topic-worker.md`. 한 주제만 맡고, 완료·막힘 시 front에 `SendMessage`로 짧게 보고하고, 라우팅하지 않는다. 대장에 기록된 front의 권한 모드로 뜬다(아래 보안 모델).
- **Stop 훅**: 작업 세션(`session_id`, 아직 모르면 `$CLAUDE_JOB_DIR`의 job id가 대장에 있음)에서만 `last_assistant_message`를 `last_result`로 기록한다. 보고가 빠져도 front가 결과를 읽을 수 있다.
- **승인 전달**: 작업 세션의 PermissionRequest 훅과 front의 `/router:approve` 훅(아래 "승인 전달").
- **보고 대상 고정**: 작업 세션의 PreToolUse(`SendMessage`) 훅이 front·형제가 아닌 살아 있는 세션(`claude agents`)으로의 전송을 거부한다. front가 사라진 뒤 보고하면 `SendMessage`가 "Did you mean <다른 세션>?"을 제안하고, 작업 세션이 그 제안을 따라 무관한 세션에 보고를 보낸 일이 있었다. 주소는 Claude Code가 쓰는 꼴을 벗겨 비교한다: `@`, `"공백 든 이름"`, 이름이 겹칠 때 붙는 ` [ref]`(예: `router-front-5 [09e9dd]`), 앞뒤 공백, 대소문자. ref는 `claude agents`에 없어 검증할 수 없으므로, front·작업 세션(id 기준)이 아닌 살아 있는 세션과 이름이 같으면 front 이름이라도 거부한다. 벗기고 나서 빈 주소(ref만)도 거부한다. 작업 세션 자신의 subagent 이름·id는 막지 않는다. front를 `/clear`하거나 다시 띄운 뒤 `/router:front`를 다시 입력하기 전에는 front의 새 session id가 대장에 없어 보고가 거부된다(0.2.1까지는 이름으로 전달됐다). 그동안 결과는 Stop 훅의 `last_result`로만 남는다.
- **백엔드**: 세션 생성·재개·목록·정지·요약은 `scripts/backend.sh` 한 파일만 Claude Code CLI를 부른다. 다른 백엔드(Orca 등)로 바꿀 때 이 파일만 교체한다. `registry.py`만 부르고, 인자 목록이 고정되어 있다(추가 claude 인자 없음, 권한 모드는 문서의 6개 값만). `spawn`/`resume`은 프롬프트를 표준 입력으로 받고, stdout은 job id 한 줄뿐이다(안내 문구는 stderr).
- **프롬프트 조립**: `registry.py spawn`/`resume`이 front의 요청 본문(`--request TEXT`, 또는 `--request -`와 heredoc 표준 입력)에 대장의 현재 front 이름·주제·형제 목록을 붙여 작업 세션 프롬프트를 만들고, 이름 예약·실행·job id 기록까지 한 명령으로 묶는다. 프롬프트 파일을 쓰지 않고, id를 모델이 옮겨 적지 않는다. `spawn`은 디렉터리(기본: front의 cwd)와 요청을 이름 예약 전에 확인한다.
- **재개**: 프로세스가 없는(`pid` 없음) 세션만 `claude --resume <session_id> --bg`로 깨운다. `registry.py resume`은 먼저 목록을 갱신하고, 살아 있는 세션이면 재개하지 않는다(오래된 문맥에서 사본을 띄우지 않게). 훅이 주입하는 목록은 `pid`를 그 프로세스가 있을 때만 보여 준다. 목록에 남은 세션은 플래그 없이 깨워야 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 이어진다. 플래그를 주면 사본이 생긴다. 목록에서 지워진 세션은 이름과 현재 front 모드를 다시 준다.

## 권한 프롬프트 줄이기

front는 `registry.py`를 플러그인 경로째 부르는 단일 명령만 쓴다. `front`/`route`/`merge` 스킬의 `allowed-tools`는 스킬을 불러온 그 턴에만 이 스크립트를 사전 승인한다. front는 `route`를 세션에 한 번만 불러오고, 작업 세션 보고처럼 메시지로 시작된 턴에는 스킬이 없다. 그래서 **사람이 지켜보지 않는 라우팅에는 아래 allow 규칙이 필수다.** 사용자 설정(`~/.claude/settings.json`)에 넣고, `<HOME>`은 홈 디렉터리의 절대 경로(`echo $HOME`)로, `<VERSION>`은 설치된 버전(예: `0.2.3`)으로 바꾼다. 마켓플레이스 설치본의 `${CLAUDE_PLUGIN_ROOT}`는 `~/.claude/plugins/cache/hexoskeleton/router/<version>/`이다. 버전 자리에 `*`를 쓰지 않는다(아래 보안 모델). 플러그인을 업데이트하면 규칙의 버전도 바꾼다. 바꾸지 않으면 확인이 다시 뜰 뿐이다. `Skill(...)` 규칙은 front가 스킬을 불러올 때의 `Use skill "router:route"?` 확인을 없앤다(`Skill(name)`은 정확히 그 이름, `Skill(name *)`은 인자가 붙은 호출까지). 사용자가 직접 입력한 `/router:front`·`/router:approve`는 Skill 도구 호출이 아니라서 확인이 없으므로 `front`·`approve` 규칙은 두지 않는다.

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

   사용자가 `claude attach`로 먼저 응답해도 Claude Code는 이 훅을 멈추지 않는다(4차 시험). 그래서 훅은 3초마다 `claude agents`를 본다. 자기 작업 세션이 `status: waiting`·`waitingFor: permission prompt`인 것을 한 번 보면 요청에 `seen`을 기록하고, 그 뒤 더는 그 상태가 아니면 출력 없이 끝나 요청을 지운다. 첫 확인이 확인 창보다 먼저일 수 있어서, 본 적 없이 아니라고만 나오면 끝내지 않는다. 훅의 입력에는 `tool_use_id`가 없어(문서: PermissionRequest input) transcript의 도구 결과로는 짝을 지을 수 없다.

   병렬 도구 호출은 확인 창이 하나씩 뜬다. 첫 확인에 응답하면 다음 확인이 0.6초 안에 떠서(5차 시험), 작업 세션은 확인 창을 떠나지 않고 `claude agents`로는 응답을 알 수 없다. 그래서 같은 스레드의 더 새 요청이 있으면 이전 요청은 응답된 것으로 본다. 스레드는 `session_id`, 그리고 subagent 안이면 `agent_id`로 가른다(문서: 훅 공통 입력의 `agent_id`는 subagent 안에서만 있다). `seen` 요청의 훅은 0.5초 안에 출력 없이 끝나고, front 목록은 그 요청을 숨긴다. 작업 세션 본 스레드와 그 subagent의 요청은 서로 밀어내지 않는다.
2. **표시**: 열린 요청이 있는 작업 세션은 refresh 없이도 `WAITING`으로 보인다. 그 아래에 다음 두 줄이 붙는다.

   ```text
   approval 2a53cf92: @relay1 Bash: echo relay-ok > /tmp/router-relay-test.txt
   approve: /router:approve 2a53cf92   deny: /router:approve 2a53cf92 deny   (or claude attach fd6f02cb)
   ```

   모델이 쓴 `description`은 보이지 않고 `tool_input`만 보인다(Bash는 `command`, 그 밖의 필드는 `[input: {…}]`). 표시용으로 ANSI 시퀀스와 제어·zero-width·bidi 문자를 지우고, 지운 개수를 `[N hidden chars removed]`로 알린다. 줄바꿈은 `⏎`로 보여, 두 명령이 한 명령처럼 읽히지 않게 한다. 300자를 넘으면 `…[cut: 전체 길이 chars]`로 자른다. `seen` 요청인데 작업 세션이 더는 확인 창에 있지 않거나(`claude attach`로 응답됨), 같은 스레드의 더 새 요청이 있으면 훅이 끝나기 전이라도 보이지 않는다. front 모델은 응답에 id가 든 승인 명령을 쓰지 않고, 인자 없는 `/router:approve`를 안내한다(아래 "프롬프트 제안").
3. **사용자 입력**: front에 `/router:approve <id>`(허용) 또는 `/router:approve <id> deny`(거부)를 직접 입력한다. UserPromptExpansion 훅이 다음을 차례로 확인한 뒤 결정 파일을 쓴다.
   - 입력한 세션이 대장의 front인지.
   - id가 8자리 소문자 hex이고 열린(만료 전) 요청인지.

   결정을 쓴 뒤 프롬프트를 막는다. 그래서 모델 턴이 없고, 화면에는 무엇을 허용·거부했는지(`router: approved <id>: @<세션> <도구>: <명령>`) 나온다. 인자 없이 입력하면 열린 요청 목록을 보여 준다. front가 아니거나, 모르는 id·만료된 id면 `not sent`로 막는다. 이미 `claude attach`로 응답됐거나 같은 작업 세션의 다음 요청에 밀린 요청도 결정을 쓰지 않고 막는다. 보통은 훅이 먼저 끝나 요청이 지워졌으므로 `not sent. No open request <id> (answered, expired or unknown).`가 나온다(5차 시험). 훅이 아직 끝나지 않았으면 `not sent. <id> was already answered (e.g. via claude attach) or superseded by the same worker's next request; nothing approved.`가 나온다.

**끄기**: 사용자 설정의 `"env": {"ROUTER_APPROVAL_WAIT": "0"}`. 훅이 기다리지 않고 바로 끝나, 일반 확인 창과 `claude attach`만 남는다.

**프롬프트 제안**: Claude Code는 응답 뒤 다음 입력을 예측해 입력창에 회색으로 보여 준다(문서: Prompt suggestions). 4차 시험에서 front가 승인 명령을 쓰자 입력창에 `/router:approve <id>`가 제안됐다. 제안은 `Tab`이나 `→`로 입력창에 넣고 `Enter`로 보낸다(빈 입력에서 `Enter`만으로 제출되던 동작은 v2.1.136에서 고쳐졌다). 제안된 승인 명령을 요청 줄을 읽지 않고 보내지 않는다. front에서는 제안을 끄기를 권한다.
- 설정: `"promptSuggestionEnabled": false`(어느 설정 파일이든, `/config`의 **Prompt suggestions**가 쓰는 키).
- front 세션만: `CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION=false claude -n <front 이름>`(설정보다 우선, v2.1.238+).

`route`는 응답에 id가 든 승인 명령을 쓰지 않는다. 다만 제안은 주입된 대장 문맥(승인 줄에 id가 있다)에서도 나올 수 있어, 이것은 위험을 줄일 뿐 없애지 못한다.

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
- 표시는 정리하고 잘라서 보이므로, 300자를 넘는 입력은 끝까지 보이지 않는다. 긴 명령은 `claude attach`로 원문을 보고 응답한다.
- front는 다음 턴에야 새 요청을 안다. 인자 없는 `/router:approve`는 즉시 최신 목록을 보여 준다.
- `claude attach`로 응답한 뒤 훅이 알아채기 전(다음 확인 창이 뜨기 전, 또는 최대 약 3초)에 입력한 `/router:approve`는 `approved`라고 답하지만 아무 일도 일어나지 않는다(Claude Code는 이미 응답된 확인 창에 대한 늦은 훅 답을 무시했다, 4·5차 시험).
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

### 미검증 (unverified)

- `dontAsk` 작업 세션이 거부된 일을 `blocked`로 보고하는지(문서 기준).
- 실패한 이름 재사용과 `resume`의 살아 있는 세션 거절(단위 테스트만).
- `dontAsk` 모드에서 PermissionRequest가 실행되는지. 실행되더라도 훅은 기다리지 않는다.
- 0.2.1 수정 중 `already answered` 문구는 단위 테스트로만 확인했다(5차 시험에서는 훅이 먼저 끝나 나오지 않았다). attach 먼저 응답 뒤 훅 종료·요청 정리, 대기 기록 정리, `route`가 응답에 id를 쓰지 않는 것은 5차 시험에서 확인했다.
- 프롬프트 제안을 `Tab`·`Enter`로 받았을 때의 동작(문서 기준).
- 0.2.2 수정은 stub `claude`를 쓴 단위 테스트로만 확인했다. 대상은 세 가지다.
  - `SendMessage` 가드의 주소 정규화(`name [ref]`·따옴표·공백·대소문자, 이름을 공유한 다른 세션 거부).
  - 같은 스레드의 새 요청이 이전 요청을 밀어내는 것(훅 종료, 목록 숨김, `superseded` 거부). subagent 요청(`agent_id`)은 실측한 적이 없다.
  - `topic-worker`의 보고 시점.
- `SendMessage`가 이름 없는 ref(예: `09e9dd`)만으로도 전달하는지(문서에 없음). 그렇다면 가드는 그 주소를 알아보지 못한다.

## 개발

```bash
python3 plugins/router/tests/test_registry.py   # 대장: 유일 이름·실패 이름 재사용, 갱신(id로만), merged, 원자적 쓰기, stub claude로 spawn/resume·프롬프트 조립, front 모드 고정, CLI로 front·id·모드·대장 파일 지정 불가, backend.sh 고정 인자, 승인 대기(WAITING) 표시, 승인 요청 표시 정리(ANSI·bidi·줄바꿈·절단), claude attach로 응답된 요청 숨김, 같은 스레드의 새 요청에 밀린 요청 숨김(subagent 요청은 유지), Stop 뒤 대기 기록 정리
python3 plugins/router/tests/test_hooks.py      # 훅: 입력한 /router:front만 front 등록, front만 모드 기록·주입(살아 있는 pid만 표시), 작업 세션만 기록, 승인 전달(PermissionRequest 대기·allow/deny·오래된/다른 id/잘못된 결정 무시·시간 초과, front에서 입력한 /router:approve만 결정, claude attach 먼저 응답 → 훅 종료·already answered, 병렬 호출의 새 요청 → 이전 요청 훅 종료·superseded 거부, subagent 요청은 유지), 결정·보고 뒤 대기 기록 정리, SendMessage 보고 대상 가드(name [ref]·따옴표·대소문자, 이름을 공유한 다른 세션)
claude --plugin-dir plugins/router              # 작업 트리를 플러그인으로 로드
```

셸 환경 변수는 백그라운드 세션에 전달되지 않는다. 대장 경로를 바꿔 시험하려면 `PATH` 앞에 `claude` 래퍼를 두어 `--bg` 호출에만 `--plugin-dir`와 `--settings '{"env":{"ROUTER_REGISTRY":"…"}}'`를 더한다(`backend.sh`는 추가 인자를 받지 않는다).
