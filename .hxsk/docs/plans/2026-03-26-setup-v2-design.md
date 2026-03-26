# Setup v2: 멱등 수렴 패턴 + 2-hop 컨텍스트 구성 + 범용 에이전트 지원

> Date: 2026-03-26
> Status: DRAFT
> Scope: `scripts/bootstrap.sh`, `prompts/setup*.md`, `.hxsk/hooks/session-start.sh`, `.hxsk/skills/bootstrap/`

## Background

현재 setup은 단방향 초기 설치만 지원. "이미 설치됨 → 업데이트 필요" 상황 처리 없음. 또한 Claude Code 전용 기능(hooks)에 의존하면 범용성이 깨짐. 모든 에이전트가 공통으로 사용할 수 있는 멱등 setup 시스템이 필요.

## Core Concept: 멱등 수렴 엔진

`bootstrap.sh`를 "설치 스크립트"에서 **"상태 수렴 엔진"**으로 전환.

```
실행할 때마다:
1. 현재 상태 스캔 (뭐가 있고 뭐가 없는지)
2. 목표 상태와 비교 (버전 + 컴포넌트 목록)
3. 차이만 적용
4. 결과 보고: [NEW] / [UPDATED] / [OK]
```

### 버전 마커: `.hxsk/.bootstrap-version`

```yaml
version: 4.1.0
last_run: 2026-03-26
components:
  - skills/19
  - agents/17
  - hooks/17
  - memories/14
```

### 판별 로직

| `.bootstrap-version` | 동작 | 보고 |
|----------------------|------|------|
| 파일 없음 | 전체 설치 | 모두 `[NEW]` |
| 동일 버전 | 구조 검증만 | 모두 `[OK]` |
| 구버전 | 변경분 적용 | 변경된 것만 `[UPDATED]`, 나머지 `[OK]` |

**범용성**: 순수 bash + YAML frontmatter. 에이전트 무관. 어떤 에이전트든 `bash scripts/bootstrap.sh`를 실행하면 동작.

## 2-hop 컨텍스트 구성

새 컴포넌트 설치/업데이트 시 기존 설정과의 관계를 자동으로 설명.

### 동작 흐름

```
[UPDATED] dispatcher v1.0.0 → v2.0.0
  ↓ md-recall-memory.sh "dispatcher" 2-hop 검색
  ↓ 관련 발견: planner, executor, merge-worktrees.sh
  ↓
  "dispatcher v2는 MASTER/WORK 이슈 문서를 사용합니다.
   기존 planner(PLAN.md 생성)와 executor(PLAN 실행)의
   출력을 입력으로 받아 병렬 분할합니다."
```

### 구현

bootstrap.sh의 각 컴포넌트 체크 후 `[NEW]` 또는 `[UPDATED]`일 때만 2-hop 호출:

```bash
report_context() {
    local component="$1" status="$2"
    if [ "$status" = "NEW" ] || [ "$status" = "UPDATED" ]; then
        local related
        related=$(bash .hxsk/hooks/md-recall-memory.sh "$component" "." 3 compact 2 2>/dev/null)
        [ -n "$related" ] && echo "  관련: $related"
    fi
}
```

**범용성**: `md-recall-memory.sh`는 순수 bash. 에이전트가 bootstrap.sh를 실행하면 자동으로 2-hop 컨텍스트가 출력에 포함.

**제약**: 메모리가 비어있는 최초 설치 시에는 2-hop 결과 없음 → `[NEW]`만 표시. 이후 업데이트부터 관계 설명 제공.

## setup.md 상태 인식형 가이드

현재 7단계 선형 체크리스트를 **분기형 가이드**로 전환. 에이전트가 상태를 감지하고 스스로 초기/업데이트 경로를 선택.

### 프롬프트 구조

```markdown
## Step 0: 상태 감지 (신규)
1. `.hxsk/.bootstrap-version` 파일 확인
2. 없으면 → "초기 설치" 경로 (Step 1부터 전체 실행)
3. 있으면 → 버전 읽기 → "업데이트" 경로 (bootstrap.sh만 재실행)

## 초기 설치 경로
Step 1~7: 기존과 동일 (llms.txt 읽기 → 에이전트 지침 설치 → ... → 뱃지)
마지막에 bootstrap.sh가 .bootstrap-version 생성

## 업데이트 경로
1. `bash scripts/bootstrap.sh` 실행
2. [NEW/UPDATED/OK] 보고서 확인
3. [UPDATED] 항목의 2-hop 관계 설명 읽기
4. 필요 시 에이전트별 설정 갱신 (hook 등록 등)
```

**setup-claude.md도 동일 패턴** 적용. Claude Code 전용 부분(hook 등록, skills 경로)은 업데이트 경로에서 "설정 변경 있으면 갱신" 분기 추가.

**범용성**: Step 0의 상태 감지는 파일 존재 확인(`[ -f ]`)이므로 어떤 에이전트든 수행 가능.

## session-start.sh source 분기 (에이전트별 레이어)

hook을 지원하는 에이전트에서 세션 시작 시 로드 범위를 자동 조절.

### 분기 로직

