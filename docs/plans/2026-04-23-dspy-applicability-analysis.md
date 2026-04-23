# DSPy 적용 적합성 분석

**날짜**: 2026-04-23  
**대상**: HExoskeleton v5.5.0  
**결론 요약**: 핵심 시스템에 DSPy 직접 통합 — **부적합**. 관리 대상 프로젝트용 선택적 스킬로는 **조건부 적합**.

---

## 1. 적합성 판단: 불가 (핵심 아키텍처)

### 1.1 근본적 아키텍처 불일치

| 항목 | DSPy | HExoskeleton |
|------|------|--------------|
| 작동 방식 | Python 런타임이 LLM API 호출을 직접 가로채어 최적화 | 마크다운 파일을 AI 하네스(Claude Code·Cursor 등)가 읽어 추론 |
| 프롬프트 위치 | Python Signature/Module 객체 안 | `.hxsk/skills/*/SKILL.md`, `AGENTS.md` 파일 |
| LLM 호출 소유권 | 프레임워크가 직접 소유 | AI 하네스(Claude Code 등)가 소유, HXSK는 관여 불가 |
| 최적화 대상 | API 콜 파라미터·few-shot | 마크다운 텍스트 (컴파일 불가) |

DSPy는 LLM 콜 체인 사이에 끼어들어야 작동합니다.  
Hexoskeleton의 프롬프트(SKILL.md, AGENTS.md)는 Claude Code나 Cursor가 파일로 읽어가는 구조이므로 **DSPy가 개입할 진입점 자체가 없습니다**.

### 1.2 제로 의존성 원칙 위반

```
AGENTS.md: "외부 종속성 없음: 순수 bash 스크립트 + 마크다운 파일 기반."
```

`dspy-ai` 패키지 추가 → pyproject.toml·.venv 생성 → 설치/버전 관리 부담 → 멀티 하네스 환경에서 일관성 깨짐.  
이는 HXSK 설계의 **1번 원칙**을 파기합니다.

### 1.3 멀티 하네스 비호환

HXSK는 Claude Code·Cursor·Copilot·Gemini·Windsurf 동시 지원이 핵심 가치입니다.  
DSPy는 특정 Python 환경에서만 실행되므로, 최적화 결과가 특정 하네스에만 유효할 수 있습니다.

---

## 2. HXSK가 이미 DSPy를 대체하는 방법

DSPy가 해결하려는 문제를 HXSK는 이미 다른 방식으로 해결하고 있습니다.

| DSPy 기능 | HXSK 대응 메커니즘 |
|-----------|-------------------|
| Few-shot 자동 생성 | `lessons-learned` 메모리 → 패턴 누적 (A/B/C/D/E 분류) |
| 프롬프트 컴파일·최적화 | CSO(Claude Search Optimization) — description에 트리거 조건만 |
| 메트릭 기반 반복 개선 | `empirical-validation` 스킬 + `autoresearch` 통합 |
| Hypothesis 검증 | `debugger` 스킬의 3-Strike Rule |
| 결과 추적 | `iteration-log.tsv` + `md-store-memory.sh` |

**CSO는 DSPy SkillReducer 논문 기반** (48% description 압축 + 2.8% 품질 향상)으로 이미 구현된 상태입니다.  
DSPy를 추가해도 동일 기능 중복이 됩니다.

---

## 3. 조건부 적용 가능 영역

HXSK 코어가 아닌 **HXSK가 관리하는 외부 Python 프로젝트**에 DSPy를 도입하고,  
HXSK 스킬이 그것을 오케스트레이션하는 구조는 타당합니다.

### 3.1 적용 패턴: `dspy-optimizer` 스킬

```
.hxsk/skills/dspy-optimizer/
├── SKILL.md              # 트리거·진입점·Quick Reference
└── references/
    ├── when-to-use.md    # 적용 판단 기준
    ├── setup-guide.md    # 대상 프로젝트에 DSPy 셋업
    └── metric-design.md  # HXSK 메트릭 → DSPy metric 함수 변환
```

**트리거 조건** (SKILL.md description):

```
Use when managing an external Python LLM project where:
- The project owns its own LLM API calls (openai/anthropic SDK 직접 사용)
- Manual prompt iterations have regressed 2+ times
- A measurable output metric exists (F1, pass-rate, etc.)
- autoresearch iterations > 5 without improvement
```

### 3.2 적용 가능 외부 프로젝트 유형

| 유형 | 적합도 | 이유 |
|------|--------|------|
| PDF 파싱 파이프라인 (kdb-parsing-llm-test 등) | ★★★★★ | LLM API 직접 소유, F1 메트릭 명확, 수동 회귀 이력 있음 |
| RAG 검색 품질 개선 | ★★★★☆ | Retrieval 정확도 메트릭 정의 가능 |
| 분류/추출 파이프라인 | ★★★★☆ | Pydantic 스키마 → DSPy Signature 자연스럽게 매핑 |
| 코드 생성 도구 | ★★★☆☆ | 메트릭 정의 어려움, 결과 검증 복잡 |
| 범용 챗봇 | ★☆☆☆☆ | 메트릭 불명확, 도메인 특화 어려움 |

---

## 4. 현재 HXSK에서 프롬프트 품질을 높이는 올바른 경로

DSPy 대신 HXSK 고유 방법론으로 스킬 품질을 개선하는 순서입니다.

### Step 1 — 현재 스킬 성능 측정 (`empirical-validation`)

```bash
# 스킬 실행 결과를 iteration-log.tsv에 기록
echo "$(date -I)\t{skill}\t{metric}\t{result}" >> .hxsk/reports/iteration-log.tsv
```

### Step 2 — 회귀 원인 분류 (`lessons-learned`)

| 카테고리 | 내용 |
|---------|------|
| A-Doc-Drift | SKILL.md와 실제 동작 불일치 |
| B-Test-Quality | 검증 기준이 너무 약함 |
| C-State-Sync | 메모리/STATE.md 미갱신 |
| D-Lifecycle | Hook 타이밍 문제 |
| E-Compat | 하네스 간 호환성 깨짐 |

### Step 3 — CSO 원칙으로 description 재작성

```markdown
# Bad (현재 description)
"Task planning and execution workflow management"

# Good (CSO 적용)
"Use when SPEC.md exists and tasks need decomposing into 2-3 atomic steps.
Triggers: new feature, bug with unknown scope, or 3+ file changes needed."
```

### Step 4 — `autoresearch` 통합으로 자동 반복

```
/autoresearch "skill {name} 실패율 감소" Iterations: 10
```

---

## 5. 결론

```
핵심 시스템 통합:  ✗ 불가
  - LLM 콜 체인 진입점 없음
  - 제로 의존성 원칙 위반
  - 멀티 하네스 비호환

관리 프로젝트용 스킬:  △ 조건부 가능
  - Python LLM 프로젝트 한정
  - HXSK는 오케스트레이터 역할만 담당
  - dspy-optimizer 스킬로 캡슐화 권장

현재 대안:  ✓ 이미 동등한 메커니즘 존재
  - CSO + lessons-learned + empirical-validation + autoresearch
  - 추가 의존성 없이 동일한 반복 개선 달성 가능
```

**권장 행동**: DSPy 통합 보류. 관리 대상 Python 프로젝트(kdb-parsing-llm-test 등)에
`dspy-optimizer` 스킬을 통해 선택적으로 적용. HXSK 코어 품질 개선은 CSO + autoresearch 경로 유지.
