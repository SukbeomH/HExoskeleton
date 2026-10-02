# router — One session to rule them all

Claude Code 전용 플러그인. 사용자는 **front 세션 하나**에서만 말한다. front가 메시지마다 주제를 판단해 그 주제를 맡은 백그라운드 작업 세션에 전달하거나, 새 작업 세션을 띄우거나, 여러 세션에 전파하고, 결과를 front로 모은다. 수렴한 세션은 명시적인 명령으로 하나로 병합한다. 다른 세션 화면을 볼 필요가 없다.

## 설치

```text
/plugin marketplace add SukbeomH/HExoskeleton
/plugin install router@hexoskeleton
```

사용자 범위로 설치한다. 작업 세션은 여러 저장소에서 뜨고, 각 세션이 `router:topic-worker` 에이전트를 찾을 수 있어야 한다. 훅은 front와 작업 세션에서만 동작하므로 다른 세션에는 영향이 없다.

## 사용

1. 대화할 세션에서 `/router:front` — 이 세션을 front로 등록하고 등록된 작업 세션을 보여 준다.
2. 그다음은 평소처럼 말한다. front가 `router:route` 절차로 판단한다.
   - **forward**: 기존 주제면 그 세션에 `SendMessage`로 전달. 종료된 세션은 다시 깨운다.
   - **new**: 새 주제면 `claude --bg --agent router:topic-worker`로 작업 세션을 띄운다. 형제 세션 목록을 함께 준다.
   - **broadcast**: 여러 주제에 걸치면 대상마다 한 번씩 보내고, 본문에 참여 세션 목록을 넣어 서로를 알린다.
   - **status**: 진행 상황을 물으면 대장을 갱신해 보여 준다. 사용자 응답을 기다리는 작업 세션은 `WAITING`으로 보이고, front가 `claude attach <job_id>`를 안내한다.
3. 수렴한 세션 병합: `/router:merge <세션...> into <새 이름>` — 요약을 모아 병합 brief를 만들고, 그것으로 새 작업 세션을 띄우고, 원본은 `merged`로 표시한다.

`/clear` 후에는 세션 id가 바뀌므로 `/router:front`를 다시 실행한다.

front에는 `/rename <고정 이름>`(또는 `claude -n <고정 이름>`으로 시작)으로 이름을 붙여 둔다. 이름 없는 대화형 세션의 기본 표시 이름(`<디렉터리>-<두 글자>`)은 다시 띄울 때마다 바뀌어, 작업 세션의 보고가 옛 이름으로 간다. front를 다시 띄웠으면 `/router:front`를 다시 실행한다. 대장에 새 session id와 이름이 기록되고, 이후 생성·재개되는 작업 세션은 프롬프트 첫 줄로 현재 front 이름을 받는다.

## 동작 방식