```bash
# Claude Code / Gemini CLI: stdin JSON에서 source 파싱
SOURCE=$(echo "$INPUT" | json_get "source" 2>/dev/null)

# 타 에이전트 또는 source 미제공 시: 구조적 감지
if [ -z "$SOURCE" ]; then
    if [ -f ".hxsk/.session-active" ]; then
        SOURCE="resume"
    else
        SOURCE="startup"
    fi
fi

case "$SOURCE" in
    startup)
        # 풀 로드: STATE + memory 2-hop + git status + recent commits
        touch .hxsk/.session-active
        ;;
    resume)
        # 최소: uncommitted changes + CURRENT.md만
        ;;
    compact)
        # 핵심만: STATE.md 첫 15줄 + 활성 PLAN 태스크
        ;;
esac
```

### 에이전트별 호환성

| 에이전트 | source 감지 | fallback |
|----------|------------|----------|
| Claude Code | stdin JSON `source` 필드 | - |
| Gemini CLI | stdin JSON `source` 필드 | - |
| Cursor/Windsurf/Copilot | hook에서 셸 실행 가능 | `.session-active` 마커 |
| Aider/기타 | hook 미지원 | setup.md에서 수동 실행 안내 |

**SessionEnd**: `.session-active` 마커 삭제. hook 지원 에이전트는 SessionEnd hook에서 자동, 미지원은 수동.

## 범용 에이전트 호환성 매트릭스

| 기능 | 구현 위치 | 범용 (bash) | Claude Code | Gemini CLI | Cursor/WS/Copilot | Aider |
|------|-----------|:-:|:-:|:-:|:-:|:-:|
| 버전 마커 감지 | bootstrap.sh | O | O | O | O | O |
| 멱등 수렴 | bootstrap.sh | O | O | O | O | O |
| 2-hop 컨텍스트 | md-recall-memory.sh | O | O | O | O | O |
| setup.md 분기 | 프롬프트 | O | O | O | O | O |
| source 기반 세션 분기 | session-start.sh | - | O | O | fallback | - |
| hook 자동 실행 | 에이전트별 설정 | - | O | O | O | - |

## 변경 파일

| 파일 | 유형 | 변경 내용 |
|------|------|-----------|
| `scripts/bootstrap.sh` | 수정 | 멱등 수렴 엔진 + 버전 마커 + `[NEW/UPDATED/OK]` + 2-hop 컨텍스트 |
| `prompts/setup.md` | 수정 | Step 0 상태 감지 추가, 초기/업데이트 분기 |
| `prompts/setup-claude.md` | 수정 | 동일 분기 + Claude 전용 hook 갱신 안내 |
| `.hxsk/hooks/session-start.sh` | 수정 | source 분기 + .session-active fallback |
| `.hxsk/skills/bootstrap/SKILL.md` | 수정 | 업데이트 시나리오 추가, 2-hop 보고 |
| `.hxsk/templates/bootstrap-version.yaml` | 신규 | .bootstrap-version 템플릿 |

### 유지

- bootstrap.sh의 기존 체크 로직 (시스템 요구사항, 메모리 디렉토리 등)
- setup.md의 7-step 구조 (초기 설치 경로에서 그대로 사용)
- session-start.sh의 기존 컨텍스트 로드 로직 (startup에서 그대로 사용)

## Design Decisions

| 결정 | 선택 | 이유 |
|------|------|------|
| 설치/업데이트 구분 | 단일 멱등 경로 | 두 코드 경로보다 유지보수 용이 |
| 2-hop 구성 | `[NEW/UPDATED]` 시에만 호출 | 매번 호출하면 느림, 필요할 때만 |
| source 감지 fallback | `.session-active` 마커 | hook source 미제공 에이전트 호환 |
| 범용/전용 분리 | bootstrap.sh(범용) + hook(전용) | AGENTS.md만 읽는 에이전트도 사용 가능 |
| setup.md 분기 | 프롬프트 내 조건 지시 | 에이전트가 자율 판단, 사람 개입 불필요 |

## Research References

| 출처 | 참고 포인트 |
|------|------------|
| [Idempotent Bash Scripts](https://arslan.io/2019/07/03/how-to-write-idempotent-bash-scripts/) | 멱등 bash 패턴 (mkdir -p, [ -f ] \|\| cp) |
| [Ansible Idempotent Playbooks](https://admantium.medium.com/ansible-idempotent-playbooks-a89bb0e012c9) | 단일 수렴 경로 > 분리된 install/update |
| [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks) | SessionStart source 필드 |
| [Gemini CLI Hooks](https://geminicli.com/docs/hooks/) | BeforeTool, SessionStart 등 10+ 이벤트 |
| [AGENTS.md Standard](https://agents.md/) | 범용 에이전트 지침 표준 (60,000+ repos) |
| [Self-Improving Bootstrap](https://gist.github.com/ChristopherA/fd2985551e765a86f4fbb24080263a2f) | 메타 규칙 기반 자기 개선 부트스트랩 |
| [mem0 Graph Memory](https://mem0.ai/blog/graph-memory-solutions-ai-agents) | 2-hop 그래프 탐색으로 관계 기반 컨텍스트 구성 |
