---
phase: 2
plan: R3
wave: 0
depends_on: []
files_modified:
  - .hxsk/docs/plans/2026-05-04-hermes-working-memory-spine-applicability.md
autonomous: true
user_setup: []
must_haves:
  truths:
    - "Hermes 대안 설계의 핵심 요소(thin bridge, working-memory spine, procedure compression, session recall)가 HXSK 현재 구조와 어디서 겹치고 어디서 비는지 명시한다"
    - "HXSK에 그대로 재사용 가능한 자산과 새로 보강해야 할 자산을 구분한다"
    - "프로젝트 개선에 실제로 쓸 수 있는 최소 도입 순서를 제안한다"
  artifacts:
    - .hxsk/docs/plans/2026-05-04-hermes-working-memory-spine-applicability.md
cross_phase_invariants:
  inherit: []
  new:
    - "새 구조는 HXSK의 core principle(순수 bash + markdown, thin adapter, empirical verification)을 해치지 않아야 한다"
    - "기존 문서/작업 상태 surface 와 충돌하는 중복 문서를 늘리기보다 canonical surface 를 정리하는 방향을 우선한다"
---

# Plan 2.R3: Hermes Working-Memory Spine를 HXSK 개선에 적용할 수 있는가

<objective>
Hermes 네이티브 대안 설계(thin bridge + working-memory spine + compression artifacts)를
HExoskeleton(HXSK) 구조에 대입해, 실제 프로젝트 개선 과제로 전환 가능한지 검토한다.

Output:
1. 현재 HXSK와의 구조적 정합성 판정
2. 바로 재사용 가능한 기존 자산 목록
3. 드리프트/결손 surface 목록
4. 최소 개선 로드맵
</objective>

<context>
Load for context:
- llms.txt
- AGENTS.md
- .hxsk/SPEC.md
- .hxsk/CURRENT.md
- .hxsk/DECISIONS.md
- .hxsk/PATTERNS.md
- .hxsk/VERIFICATION.md
- .hxsk/ARCHITECTURE.md
- .hxsk/STACK.md
- docs/codebase-summary.md
</context>

## 1. 판정 요약

### 결론
**적용 가능성 높음.**

HXSK는 이미 Hermes 대안 설계의 70~80%를 자체적으로 구현하고 있다.
다만 현재는 **문서 drift** 와 **하네스별 bridge 명시 부족** 때문에,
Hermes/Codex/OpenCode 같은 non-Claude harness 입장에서는
"어디가 canonical active state 인가"가 완전히 선명하지 않다.

따라서 이 설계는 HXSK에 새 철학을 들여오는 작업이라기보다,
**이미 있는 철학을 하네스 중립적으로 정리·노출하는 리팩터링**에 가깝다.

---

## 2. Hermes 대안 설계 ↔ HXSK 현재 구조 매핑

| Hermes 대안 설계 요소 | HXSK 기존 자산 | 판정 |
|---|---|---|
| Thin Bridge | `llms.txt`, `AGENTS.md`, `.hxsk/prompts/setup.md`, `.hxsk/scripts/install.sh` | 이미 강함 |
| Repo-local source of truth | `.hxsk/` 전체, 특히 `SPEC.md`, `DECISIONS.md`, `ARCHITECTURE.md`, `STACK.md` | 이미 강함 |
| Working-memory spine | `CURRENT.md`, `DECISIONS.md`, `PATTERNS.md`, `VERIFICATION.md`, `TODO.md` | 부분 충족 |
| Session continuity | Claude hooks + file-based memory + `session-summary` memories | Claude에 강함 / 타 하네스는 약함 |
| Procedure compression | `.hxsk/skills/`, `.hxsk/agents/` | 이미 강함 |
| Recall / recovery | `md-recall-memory.sh`, file memories, `CURRENT.md` | 강함 |
| Output compression | 스킬 quick reference, gate workflow, verification artifacts | 중간 이상 |
| Task tracking | `TODO.md`, issues/, phases/, workflow/GATES.md | 강함 |