- **대장**: `${CLAUDE_PLUGIN_DATA}/registry.json` (사용자 단위). 이름(유일, 실행에 실패해 id가 없는 이름만 다시 쓸 수 있음)·session_id·job id·cwd·주제·모델(지정한 경우)·상태(active/idle/waiting/exited/merged)·마지막 결과. `scripts/registry.py`만 읽고 쓴다(flock + 원자적 교체). 빈 id는 기록하지 않는다. 전달할 때 `active`, 작업 세션의 턴이 끝나면(Stop 훅) `idle`. 목록을 갱신할 때 살아 있는 세션의 턴을 확인 프롬프트가 붙잡고 있으면(`claude agents`의 `status: waiting`·`waitingFor`) `waiting`과 그 이유를 기록한다. 프롬프트 없이 `state: blocked`인 세션(질문하고 턴을 끝냄)은 `idle/blocked`로 두고, 답은 평소처럼 전달한다.
- **front 식별**: `front` 스킬이 Bash의 `CLAUDE_CODE_SESSION_ID`(훅의 `session_id`와 같은 값)와 `ListAgents` 첫 줄의 자기 이름을 대장에 기록한다.
- **UserPromptSubmit 훅**: `session_id`가 front일 때만 대장 요약과 front의 권한 모드를 `additionalContext`로 주입한다. 다른 세션에서는 아무것도 하지 않는다.
- **작업 세션**: `agents/topic-worker.md`. 한 주제만 맡고, 완료·막힘 시 front에 `SendMessage`로 짧게 보고하고, 라우팅하지 않는다. front와 같은 권한 모드로 뜬다.
- **Stop 훅**: 작업 세션(`session_id`, 아직 모르면 `$CLAUDE_JOB_DIR`의 job id가 대장에 있음)에서만 `last_assistant_message`를 `last_result`로 기록한다. 보고가 빠져도 front가 결과를 읽을 수 있다.
- **백엔드**: 세션 생성·재개·목록·정지·요약은 `scripts/backend.sh` 한 파일만 Claude Code CLI를 부른다. 다른 백엔드(Orca 등)로 바꿀 때 이 파일만 교체한다. `spawn`/`resume`은 프롬프트를 표준 입력으로 받고, stdout은 job id 한 줄뿐이다(안내 문구는 stderr).
- **프롬프트 조립**: `registry.py spawn`/`resume`이 front의 요청 본문(`--request TEXT`, 또는 `--request -`와 heredoc 표준 입력)에 대장의 현재 front 이름·주제·형제 목록을 붙여 작업 세션 프롬프트를 만들고, 이름 예약·실행·job id 기록까지 한 명령으로 묶는다. 프롬프트 파일을 쓰지 않고, id를 모델이 옮겨 적지 않는다. `spawn`은 디렉터리(기본: front의 cwd)와 요청을 이름 예약 전에 확인한다.
- **재개**: 프로세스가 없는(`pid` 없음) 세션만 `claude --resume <session_id> --bg`로 깨운다. `registry.py resume`은 먼저 목록을 갱신하고, 살아 있는 세션이면 재개하지 않는다(오래된 문맥에서 사본을 띄우지 않게). 훅이 주입하는 목록은 `pid`를 그 프로세스가 있을 때만 보여 준다. 목록에 남은 세션은 플래그 없이 깨워야 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 이어진다. 플래그를 주면 사본이 생긴다.

## 권한 프롬프트 줄이기

front는 `registry.py`와 `backend.sh`를 플러그인 경로째 부르는 단일 명령만 쓴다. `front`/`route`/`merge` 스킬의 `allowed-tools`는 스킬을 불러온 그 턴에만 두 스크립트를 사전 승인한다. front는 `route`를 세션에 한 번만 불러오고, 작업 세션 보고처럼 메시지로 시작된 턴에는 스킬이 없다. 그래서 **사람이 지켜보지 않는 라우팅에는 아래 allow 규칙이 필수다.** 사용자 설정(`~/.claude/settings.json`)에 넣고, `<HOME>`은 홈 디렉터리의 절대 경로(`echo $HOME`)로 바꾼다. 마켓플레이스 설치본의 `${CLAUDE_PLUGIN_ROOT}`는 `~/.claude/plugins/cache/hexoskeleton/router/<version>/`이고, 버전 자리의 `*`가 업데이트 뒤에도 규칙을 유지한다. `Skill(...)` 규칙은 front가 스킬을 불러올 때의 `Use skill "router:route"?` 확인을 없앤다(`Skill(name)`은 정확히 그 이름, `Skill(name *)`은 인자가 붙은 호출까지). 사용자가 직접 입력한 `/router:front`는 Skill 도구 호출이 아니라서 확인이 없으므로 `front` 규칙은 두지 않는다.

```json
{
  "permissions": {
    "allow": [
      "Bash(python3 \"<HOME>/.claude/plugins/cache/hexoskeleton/router/*/scripts/registry.py\" *)",
      "Bash(bash \"<HOME>/.claude/plugins/cache/hexoskeleton/router/*/scripts/backend.sh\" *)",
      "Skill(router:route)",
      "Skill(router:merge *)"
    ]
  }
}
```

`*`는 공백을 포함한 어떤 글자와도 맞으므로 이 규칙은 편의 장치이지 보안 경계가 아니다. 앞부분을 홈 경로로 고정해 다른 `python3`/`bash` 명령은 승인하지 않게 했다.

규칙을 두어도 남는 확인:
- 스크립트 밖의 즉흥 명령(예: `cd … &&`가 붙은 복합 명령, `cp`). 스킬은 이런 명령을 쓰지 않으며, 거절해도 흐름이 이어진다.
- 작업 세션 쪽에서 그 세션의 권한 모드가 허용하지 않는 도구 사용. 그 확인 프롬프트가 작업 세션의 턴을 붙잡아, 작업 세션은 보고할 수 없고 Stop 훅도 오지 않는다. front의 다음 refresh가 그 세션을 `[WAITING: permission prompt — user must run: claude attach <job_id>; …]`로 표시하고, front는 사용자에게 그 명령을 안내한다. 사용자가 터미널에서 `claude attach <job_id>`로 열어 응답해야 이어진다(다른 세션의 메시지는 승인이 되지 못한다).
- `bypassPermissions`의 일회 동의(그래서 `route`가 쓰지 않는다).

