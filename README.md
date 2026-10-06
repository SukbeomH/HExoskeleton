<p align="center">
  <img src="logo.png" alt="HExoskeleton" width="200" />
</p>

<h1 align="center">HExoskeleton</h1>

<p align="center"><b>One session to rule them all.</b></p>

Claude Code 세션 하나(front)에만 말하면, 메시지는 주제를 맡은 작업 세션으로 흘러가고 결과는 다시 front로 모인다. 이 저장소는 그 일을 하는 **router** 플러그인과, 각 작업을 SPEC → PLAN → EXECUTE → VERIFY로 검증하며 끝내는 방법론 플러그인 **hxsk**를 함께 싣는 마켓플레이스 `hexoskeleton`이다. 구성 요소는 bash, python3 표준 라이브러리, 마크다운뿐이다.

## router — 세션 하나로 모든 주제를

여러 주제를 동시에 굴리면 터미널과 세션이 늘어난다. router는 사용자가 front 세션 하나에서만 대화하게 한다.

- **전달**: 기존 주제의 메시지는 그 주제를 맡은 세션으로 보낸다. 세션이 멈춰 있으면 다시 깨운다.
- **생성**: 새 주제면 새 백그라운드 작업 세션을 띄운다.
- **전파**: 여러 주제에 걸치는 메시지는 대상마다 보내고, 참여 세션 목록을 함께 넣어 서로를 소개한다.
- **결과 회수**: 작업 세션은 끝나거나 막히면 front에 보고하고, front가 사용자에게 전한다.
- **병합**: 수렴한 세션들은 명시적인 명령으로 요약을 모아 새 세션 하나로 합친다.

### 설치와 첫 사용

```text
/plugin marketplace add SukbeomH/HExoskeleton
/plugin install router@hexoskeleton
```

대화할 세션에서 `/router:front`를 실행하고, 그다음은 평소처럼 말한다. 병합은 `/router:merge <세션...> into <새 이름>`.

### 동작 방식

- 대장(`registry.json`, 플러그인 데이터 디렉터리)이 주제 → 작업 세션(이름·session id·상태·마지막 결과)을 기록한다.
- UserPromptSubmit 훅은 front 세션에서만 대장 요약을 주입한다. 다른 세션에는 영향이 없다.
- front 모델이 `route` 스킬 절차로 전달·생성·전파·상태 조회를 고른다. 별도 라우터 모델은 없다.
- 작업 세션은 `topic-worker` 에이전트로 `claude --bg`에서 front와 같은 권한 모드로 뜨고, `SendMessage`로 보고한다.
- 작업 세션의 Stop 훅이 마지막 응답을 대장에 기록해, 보고가 빠져도 front가 결과를 읽을 수 있다.
- 세션 생성·재개·목록은 `backend.sh` 한 파일만 Claude Code CLI를 부른다. 다른 백엔드로 바꿀 때 이 파일만 교체한다.

### 한계

