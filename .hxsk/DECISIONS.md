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

*Last updated: 2026-04-21*

---

## ADR: Autoresearch 방법론 3계층 하네스 적용 전략

**날짜**: 2026-04-21  
**상태**: accepted

### Context

autoresearch 방법론(Karpathy + Goenka) 기법 3가지(TSV 로그, 자동 revert 루프, Guard 이중 게이트)를
HXSK 10개 하네스에 범용 적용하기 위해 계층 분리 전략이 필요하다.
하네스별 hook API가 달라 단일 구현으로는 전 하네스를 커버할 수 없다.

### Decision

3계층으로 분리한다:
- **Layer 1 (AGENTS.md)**: 행동 지침 — 전 하네스 공통
- **Layer 2 (SKILL.md)**: 절차 상세 — SKILL 지원 하네스만 (Claude Code + Gemini)
- **Layer 3 (githooks/post-commit)**: 자동화 실행 — git 기반 전 하네스 공통

### Rationale

- EASYTOOL 2단계 로딩 원칙: L1=트리거/정책, L2=절차 상세
- CLI 우선 원칙: git hook은 외부 의존 없이 전 하네스 커버
- PostToolUse hook은 Claude Code 전용 → Guard 자동화에 사용하지 않음

### Consequences

- SKILL 미지원 하네스(Cursor 등)는 Layer 1 정책만 따름 — 정밀도 낮아지는 트레이드오프 감수
- Guard 자동화는 `githooks/post-commit` 확장으로 구현
- 새 하네스 추가 시 어댑터 파일만 추가하면 Layer 1-2 자동 적용

---

## [DECISION-006] 조작적 정의(Operational Definition) 시스템 — Glossary as Memory + HITL Adapter

**Date**: 2026-04-27
**Status**: Accepted

### Context
프로젝트·라이브러리·사용자 도메인 간 용어 혼선이 누적되어 작업 정확도를 저하시킴. 4가지 혼선 축이 존재한다:
1. 동의어/이형 (`Skill` ≡ `스킬` ≡ `역량`)
2. 동음이의 (`Agent` = HXSK Agent vs. Anthropic SDK Agent vs. AI agent 일반)
3. 라이브러리 ↔ 도메인 충돌 (`commit`(git) vs. `commit`(트랜잭션))
4. 사용자 어휘 ↔ 프로젝트 어휘 (사용자 "역량 정의" → 프로젝트 "Skill 작성")

현재 `.hxsk/`에 glossary 자산 부재. 사용자 쿼리를 정규 용어로 환원하고 산출물 일관성을 유지할 메커니즘이 필요하다.

### Decision
DDD Ubiquitous Language를 SSOT로 두고, A-Mem 검색 인프라로 자동 주입하는 하이브리드 방식 채택.

**구성 요소**:
1. **메모리 타입 신설**: `term-definition` (14 → 15개 타입). 한 용어 = 한 .md 파일, `canonical`/`context`/`aliases`/`disambiguates_from`/`learned` 필드
2. **인덱스 자동 생성**: `.hxsk/GLOSSARY.md` (canonical만, aliases는 lazy lookup)
3. **HITL 어댑터 패턴**: `.hxsk/adapters/hitl/{claude-code,opencode,antigravity,_detect}.sh` — 하네스별 Q&A 메커니즘 추상화
4. **자동 검출 훅**: `glossary-detect.sh` (UserPromptSubmit) — 후보 추출 + 매칭 힌트 비파괴 주입
5. **펜딩 큐**: `.hxsk/.glossary-pending.tsv` (gitignore) — 세션 중 학습 항목 누적
6. **Skill 1개**: `define-term` — register/review/merge/rebuild 4 모드 (Agent 추가 안 함)

**운영 정책**:
- 자동 정규화 강도: 비파괴 힌트만 (출력 강제 변환 없음)
- 충돌 시: HITL 게이트로 즉시 차단·해소 (등록 시점만, 일반 흐름 무차단)
- 트리거: 자동 검출 (동일 후보어 ≥3회 또는 정의 패턴 감지)
- 자동 학습: alias 추가만 허용. canonical/context는 항상 HITL
- 검토 주기: 세션 종료(handoff) 시 펜딩 일괄 처리 → 별도 commit
- Bounded context: `hxsk` / `domain` / `library` / `<custom>` 자유 문자열