작업 세션은 front의 권한 모드로 뜬다. 지켜보지 않고 맡기려면 front를 `auto`(쓸 수 있는 계정에서)나 `acceptEdits`로 띄우고, 작업에 필요한 명령은 allow 규칙에 더한다.
- `default`(Manual): 작업 세션은 승인이 필요한 첫 도구에서 멈춘다.
- `acceptEdits`: 파일 편집과 흔한 파일 시스템 명령은 묻지 않지만, 그 밖의 셸 명령(예: `python3 -c …`)은 allow 규칙이 없으면 여전히 묻는다.
- `auto`: 분류기가 대부분의 동작을 사람 대신 검토한다.
- `dontAsk`: 물을 동작을 묻지 않고 거부한다(문서 기준). 작업 세션은 멈추지 않고 거부된 일을 `blocked`로 보고한다.

## 한계

- **Claude Code 전용**: cross-session `SendMessage`/`ListAgents`와 `claude --bg`가 필요하다. 최소 버전은 각 `SKILL.md`의 `compatibility`를 본다.
- 신뢰하지 않은 디렉터리에서는 작업 세션을 띄울 수 없다(`Workspace not trusted`).
- 유휴·미연결 작업 세션은 약 1시간 뒤 프로세스가 멈춘다. 멈춘 세션은 `SendMessage`로 깨어나지 않으므로 다음 전달 때 `route`가 `resume`으로 다시 깨운다.
- 작업 세션마다 독립 세션이라 비용이 세션 수에 비례한다. 전달된 메시지도 프롬프트처럼 사용량에 잡힌다.
- 결과 보고는 작업 세션이 지시를 따르는 데 달려 있다. 백업은 Stop 훅의 `last_result`다. `notify_when_idle`은 선택 사항으로, 오래 걸리는 작업에만 건다(평소에는 보고와 겹쳐 같은 결과가 한 턴 더 온다).
- 플러그인을 제거하거나(`/plugin`, `claude plugin uninstall`) 마켓플레이스를 제거하면 플러그인 데이터 디렉터리(`~/.claude/plugins/data/router-hexoskeleton/`)가 대장 `registry.json`째 지워진다. 남기려면 `claude plugin uninstall --keep-data`(문서 기준).
- `claude --bg --name`은 이름 중복을 막지 않는다. 유일성은 대장이 보장한다.
- `bypassPermissions` 세션은 다른 권한 class의 메시지를 보류하므로 front와 작업 세션은 같은 모드로 둔다.
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

### 미검증 (unverified)

- 3차 시험 이후 바뀐 부분은 stub `claude`를 쓴 단위 테스트로만 확인했다: 승인 대기 세션의 `WAITING` 표시와 `claude attach` 안내, 작업 세션 프롬프트의 라우팅 지시 안내 줄, `refresh --json`. 라우팅 지시를 뺀 요청 본문과 `merge`의 요약 요청 → 답장 대기 순서는 스킬 지시일 뿐 실측하지 않았다.
- `claude attach <job_id>`로 연 작업 세션에서 승인하면 턴이 이어져 보고가 오는지(문서 기준).
- `dontAsk` 작업 세션이 거부된 일을 `blocked`로 보고하는지(문서 기준).
- 실패한 이름 재사용과 `resume`의 살아 있는 세션 거절(단위 테스트만).

## 개발

```bash
python3 plugins/router/tests/test_registry.py   # 대장: 유일 이름·실패 이름 재사용, 빈 id, 갱신·이름 폴백, merged, 원자적 쓰기, stub claude로 spawn/resume·프롬프트 조립, 승인 대기(WAITING) 표시
python3 plugins/router/tests/test_hooks.py      # 훅: front만 주입(살아 있는 pid만 표시), 작업 세션만 기록
claude --plugin-dir plugins/router              # 작업 트리를 플러그인으로 로드
```

셸 환경 변수는 백그라운드 세션에 전달되지 않는다. 대장 경로를 바꿔 시험하려면 `ROUTER_REGISTRY`를 `--settings '{"env":{"ROUTER_REGISTRY":"…"}}'`로 넘긴다(`backend.sh spawn`의 추가 인자).