- Claude Code 전용이다 (cross-session `SendMessage`, `claude --bg`).
- 신뢰하지 않은 디렉터리에서는 작업 세션을 띄울 수 없다.
- 유휴·미연결 작업 세션은 약 1시간 뒤 프로세스가 멈춘다. 다음 전달 때 다시 깨운다.
- 작업 세션마다 독립 세션이라 비용이 세션 수에 비례한다.
- 결과 보고는 작업 세션이 지시를 따르는 데 달려 있고, Stop 훅 기록이 백업이다.
- 플러그인이나 마켓플레이스를 제거하면 대장(`registry.json`)이 든 플러그인 데이터 디렉터리도 지워진다.
- front가 플러그인 스크립트를 부를 때마다 권한을 묻지 않게 하는 allow 규칙은 [router README](plugins/router/README.md#권한-프롬프트-줄이기)에 있다.
- 실측(interactive test 2026-10-02, Orca terminal, marketplace install): 대화형 front의 전체 라우팅 흐름과 병합, 작업 세션의 자발적 보고, 메시지로 시작된 턴의 훅 주입을 확인했다. 미검증(unverified): 약 1시간 뒤 멈춘 작업 세션을 대화형 흐름에서 다시 깨우는 경로 등. 실측한 것과 미검증 항목은 [router README](plugins/router/README.md)에 구분해 적었다.

## hxsk — 함께 쓰는 개발 방법론

HXSK는 SPEC → PLAN → EXECUTE → VERIFY 워크플로우를 [Agent Skills](https://agentskills.io)로 제공하고, 검증 전용 서브에이전트, 위험한 동작을 막는 가드 훅, 프로젝트의 `.hxsk/`에 저장되는 파일 기반 작업 상태·메모리를 더한다. router 작업 세션 안에서도, 단독으로도 쓴다.

### 설치

Claude Code — 플러그인 (스킬 + 에이전트 + 훅):

```text
/plugin marketplace add SukbeomH/HExoskeleton
/plugin install hxsk@hexoskeleton
```

Codex CLI — 플러그인. Codex는 `.claude-plugin/` 마켓플레이스를 그대로 읽는다(이 저장소에서 시험함). 스킬은 `hxsk:<name>`으로 노출된다.

```bash
codex plugin marketplace add SukbeomH/HExoskeleton
codex plugin add hxsk@hexoskeleton
```

플러그인 훅은 사용자가 Codex의 훅 검토에서 신뢰(trust)하기 전까지 실행되지 않는다. 신뢰 후 가드는 Bash 명령(`bash-guard`)과 `apply_patch`의 민감 파일 보호(`file-protect`)를 맡는다. Codex에는 Read 도구가 없어 read-before-edit 추적은 적용되지 않는다.

그 밖의 Agent Skills 호환 하네스 (Cursor, Antigravity, Devin, OpenCode 등):

```bash
git clone https://github.com/SukbeomH/HExoskeleton
HExoskeleton/scripts/init-project.sh --skills /path/to/your-project
```

스킬을 `<project>/.agents/skills/`로 복사하고, `.hxsk/`를 만들고, `AGENTS.md`에 HXSK 블록을 추가한다. `.hxsk/`의 기존 파일과 `AGENTS.md`는 덮어쓰지 않지만, `--skills`는 실행할 때마다 `.agents/skills/`의 복사본을 덮어써 갱신한다(그 안에서 직접 고친 내용은 사라진다).

> **훅은 Claude Code·Codex 플러그인과 Hermes 플러그인(아래) 설치에서만 지원한다.** Claude Code는 실제 세션으로, Codex는 공식 훅 문서와 Codex 입력 형식 테스트(`tests/hooks-smoke.sh`)로, Hermes는 소스와 가짜 플러그인 컨텍스트 시험(`tests/hermes-plugin.py`)으로 확인했다. 이 경로로 설치한 하네스에서는 스킬과 `AGENTS.md` 지침만 동작한다고 가정한다.

#### Hermes Agent

[Nous Research hermes-agent](https://github.com/NousResearch/hermes-agent)(v0.21.5 소스 기준)용 네이티브 플러그인 `hermes/`가 가드·상태 훅과 `/hxsk-init` 명령을 더한다. 스킬은 `.agents/skills` 복사본으로 쓴다.

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash   # 그다음 모델 제공자에 로그인
git clone https://github.com/SukbeomH/HExoskeleton ~/HExoskeleton
hermes plugins install SukbeomH/HExoskeleton/hermes                  # HXSK_ROOT 를 물으면 ~/HExoskeleton
hermes plugins enable hxsk
```

- 서브디렉터리 설치는 `hermes/`만 받는다(sparse checkout). 훅 스크립트·템플릿·스킬은 체크아웃에 있으므로 플러그인은 `HXSK_ROOT`(설치 때 물어 `~/.hermes/.env`에 저장)로 찾고, 못 찾으면 로드에 실패한다(시작 경고와 `/plugins`). 체크아웃을 링크해도 된다: `ln -s ~/HExoskeleton/hermes ~/.hermes/plugins/hxsk`. 커밋 고정은 `--ref <40자 SHA>`.
- 플러그인은 `hermes plugins enable hxsk` 전까지 로드되지 않는다. 설치 때 Hermes의 플러그인 스캔을 거친다.
- 프로젝트에서 `/hxsk-init [디렉터리]`를 입력하면 `init-project.sh --skills`가 `.hxsk/`와 `.agents/skills/`를 만든다. 셸에서 `hermes skills trust <프로젝트>`를 실행해야 Hermes가 `.agents/skills`를 읽는다. 프로젝트 스킬은 신뢰 전에는 로드되지 않는다.

Claude Code와 다른 점:

- **도구 대응**: `terminal`=Bash, `write_file`=Write, `patch`=Edit, `read_file`=Read(`path`→`file_path`). `file-protect`(read_file·write_file·patch, V4A 패치 헤더 포함), `write-guard`(write_file), `bash-guard`(terminal)를 그대로 돌린다. exit 2는 차단이고, 가드를 실행하지 못하면(시간 초과·스크립트 없음) Hermes가 차단한다. `execute_code`·`search_files`·MCP 등 다른 도구는 가드하지 않는다.
- **read-before-edit 없음**: Hermes `write_file`은 읽지 않은 기존 파일을 스스로 거부하지만 `patch`는 경고만 한다. Hermes에서 NO EDIT WITHOUT READ는 Claude Code보다 약하다.
- **상태 훅**(`.hxsk/`가 있을 때만): 새 세션의 첫 턴(`pre_llm_call`)에 session-start 문맥을 사용자 메시지에 붙인다. `--resume`한 세션에는 붙이지 않는다. 변경 기록은 `post_tool_call`, 매 턴 끝의 컨텍스트 저장은 `on_session_end`가 맡는다.
- **없는 것**: PreCompact(Hermes에 대응 이벤트가 없다). Stop의 post-turn-verify 대신 Hermes 내장 verify-on-stop이 코드를 고치고 검증 증거가 없는 턴을 이어 가게 한다. auto-format과 검증 서브에이전트(`agents/`)는 쓰지 않는다.
- **상대 경로**는 Hermes를 띄운 디렉터리(`TERMINAL_CWD`) 기준으로 검사한다. 세션 중 `cd`한 뒤의 상대 경로에서는 write-guard가 다른 파일을 볼 수 있다.
- CLI에서는 플러그인 명령이 같은 이름의 스킬보다 우선한다. 복사된 `hxsk-init` 스킬은 모델이 불러 쓴다.
- **미검증**(Hermes를 설치해 확인할 것): 실제 세션의 훅 페이로드와 차단 표시, 프로젝트 스킬의 색인·실행, 모델이 `/hxsk-init`을 부를 수 없는지. 소스상 플러그인 명령은 사용자 입력 경로에서만 실행된다.

### 첫 실행

Claude Code에서 `/hxsk:hxsk-init`을 실행한다(또는 "HXSK 초기화해줘"). 프로젝트에 `.hxsk/`(SPEC, STATE, VERIFICATION, 메모리 등)를 만들고 `SPEC.md` 작성을 안내한다. 상태를 기록하는 훅은 `.hxsk/`가 있는 프로젝트에서만 동작하므로, 초기화하지 않은 프로젝트에는 가드 훅만 적용된다.

`.hxsk/`에서 `SPEC.md`·`STATE.md`·`VERIFICATION.md`·`memories/`는 직접 관리하며 커밋한다. Stop 훅이 매 턴 다시 쓰는 `CURRENT.md`, 이 클론 전용 재진입 메모인 `SESSION_HANDOFF.md`(직접 또는 `handoff` 스킬로 작성), 런타임 로그는 `.hxsk/.gitignore`로 제외된다. 훅은 `STATE.md`와 `SESSION_HANDOFF.md`를 없을 때 만들기만 하고 다시 쓰지 않는다.

### 워크플로우

```text
SPEC.md (무엇을) → PLAN (어떻게) → EXECUTE (atomic commit) → VERIFY (실행 증거)
```

- `planner` → `plan-checker` → `executor` → `verifier` 스킬이 각 단계를 맡는다. 큰 작업은 `dispatcher`가 워크트리 단위로 병렬 실행한다.
- 완료 선언에는 실제로 실행한 검증 명령의 결과가 있어야 한다 (`empirical-validation`).
- 결정·근본 원인·교훈은 `memory-protocol`로 `.hxsk/memories/`에 남기고 다음 세션에서 검색한다.

### 업그레이드

- Claude Code: `claude plugin update hxsk@hexoskeleton`(router는 `router@hexoskeleton`) 후 새 세션 시작(또는 `/reload-plugins`)
- Codex CLI: `codex plugin marketplace upgrade hexoskeleton`(마켓플레이스 스냅샷 갱신) 후 `codex plugin add hxsk@hexoskeleton`으로 다시 설치. 설치된 플러그인은 스냅샷 갱신만으로 바뀌지 않는다.
- Hermes Agent: 체크아웃에서 `git pull`(서브디렉터리 설치는 `hermes plugins update hxsk`도) 후 프로젝트에서 `/hxsk-init` 재실행 (`.agents/skills` 복사본 갱신)
- 그 밖의 하네스: `git pull` 후 `scripts/init-project.sh --skills <project>` 재실행 (`.agents/skills` 복사본 갱신)

#### v5.x(복사 설치)에서 옮겨오기

1. 프로젝트에서 복사본을 지운다: `.hxsk/{skills,agents,hooks,scripts,templates,adapters,githooks,prompts,docs,workflow}`, `.hxsk/memories/_schema`, `.hxsk/.bootstrap-version`, `.claude/skills`·`.claude/agents` 심볼릭 링크.
2. `.claude/settings.json`에서 `.hxsk/hooks/…`를 가리키는 `hooks` 항목을 지운다(플러그인이 대신 등록한다). Codex/Copilot 훅 파일과 `.cursorrules`·`.windsurfrules` 링크도 지운다.
3. `SPEC.md`, `STATE.md`, `VERIFICATION.md`, `memories/` 등 작업 상태는 그대로 둔다.
4. 위 설치 절차로 플러그인을 설치하고 `/hxsk:hxsk-init`을 실행한다. 기존 파일은 덮어쓰지 않는다.

## 저장소 구조

`.claude-plugin/marketplace.json`이 두 플러그인을 싣는다. `plugins/router/`가 router 플러그인이고, 저장소 루트가 hxsk 플러그인이다: `.claude-plugin/plugin.json`, `skills/`, `agents/`, `hooks/`, `scripts/`, `templates/`(`.hxsk/` 스캐폴드), `docs/`, `tests/`. `.agents/skills`는 `skills/`를 가리키는 심볼릭 링크다. `hermes/`는 같은 훅을 Hermes Agent에서 돌리는 플러그인이다.

문서: [router](plugins/router/README.md) · [설계 철학](docs/DESIGN-PHILOSOPHY.md) · [훅](docs/HOOKS.md) · [게이트 관례](docs/GATES.md) · [변경 이력](CHANGELOG.md)

## 개발

```bash
scripts/init-project.sh .      # 로컬 dogfood 상태 .hxsk/ (gitignore)
claude --plugin-dir .          # 작업 트리를 hxsk 플러그인으로 로드 (router: --plugin-dir plugins/router)
bash scripts/verify.sh         # 검증 단일 진입점 (CI와 동일)
```

기여 규칙은 [AGENTS.md](AGENTS.md)를 본다.

## 라이선스

[MIT](LICENSE)
