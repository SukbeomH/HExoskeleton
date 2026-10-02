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
   - **status**: 진행 상황을 물으면 대장을 갱신해 보여 준다.
3. 수렴한 세션 병합: `/router:merge <세션...> into <새 이름>` — 요약을 모아 병합 brief를 만들고, 그것으로 새 작업 세션을 띄우고, 원본은 `merged`로 표시한다.

`/clear` 후에는 세션 id가 바뀌므로 `/router:front`를 다시 실행한다.

## 동작 방식

- **대장**: `${CLAUDE_PLUGIN_DATA}/registry.json` (사용자 단위). 이름(유일)·session_id·job id·cwd·주제·모델(지정한 경우)·상태(active/idle/exited/merged)·마지막 결과. `scripts/registry.py`만 읽고 쓴다(flock + 원자적 교체). 빈 id는 기록하지 않는다. 전달할 때 `active`, 작업 세션의 턴이 끝나면(Stop 훅) `idle`.
- **front 식별**: `front` 스킬이 Bash의 `CLAUDE_CODE_SESSION_ID`(훅의 `session_id`와 같은 값)와 `ListAgents` 첫 줄의 자기 이름을 대장에 기록한다.
- **UserPromptSubmit 훅**: `session_id`가 front일 때만 대장 요약과 front의 권한 모드를 `additionalContext`로 주입한다. 다른 세션에서는 아무것도 하지 않는다.
- **작업 세션**: `agents/topic-worker.md`. 한 주제만 맡고, 완료·막힘 시 front에 `SendMessage`로 짧게 보고하고, 라우팅하지 않는다. front와 같은 권한 모드로 뜬다.
- **Stop 훅**: 작업 세션(`session_id`, 아직 모르면 `$CLAUDE_JOB_DIR`의 job id가 대장에 있음)에서만 `last_assistant_message`를 `last_result`로 기록한다. 보고가 빠져도 front가 결과를 읽을 수 있다.
- **백엔드**: 세션 생성·재개·목록·정지·요약은 `scripts/backend.sh` 한 파일만 Claude Code CLI를 부른다. 다른 백엔드(Orca 등)로 바꿀 때 이 파일만 교체한다. `spawn`/`resume`의 stdout은 job id 한 줄뿐이고(안내 문구는 stderr), `registry.py spawn`/`resume`이 이름 예약·실행·job id 기록을 한 명령으로 묶는다. id를 모델이 옮겨 적지 않는다.
- **재개**: 프로세스가 없는(`pid` 없음) 세션만 `claude --resume <session_id> --bg`로 깨운다. 목록에 남은 세션은 플래그 없이 깨워야 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 이어진다. 플래그를 주면 사본이 생긴다.

## 권한 프롬프트 줄이기

front는 `registry.py`와 `backend.sh`를 플러그인 경로째 부르는 단일 명령만 쓴다. `front`/`route`/`merge` 스킬의 `allowed-tools`가 스킬을 호출한 턴에는 두 스크립트를 사전 승인한다. 그 밖의 턴에서도 묻지 않게 하려면 사용자 설정(`~/.claude/settings.json`)에 allow 규칙을 둔다. `<HOME>`은 홈 디렉터리의 절대 경로(`echo $HOME`)로 바꾼다. 마켓플레이스 설치본의 `${CLAUDE_PLUGIN_ROOT}`는 `~/.claude/plugins/cache/hexoskeleton/router/<version>/`이고, 버전 자리의 `*`가 업데이트 뒤에도 규칙을 유지한다.

```json
{
  "permissions": {
    "allow": [
      "Bash(python3 \"<HOME>/.claude/plugins/cache/hexoskeleton/router/*/scripts/registry.py\" *)",
      "Bash(bash \"<HOME>/.claude/plugins/cache/hexoskeleton/router/*/scripts/backend.sh\" *)"
    ]
  }
}
```

`*`는 공백을 포함한 어떤 글자와도 맞으므로 이 규칙은 편의 장치이지 보안 경계가 아니다. 앞부분을 홈 경로로 고정해 다른 `python3`/`bash` 명령은 승인하지 않게 했다. 규칙 문법(경로 중간의 `*`)은 문서 기준이고, 따옴표가 든 명령과의 실제 매칭은 확인하지 않았다(unverified).

## 한계

- **Claude Code 전용**: cross-session `SendMessage`/`ListAgents`와 `claude --bg`가 필요하다. 최소 버전은 각 `SKILL.md`의 `compatibility`를 본다.
- 신뢰하지 않은 디렉터리에서는 작업 세션을 띄울 수 없다(`Workspace not trusted`).
- 유휴·미연결 작업 세션은 약 1시간 뒤 프로세스가 멈춘다. 다음 전달 때 `route`가 다시 깨운다.
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

### 미검증 (unverified)

- 약 1시간 유휴로 멈춘 작업 세션을 대화형 흐름에서 `resume`으로 다시 깨우는 경로(재개 자체는 `-p` 스모크에서만 확인).
- 대화형 실측 이후 바뀐 부분: `registry.py spawn`/`resume` 경유 생성·재개, 단일 명령 템플릿, 스킬 `allowed-tools`, 대장 상태 갱신(active/idle)은 stub `claude`를 쓴 단위 테스트로만 확인했다.
- 위 allow 규칙과 `allowed-tools` 규칙이 실제로 프롬프트를 없애는지.

## 개발

```bash
python3 plugins/router/tests/test_registry.py   # 대장: 유일 이름, 빈 id, 갱신·이름 폴백, merged, 원자적 쓰기, stub claude로 spawn/resume
python3 plugins/router/tests/test_hooks.py      # 훅: front만 주입, 작업 세션만 기록
claude --plugin-dir plugins/router              # 작업 트리를 플러그인으로 로드
```

셸 환경 변수는 백그라운드 세션에 전달되지 않는다. 대장 경로를 바꿔 시험하려면 `ROUTER_REGISTRY`를 `--settings '{"env":{"ROUTER_REGISTRY":"…"}}'`로 넘긴다(`backend.sh spawn`의 추가 인자).
