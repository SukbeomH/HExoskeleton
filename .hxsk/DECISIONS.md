# DECISIONS.md — Architecture Decision Records

> **Purpose**: Log significant technical decisions and their rationale.

## Template

```markdown
## [DECISION-XXX] Title

**Date**: YYYY-MM-DD
**Status**: Proposed | Accepted | Deprecated | Superseded

### Context
What is the issue we're facing?

### Decision
What have we decided to do?

### Rationale
Why did we make this decision?

### Consequences
What are the trade-offs?

### Alternatives Considered
What other options were evaluated?
```

---

## Decisions

---

## [DECISION-001] 메모리 스크립트 경로 전략 — 중립 경로(scripts/) 통일

**Date**: 2026-02-20
**Status**: Accepted

### Context
SKILL.md 파일들이 메모리 스크립트 경로를 `.claude/hooks/md-*.sh`로 하드코딩하고 있었음.
보일러플레이트에서는 동작하지만, 플러그인으로 배포 시 스크립트가 `.claude/plugins/gsd/scripts/`에 위치하여 경로 불일치 → **exit 127** 발생.

### Decision
메모리 스크립트 참조 경로를 `scripts/md-*.sh` (중립 경로)로 통일한다.

- **소스(보일러플레이트)**: `scripts/` 디렉토리에 `.claude/hooks/`를 가리키는 심볼릭 링크 생성
- **빌드(플러그인)**: `build-plugin.sh`에서 `scripts/` → `${CLAUDE_PLUGIN_ROOT}/scripts/`로 자동 치환

### Rationale
- **방안 A (환경변수 기반)**: 에이전트가 실행하는 bash 명령에서 env var 확장이 불안정
- **방안 B (스크립트 자동탐색)**: wrapper 스크립트 추가로 복잡도 증가, 단일 책임 원칙 위반
- **방안 C (중립 경로 정규화, 채택)**: 소스는 심볼릭 링크로 호환 유지, 빌드 시 sed 치환으로 해결. 외부 종속성 없음, 검증 자동화 가능

### Consequences
- `scripts/` 디렉토리에 심볼릭 링크 3개 추가 (`md-store-memory.sh`, `md-recall-memory.sh`, `_json_parse.sh`)
- 신규 SKILL.md 작성 시 `scripts/md-*.sh` 경로를 사용해야 함 (`.claude/hooks/` 직접 참조 금지)
- `build-plugin.sh` Phase 3이 SKILL.md 경로 치환을 담당

### Alternatives Considered
- **방안 A**: `${MEMORY_STORE:-bash scripts/md-store-memory.sh}` 형태 env var — 에이전트 bash 실행 환경에서 확장 불안정
- **방안 B**: `scripts/run-memory.sh` wrapper — 복잡도 증가, 디버깅 어려움

---

## [DECISION-002] .gsd/ → .hxsk/ 디렉토리 전면 rename

**Date**: 2026-02-23
**Status**: Accepted

### Context
프로젝트 리브랜딩 (GSD Boilerplate → HExoskeleton) 이후 `.gsd/` 디렉토리명이 브랜드와 불일치.
메모리, 문서, 설정이 모두 `.gsd/`를 참조하고 있어 혼란 발생.

### Decision
`.gsd/` 전체를 `.hxsk/`로 rename. 모든 스크립트, 훅, SKILL.md 참조 일괄 치환.

### Rationale
HExoskeleton(HXSK) 브랜드 통일. 일관된 디렉토리명으로 신규 기여자 온보딩 개선.

### Consequences
- 기존 `.gsd/memories/` 데이터는 `.hxsk/memories/`로 이전
- 모든 스크립트의 경로 참조 일괄 수정 필요
- PR #40으로 master 반영 완료

### Alternatives Considered
- `.agent/` — Antigravity IDE와 혼동 가능 (rejected)
- `.claude-hxsk/` — 너무 길고 Claude 종속성 암시 (rejected)

---

## [DECISION-003] handoff 에이전트 추가 — 세션 인계 표준화

**Date**: 2026-02-25
**Status**: Accepted

### Context
세션 종료 시 다음 세션에 컨텍스트를 전달하는 표준 절차가 없었음.
각 에이전트가 임의로 session-summary를 작성하거나 생략.

### Decision
`handoff` 에이전트와 대응 SKILL.md를 추가. 세션 종료 시 `/handoff` 실행으로 표준 인계 수행.

### Rationale
- 세션 간 컨텍스트 연속성 보장
- `session-handoff` 메모리 타입 활용으로 2-hop 검색 연동
- `/handoff` 하나로 상태 확인 → 커밋 → 메모리 저장 → 핸드오프 작성 자동화

### Consequences
- Agent 개수 15 → 16개
- `.hxsk/memories/session-handoff/` 타입 활성화
- CLAUDE.md Memory Storage Triggers 테이블에 session-handoff 행 추가

---

## [DECISION-004] A-Mem 확장 — contextual_description + 2-hop 검색

**Date**: 2026-03-05
**Status**: Accepted

### Context
파일 기반 메모리 시스템의 검색 정확도가 낮았음. 단순 키워드 매칭만 지원.
연관 메모리 간 링크가 없어 관련 과거 결정을 놓치는 경우 발생.

### Decision
A-Mem 논문 기반 확장 적용:
1. `contextual_description` 필드 추가 (200자 자동 생성)
2. `keywords` 필드 추가 (LLM 생성 검색 키워드)
3. `related` 필드로 2-hop 그래프 검색 구현
4. `md-store-memory.sh`에 Nemori Predict-Calibrate 적용 (유사 메모리 경고)

### Rationale
- 서사형 contextual_description으로 recall 정확도 향상
- related 링크로 연관 결정/패턴을 자동 연결
- 중복 저장 방지로 메모리 디렉토리 비대화 억제

### Consequences
- `md-store-memory.sh` 인터페이스: 7개 파라미터로 확장
- `md-recall-memory.sh`: compact fallback 스마트화, hop 파라미터 추가
- 기존 메모리 파일과 하위 호환 (선택적 필드)

---

## [DECISION-005] release-please extra-files 제거 — manifest 기반 버전 관리

**Date**: 2026-03-06
**Status**: Accepted

### Context
`release-please-config.json`의 `extra-files`가 `hxsk-plugin/.claude-plugin/plugin.json`을 참조.
이 파일은 gitignore 대상(빌드 출력물)이므로 release-please가 직접 업데이트 불가.
`build-plugin.sh`가 이미 `.release-please-manifest.json`에서 버전을 읽어 plugin.json 생성.

### Decision
`extra-files` 항목 전체 제거. 버전 소스는 `.release-please-manifest.json`으로 단일화.

### Rationale
- release-please는 manifest만 업데이트하면 충분
- build-plugin.sh가 manifest에서 버전을 읽어 plugin.json을 생성하므로 중복 없음
- extra-files 실패 시 release PR이 오류 상태로 남는 리스크 제거

### Consequences
- release-please PR은 CHANGELOG.md + .release-please-manifest.json만 수정
- plugin.json 버전은 CI `make build` 시 manifest에서 자동 주입

---

*Last updated: 2026-03-06*