핵심 해석:
- **HXSK는 이미 thin bridge + repo-local SSOT 구조를 달성**했다.
- 부족한 것은 **working-memory spine의 canonical naming/required files 정리**다.

---

## 3. 바로 재사용 가능한 기존 자산

### 3.1 CURRENT.md
- 역할: 지금 무엇을 하고 있는지, 최근 커밋, 다음 단계
- Hermes 대안 설계의 `CURRENT` 역할과 거의 동일
- 별도 새 문서가 필요 없다

### 3.2 DECISIONS.md
- 역할: 결정 근거와 트레이드오프 기록
- Hermes 대안 설계의 `DECISIONS` 역할과 직접 대응

### 3.3 VERIFICATION.md
- 역할: must-have truth, evidence, human verification, verdict
- Hermes 대안 설계의 `VERIFY` 역할로 재사용 가능
- 새 `VERIFY.md`를 만들기보다 **`VERIFICATION.md`를 canonical verify surface로 선언**하는 편이 낫다

### 3.4 PATTERNS.md
- 역할: 세션을 넘어 재사용 가능한 distilled learnings
- Hermes skills/memory의 중간층 역할 수행

### 3.5 File-based memory (`.hxsk/memories/`)
- Hermes built-in memory 대신 사용하는 장기 기억 백본
- 특히 `session-summary`, `session-handoff`, `pattern-discovery`, `lessons-learned` 는
  Hermes 대안 설계의 session_search/memory 기능과 유사한 역할을 한다

---

## 4. 현재 드리프트 / 결손 surface

### 4.1 `STATE.md` referenced-but-missing
사실 확인:
- `AGENTS.md`, `ARCHITECTURE.md`, `docs/codebase-summary.md` 등은 `STATE.md`를 active state surface로 언급한다
- 그러나 현재 repo에는 실제 `STATE.md` 파일이 없다

의미:
- HXSK가 의도한 working-memory spine 이 문서/실파일 기준으로 불일치 상태다
- Hermes/Codex/OpenCode 같은 non-native harness 입장에서는 active state 복원 지점이 애매해진다

권장:
- **Option A:** `STATE.md`를 실제 canonical 파일로 복구
- **Option B:** `CURRENT.md`와 다른 surface 로 역할이 흡수되었다면, 문서 전체에서 `STATE.md` 언급 제거

개인 추천:
- HXSK의 gate/dispatcher/phase 운영을 보면 `STATE.md`는 살아있는 편이 더 자연스럽다.
- 따라서 **복구 쪽이 더 적합**하다.

### 4.2 `SESSION_HANDOFF.md` referenced-but-missing
사실 확인:
- `docs/codebase-summary.md`는 `.hxsk/TODO.md / CURRENT.md / SESSION_HANDOFF.md`를 나열한다
- 실제 파일은 없다

의미:
- handoff 책임이 현재는 memory(`session-handoff`)와 `CURRENT.md`로 분산된 상태일 가능성이 크다
- 그러나 문서상 surface 와 실제 surface 가 다르다

권장:
- **Option A:** `SESSION_HANDOFF.md`를 실제로 두고 session-end summary의 human-readable landing page 로 사용
- **Option B:** file surface 는 폐기하고 memory-only 로 간다면 문서에서 제거

개인 추천:
- Hermes/타 하네스 친화성을 높이려면 **짧은 `SESSION_HANDOFF.md`를 두는 편이 낫다**
- 단, 장문 로그가 아니라 `last branch / last task / next action / verification pointer` 정도의 매우 얇은 파일이어야 한다

### 4.3 Hermes adapter 부재
사실 확인:
- HXSK는 Claude/Cursor/Copilot/Gemini/Windsurf/OpenCode/Codex 어댑터는 언급한다
- Hermes 전용 adapter/guide 는 현재 보이지 않는다