### Rationale
- **방안 A (memory 타입만 추가)**: 인프라 재사용 100%, 그러나 사용자 쿼리 → 정규어 역색인 약함 (rejected as standalone)
- **방안 B (단일 GLOSSARY.md)**: SessionStart 주입 단순, 그러나 bounded context·메타데이터 빈약, 50+ 용어 시 컨텍스트 비용 폭증 (rejected as standalone)
- **방안 C (하이브리드, 채택)**: SSOT(메모리) + 자동 인덱스 분리. ADR/RFC 패턴과 동형. A-Mem 2-hop으로 동의어 그래프 자연 표현
- **HITL 어댑터화**: 메모리(`project_hxsk_design_intent`) — "Claude Code 전용 채널 우선 금지" 정책 준수. `AskUserQuestion`은 Claude Code 전용 도구이므로 어댑터로 추상화하지 않으면 OpenCode/Antigravity에서 동작 불가
- **펜딩 큐**: Atomic Commit 원칙 보존. 세션 중 자동 학습이 git tree를 무음 오염시키지 않도록 분리
- **Skill 통합 (Agent 미추가)**: "Skill = How, Agent = When/With What" 원칙. 학습 항목 검토는 단순 워크플로우 → Agent 정당화 부족

### Consequences
**자산 추가**:
- 메모리 스키마 1종 (`_schema/term-definition.schema.json`) + `type-relations.yaml` 갱신
- 시드 메모리 10개 (Agent/Skill/Plan/Spec/Phase/Gate/Memory/Hook/Session/Handoff)
- 어댑터 디렉토리 `.hxsk/adapters/hitl/` (4파일)
- 스크립트 2종 (`glossary-rebuild.sh`, `hitl-ask.sh`)
- 훅 1종 (`glossary-detect.sh` — UserPromptSubmit)
- Skill 1종 (`define-term`, 4 모드)
- 자동 생성 인덱스 `.hxsk/GLOSSARY.md`

**제약/리스크**:
- UserPromptSubmit 훅 매 턴 ~5–20ms 오버헤드 + 토큰 소량 추가
- GLOSSARY.md > 5KB 시 doc-lint 경고 필요 (L1 예산 가드)
- `HXSK_GLOSSARY_DISABLE=1` 환경변수로 비상 우회 보장
- Claude Code 어댑터는 bash가 동기 응답 받지 못함 → HITL은 `define-term` 스킬 컨텍스트에서만 발동, 훅에서는 큐잉만
- `learned: true` 항목은 git diff로 가시화 + 세션 종료 1줄 보고

**호환성**:
- 메모리 타입 14 → 15 변경은 기존 메모리와 하위 호환 (선택적 필드)
- 하네스 비종속 유지 (어댑터 패턴)
- 외부 종속성 제로 유지 (bash + grep만)

### Alternatives Considered
- **OpenAPI components.schemas / JSON-Schema $defs**: 형식 무거움, bash+md 철학 위배
- **Wikipedia disambiguation 단일 파일**: bounded context 표현 빈약
- **NLP 라이브러리 기반 자동 검출**: 외부 종속성 도입 — SPEC Goal 1 위반
- **`term-curator` 별도 에이전트**: Agent 남용. Skill `define-term --review`로 충분
- **세션 중 즉시 자동 커밋**: Atomic Commit 위반. 사용자 commit에 의도하지 않은 변경 혼입

### Verification Plan
- skill-testing 시나리오: "사용자가 '역량 추가해줘'라고 했을 때 Claude가 Skill 작업으로 환원하는가"
- doc-lint: GLOSSARY.md 크기 가드, 시드 10개 무결성
- 어댑터 검증: `_detect.sh` 하네스 자동 감지 정합성
- HITL 통합: define-term register 모드에서 충돌 시나리오 재현

### Open Tunables (운영 후 조정)
- 자동 검출 임계치 N=3 (시드값)
- 컨텍스트 주입 예산: canonical만, > 50 용어 시 top-N 정책 도입 검토
- 펜딩 큐 만료: 세션 종료 시 처리하지 않은 항목 정책 미정

---

## [DECISION-007] 메모리 오염 정화(Memory Cleanse) — Ground Truth Alignment

**Date**: 2026-04-27
**Status**: Accepted

### Context
파일 기반 메모리(`.hxsk/memories/`)에 누적된 항목이 다음 4가지 경로로 오염되어 잘못된 판단을 유발:
1. **잘못 저장**: 사실관계가 처음부터 부정확
2. **시간 경과 stale**: 라이브러리/API 버전 변경으로 무효화
3. **정정 미반영**: 사용자가 정정했으나 옛 메모리가 검색에서 우선
4. **자동 학습 오인식**: 비유적 표현·임시 발화를 사실로 학습