의미:
- Hermes 사용자는 HXSK를 적용할 수 있지만, "어떤 Hermes 기능을 어디에 매핑해야 하는가"가 문서화되어 있지 않다

권장:
- `.hxsk/adapters/hermes/README.md` 또는 `docs/integrations/hermes-agent.md` 추가
- 다룰 내용:
  - `memory` ↔ `.hxsk/memories/` 관계
  - `session_search` ↔ `md-recall-memory.sh`
  - `todo` ↔ `TODO.md`
  - `delegate_task` ↔ dispatcher / file ownership rules
  - `cronjob` ↔ verify / cleanup / periodic recall workflows

### 4.4 Codex + context-mode + HXSK 공존 규칙 부재
사실 확인:
- 전역 Codex에는 context-mode용 `~/.codex/hooks.json`을 둘 수 있다
- HXSK는 repo-local `.codex/hooks.json` 또는 git hook fallback 패턴을 제안한다
- 현재 두 시스템의 공존 merge rule 은 명시돼 있지 않다

의미:
- 사용자가 context-mode를 켠 뒤 HXSK repo에서도 Codex를 쓰면,
  전역 훅과 repo-local 훅 중 어느 쪽이 우선인지, Stop hook 을 어떻게 병합할지 혼동 가능

권장:
- Codex adapter 문서에 **"global context-mode + repo-local HXSK stop/prune coexistence"** 섹션 추가
- 최소한 다음을 명시:
  1. global hooks = context routing / session capture
  2. repo-local hooks = HXSK prune / local verify / repo bookkeeping
  3. 둘이 충돌하면 repo-local에서 Stop hook chain 을 merge 해야 함

---

## 5. HXSK 개선에 실제로 쓸 수 있는 최소 변경 세트

### Phase A — Working-memory spine 정합화
목표: active-state surface 를 모든 하네스에서 동일하게 이해 가능하게 만든다.

#### A1. Canonical active docs 확정
권장 canonical set:
- `SPEC.md` = 목표/제약
- `CURRENT.md` = 현재 작업 컨텍스트
- `STATE.md` = 구조화된 진행 상태 / gate / owner / next checkpoint
- `VERIFICATION.md` = 검증 기준과 실제 evidence
- `DECISIONS.md` = 설계 결정
- `PATTERNS.md` = 재사용 패턴
- `TODO.md` = backlog
- `SESSION_HANDOFF.md` = 다음 세션 진입용 얇은 스냅샷

#### A2. 문서 drift 제거
수정 후보:
- `AGENTS.md`
- `ARCHITECTURE.md`
- `docs/codebase-summary.md`
- `llms.txt`
- `.hxsk/prompts/setup.md`

해야 할 일:
- `STATE.md`, `SESSION_HANDOFF.md`가 실제 canonical file 이면 생성/템플릿 연결
- 아니면 언급 제거

#### A3. 검증 surface 에 반영
- `bootstrap.sh` 또는 `setup-verify.sh`에서 canonical active docs 존재 여부 점검
- `doc-lint.sh` 또는 `check-consistency.sh`에 active-surface consistency check 추가

### Phase B — Hermes bridge 추가
목표: Hermes 사용자가 HXSK를 zero-guess로 적용 가능하게 한다.

#### B1. Hermes adapter/guide 작성
새 문서 제안:
- `.hxsk/adapters/hermes/README.md`

최소 포함 항목:
1. Hermes에서 먼저 읽을 파일 순서
2. Hermes memory를 무엇에 쓰고, 무엇을 `.hxsk/memories/`에 남길지
3. Hermes `todo` 와 `TODO.md`의 역할 분리
4. Hermes `session_search` 대신/병행해서 `md-recall-memory.sh`를 언제 쓰는지
5. Hermes `delegate_task` 사용 시 HXSK dispatcher의 file ownership rule 적용 방법