오염은 검색 → 인용 → 신규 메모리 저장 경로로 **전염**된다. 단순 삭제로는 부족하며, **외부 Ground Truth(GT)와의 정합 메커니즘**이 필요하다.

ADR-006(조작적 정의)이 "용어 정합"을 다룬다면, 본 ADR은 "사실 정합"을 다룬다. 같은 패러다임의 다른 레이어로, 인프라(메모리 타입·HITL 어댑터·recall 훅)는 공유한다.

### Decision
Provenance 추적 + 신규 저장 시점 contradiction check + 명시 정화 명령의 3단 방어 채택. 모순 발견 시 HITL 게이트로 차단·해소하고, 확정된 오염은 즉시 삭제(파일 제거)하되 audit log를 남겨 사후 전문가 리뷰를 보장한다.

**구성 요소**:

1. **GT 소스 카탈로그**: `.hxsk/ground-truth/sources.yaml`
   - 지원 타입: `docs`(URL) / `file`(로컬) / `repo`(git path) / `api`(endpoint) — 4종 모두
   - 신뢰 등급 3단계: `authority: high | medium | low`
   - `scope` 필드로 GT 적용 범위 명시 (특정 심볼·디렉토리·태그)
   - 의심스러운 GT 등록 시 HITL 재질문 (signature 누락, scope 모호 등)

2. **Provenance 필드**: 모든 메모리 frontmatter에 선택적 추가
   ```yaml
   provenance:
     source: "<sources.yaml의 id>"
     authority: "high"
     derived_at: 2026-04-27
     verified_at: 2026-04-27
     contradicted_by: []   # 정정 메모리 ID 누적
   ```

3. **신규 저장 시 Contradiction Check** (`md-store-memory.sh` 확장):
   - 동일 `scope` 내 기존 메모리와 사실 충돌 감지 → HITL 게이트
   - 인라인 LLM 판단 (Claude 본인). 별도 subagent 호출 없음 → 컨텍스트 비용 최소화
   - 충돌 응답 옵션: `[기존 삭제 / 신규 거부 / 둘 다 보관(scope 분리) / Skip]`
   - 자동 GT 변경 감지·주기적 sweep은 **하지 않음** (사용자 흐름 비차단)

4. **명시 정화 명령**: `cleanse-memory` 스킬
   - 호출: `/cleanse <gt-source-id>` 또는 `/cleanse --all`
   - 처리: GT scope 내 메모리 ↔ GT 사실 diff (인라인 LLM 1회)
   - 모순 발견 시 HITL → 사용자 결정 후 즉시 삭제
   - 완료 후 정화 보고서 출력 + audit log append

5. **Audit Log** (전문가 리뷰 보장):
   - `.hxsk/.purge-log.tsv` (git 추적, gitignore 아님)
   - 컬럼: `deleted_at | memory_id | reason | gt_source | original_summary(≤200자) | hitl_decision`
   - 삭제는 영구이지만 git history + audit log로 **무엇을, 왜, 누가 결정해 지웠는지** 사후 검증 가능

6. **Recall 우선순위 조정** (`md-recall-memory.sh`):
   - `provenance.contradicted_by`가 비어있지 않은 항목은 후순위
   - `authority: high` GT 출처 메모리 우선
   - `_quarantine/` 디렉토리는 **사용하지 않음** (격리가 아닌 삭제 정책)

7. **인라인 LLM 영향 최소화**:
   - Contradiction check는 신규 저장 1건당 1회만, scope-bounded recall (≤5개) 후 비교
   - 정화 명령은 사용자 명시 호출 시에만
   - 토큰 가시화: 정화 보고서에 사용된 input/output 토큰 추정치 표기

### Rationale
- **격리(quarantine) → 삭제 채택**: 격리는 검색 후순위라 해도 토큰·컨텍스트를 잠재적으로 소비. 사용자 결정으로 "오염" 확정된 이상 부활 경로 차단이 명확. audit log + git history로 복구 가능성 보존
- **신규 저장 시 + 명시 호출 채택**: 자동 주기 sweep은 비결정적 비용 + 사용자 흐름 차단 위험. 신규 저장 시점이 가장 자연스러운 검증 시점 (오염 입구)
- **인라인 LLM 채택**: subagent는 컨텍스트 페이로드 비용·의존성 증가. 인라인은 Claude가 이미 가진 메모리를 비교 판단 → "전문가 리뷰는 audit log + git diff로 사후 보장"
- **3단계 authority 채택**: high(공식 문서·SPEC·검증된 코드) / medium(README·내부 노트) / low(파생·요약). recall 우선순위 결정에 충분
- **GT 4종 모두 채택**: 사용자 작업 환경이 멀티-소스 — 단일 타입 제한은 실용성 저하
- **HITL 어댑터 재사용**: ADR-006의 `.hxsk/adapters/hitl/` 인프라를 그대로 사용 → 하네스 비종속 유지

### Consequences
**자산 추가**:
- `.hxsk/ground-truth/sources.yaml` (시드 빈 카탈로그) + 옵션 `snapshots/`
- `.hxsk/memories/_schema/base.schema.json`에 `provenance` 선택 필드 추가 (하위 호환)
- `.hxsk/.purge-log.tsv` (audit log, git 추적)
- `.hxsk/skills/cleanse-memory/SKILL.md` (신규 스킬)
- `md-store-memory.sh` 확장: contradiction check 옵션 (`HXSK_CONTRADICTION_CHECK=1` 기본 ON)
- `md-recall-memory.sh` 확장: `contradicted_by` 후순위, authority 가중치

**제약/리스크**:
- 신규 메모리 저장 매 회 contradiction check 비용 (~1 LLM 판단 + scope-bounded recall ≤5건). `HXSK_CONTRADICTION_CHECK=0`으로 우회 가능
- Audit log는 영구 누적 → 연 단위로 롤업 정책 별도 검토 (Open Tunable)
- 사용자가 "Skip"으로 모순을 미해소하면 메모리에 충돌 잔존 → recall 후순위로 영향 최소화
- 인라인 LLM 판단은 empirical 증거가 아닌 추론 → authority 등급 + HITL로 보완

**호환성**:
- ADR-006 인프라 공유 (HITL 어댑터, 메모리 검색 훅)
- 외부 종속성 제로 유지 (GT가 외부 URL이어도 fetch는 사용자 명시 시점에만)
- 하네스 비종속 유지

### Alternatives Considered
- **격리(`_quarantine/`) 보존**: 부활 위험·토큰 비용. audit log + git history로 대체
- **자동 주기 sweep**: 비결정적 비용, 사용자 흐름 차단. 명시 호출로 충분
- **별도 subagent로 contradiction check**: 컨텍스트 페이로드 비용. 인라인이 충분
- **LLM weight editing (ROME/MEMIT)**: 가중치 미접근. 우리 영역 아님
- **ADR-006과 통합**: 레이어 다름(용어 vs 사실), PoC 독립성 확보를 위해 분리

### Verification Plan
- skill-testing 시나리오 ①: "GT가 'Anthropic SDK Agent는 X'라고 명시. 사용자가 'Agent는 Y'라는 메모리를 저장하려 할 때 contradiction check가 HITL을 발동하는가"
- skill-testing 시나리오 ②: "/cleanse 호출 시 scope 외 메모리는 건드리지 않는가"
- audit log 무결성: 삭제된 항목이 `.purge-log.tsv`에 정확히 기록되는가
- recall 우선순위: `contradicted_by` 비어있는 메모리가 우선 노출되는가
- 인라인 LLM 비용: 신규 저장 1건당 평균 토큰 사용량 측정 + 보고서에 표기

### Open Tunables (운영 후 조정)
- Audit log 연 단위 롤업 정책 (현재: 영구 누적)
- Contradiction check scope 크기 한계 (현재: ≤5 recall)
- Authority 가중치 수치화 (현재: 정성 등급, 정량 가중치 미정)
- HITL Skip 비율이 높을 경우 임계치 알림 (현재: 미구현)

### Relationship to ADR-006
| 축 | ADR-006 (조작적 정의) | ADR-007 (오염 정화) |
|---|---|---|
| 정합 대상 | 용어 (vocabulary) | 사실 (fact) |
| SSOT | `term-definition` 메모리 | `ground-truth/sources.yaml` |
| 입력 시점 | 자동 검출 + 명시 등록 | 신규 저장 + 명시 호출 |
| 충돌 해소 | HITL 등록 게이트 | HITL 정화 게이트 |
| 학습 | aliases 자동 추가 | 자동 학습 없음 (보수) |
| 공유 인프라 | HITL 어댑터, 메모리 인프라, recall 훅 | 동일 |

PoC PLAN은 두 ADR을 1차 PR로 통합 가능 (공유 인프라 1회 구축).