#### B2. AGENTS.md에 Hermes section 추가
- "Hermes Agent Usage" 섹션을 얇게 추가
- 핵심은 정책만: read order, verification duty, memory split, ownership rule

### Phase C — Codex/context-mode/HXSK 공존 지침
목표: Codex에서 context-mode와 HXSK를 같이 쓸 때 운영 혼동 방지.

#### C1. Codex adapter 문서 업데이트
- `.hxsk/adapters/README.md` 또는 codex 관련 문서에 다음을 기록:
  - 전역 `~/.codex/config.toml` + `~/.codex/hooks.json`은 context-mode용
  - repo-local `.codex/hooks.json`은 HXSK repo bookkeeping용
  - Stop hook 병합 예시
  - git hook fallback 이 최후 보루임을 명시

#### C2. 설치 스크립트 개선 검토
현재 `install.sh --harness codex`는 단순 copy 중심이다.
개선 후보:
- 기존 `.codex/hooks.json` 존재 시 merge 안내 강화
- `--merge` 모드 추가 검토

---

## 6. 구현 우선순위 추천

### 1순위 — 문서 drift 제거
이유:
- 지금 가장 큰 문제는 "철학 부재"가 아니라 "canonical state surface 불명확"이다
- 작은 문서 정리만으로 Hermes/Codex/OpenCode 친화성이 즉시 올라간다

### 2순위 — Hermes bridge 추가
이유:
- HXSK는 Claude-native 설명이 강하지만, Hermes 관점의 entry mapping 이 없다
- 얇은 bridge 문서만 추가해도 사용자/에이전트 모두 시행착오 감소

### 3순위 — Codex/context-mode/HXSK 공존 가이드
이유:
- 실제 운영에서 곧바로 부딪힐 문제다
- 특히 global hooks 와 repo-local hooks 공존은 명시가 없으면 반복 혼동 포인트가 된다

---

## 7. 최종 판단

### 적용 가능한가?
**예. 충분히 가능하다.**

### 가치가 있는가?
**예. 특히 하네스 중립성과 active-state 명확성 측면에서 가치가 크다.**

### 핵심 포인트
이 작업은 HXSK에 새로운 거대한 하위 시스템을 추가하는 일이 아니다.
오히려 아래 세 가지를 정리하는 작업이다:
1. 이미 있는 active docs 를 canonical spine 으로 재정렬
2. Hermes 같은 non-Claude harness 에 대한 thin bridge 명시
3. Codex/context-mode 같은 외부 context discipline 과 HXSK의 로컬 discipline 을 공존 가능하게 문서화

즉, **저비용 대비 효과가 큰 개선 과제**로 판단한다.

---

## 8. 바로 다음 액션 제안

### Option 1 — 문서 정합화부터
- `STATE.md`, `SESSION_HANDOFF.md` 처리 방침 확정
- 관련 문서 drift 일괄 수정

### Option 2 — Hermes bridge 초안 작성부터
- `.hxsk/adapters/hermes/README.md` 초안 작성
- AGENTS.md에 얇은 Hermes section 추가

### Option 3 — Codex 공존 가이드부터
- context-mode + HXSK coexistence 노트 작성
- Codex adapter 문서 보강

권장 순서:
**Option 1 → Option 2 → Option 3**

<verification>
After this analysis, verify:
- [ ] 기존 HXSK 자산과 Hermes 대안 설계 간 매핑이 명시되었다
- [ ] missing/drift surface 가 구체적으로 식별되었다
- [ ] 최소 개선 단계가 실행 가능한 수준으로 제안되었다
</verification>

<success_criteria>
- [ ] HXSK에 이미 있는 것과 없는 것이 구분되었다
- [ ] 새로 만들 문서보다 재사용할 canonical surface가 우선 식별되었다
- [ ] Hermes 적용이 "가능/불가"가 아니라 실제 개선 항목으로 환원되었다
</success_criteria>
