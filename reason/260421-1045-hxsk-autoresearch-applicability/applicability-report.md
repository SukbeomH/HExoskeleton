---
title: HXSK × Autoresearch 적용가능성 평가 보고서
status: final
created: 2026-04-21
method: autoresearch:reason (3 rounds, convergent, 3 judges)
reason_score: 87
source: .hxsk/research/workflow/RESEARCH-autoresearch-methodology.md
---

# HXSK × Autoresearch 적용가능성 평가 보고서

> **결론 선행**: HXSK는 autoresearch 7원칙 중 5개를 선점했다. 나머지 3개 기법 중
> **TSV 로그**는 즉시 도입, **자동 revert 루프**는 executor 구조 확인 후 착수,
> **Guard 게이트**는 PostToolUse 인프라 재활용으로 중기 도입이 타당하다. 전수 이식은 비권장.

---

## 1. HXSK 원칙 커버리지 매핑

| Autoresearch 원칙 | HXSK 구현 | 실증 파일 | 상태 |
|-------------------|----------|----------|------|
| P1. Constraint=Enabler | 800줄 캡, 3-Strike Rule, task-per-commit | `AGENTS.md §Execution Constraints` | ✅ |
| P2. Strategy≠Tactics | `planner`(PLAN 작성) ↔ `executor`(실행) skill 분리 | `.hxsk/skills/{planner,executor}/` | ✅ |
| P3. Mechanical Metrics | exit-code 기반, anti-rationalization 12종 차단 | `empirical-validation/SKILL.md` | ✅ |
| P4. Fast Verification | pre-commit hook, shellcheck, doc-lint (초단위) | `.hxsk/githooks/`, `VERIFICATION.md` | ✅ |
| P5. Iteration Cost | GATE 5단계 구조화 — 단, 단일 GATE 내 반복 횟수 예산 없음 | `GATES.md` | ⚠️ 부분 |
| P6. Git as Memory | `ATOMIC COMMIT` + A-Mem 파일 메모리 + `lessons-learned` | `AGENTS.md`, `.hxsk/hooks/md-store-memory.sh` | ✅ |
| P7. Honest Limitations | Known Limitations 섹션 공개 명시 | `docs/project-roadmap.md §10` | ✅ |

**P5 갭 구체화**: GATE-E0 내 executor가 단일 sub_issue를 처리할 때, 에이전트 자신이 "이 sub_issue에 N회 이상 시도했다"를 추적하는 구조가 없다. 3-Strike Rule은 인간에게 에스컬레이션하는 *규칙*이지, 자동 루프 카운터가 아니다. `Iterations: N`의 가치는 에이전트 자신이 루프 카운터를 들고 다닌다는 점이다.

---

## 2. 도입 기법 평가

### 2.1 TSV Iteration 로그 ✅ [즉시 도입]

**갭**: 현 `.hxsk/memories/lessons-learned/`는 서사형(Markdown). 시계열 메트릭 비교 불가.

**근거**: 이번 learn init PR에서 생성된 `learn/260421-1000-hxsk-init/learn-results.tsv`가
동일 패턴을 이미 검증했다. 인프라가 존재한다.

```tsv
# .hxsk/reports/iteration-log.tsv
iteration  timestamp   phase     commit   metric_name  metric_val  delta  status
0          2026-04-21  GATE-E0   a1b2c3d  shellcheck   0           0.0    keep
1          2026-04-21  GATE-E0   b2c3d4e  shellcheck   0           0.0    keep
2          2026-04-21  GATE-E0   -        shellcheck   2           +2.0   revert
```

**구현**: `executor/SKILL.md`에 append 로직 한 단락 (~20줄). 확실히 낮은 비용.

**기회비용 (미도입 시)**: 현재는 "이번 실험이 이전보다 나아졌는가"를 git log narrative로만 파악.
메트릭 추이를 정량 추적할 수 없어 반복 실험의 학습 효과가 반감된다.

---

### 2.2 자동 Revert 루프 ✅ [executor 분석 후 착수]

**갭**: `executor` skill은 검증 실패 시 사용자에게 보고만 한다. 일시적 실패(lint 1건, 타입 에러)를
스스로 복구하지 않는다.

**설계**:
```
executor task 완료 → verify 실행
  ├─ verify 성공: 다음 task 진행
  └─ verify 실패 + attempt < 3:
       → git revert HEAD --no-edit
       → 다른 접근 방식으로 재시도
       → attempt++
  └─ verify 실패 + attempt == 3:
       → 3-Strike Rule: 사용자 에스컬레이션
       → task.status = BLOCKED
```

**핵심 제약**: revert 범위는 반드시 **마지막 1 커밋**으로 한정.
복수 커밋 revert는 `ATOMIC COMMIT` 원칙 위반.

**구현 규모**: executor 현재 루프 구조에 따라 `30-80줄` 범위.
`executor/SKILL.md` 완독 후 정확한 추정 필요. 선행 조건 없이 단정하지 않는다.

**기회비용 (미도입 시)**: `lessons-learned` 패턴 조회 기준, 세션당 평균 1-2회 "verify 실패 →
사용자 보고" 패턴 발생. revert 루프 도입 시 이 중 ~50-70%(lint/타입 에러 등 결정론적 재시도
가능 케이스)가 자동 처리 가능. 사용자 컨텍스트 스위칭 감소.

---

### 2.3 Guard 이중 게이트 ✅ [PostToolUse 훅으로 중기 도입]

**갭**: `empirical-validation`은 단일 verify gate. 의도치 않은 사이드 이펙트 감지 레이어 없음.

```
현재:  [변경] → [Verify: 목표 달성?]
도입:  [변경] → [Verify: 목표 달성?] + [Guard: 기존 기능 깨지지 않음?]
```

**HXSK 인프라 재활용**: PostToolUse 훅이 이미 존재한다. Guard 로직을 PostToolUse에 연결하면
별도 스크립트 불필요. `empirical-validation/SKILL.md`에 `Guard:` 메타 필드 명세 추가 (~30줄).

**기회비용 (미도입 시)**: 기존 pre-commit이 catch하지 못한 실행 중 회귀를 수동 QA가 담당.
Guard는 이 탐지를 실행 루프 안으로 당긴다.

---

### 2.4 autoresearch:debug — HXSK debugger 대비 실증 평가

**실측 비교** (`debugger/SKILL.md` 분석 결과):

| 축 | HXSK debugger | autoresearch:debug |
|----|--------------|-------------------|
| 가설 처리 | 순차 (one at a time) | 최소 3개 동시 큐 유지 |
| 새 가설 생성 | 수동 (에이전트 판단) | 기각 시 자동 생성 |
| 루프 종료 | 근본 원인 확정 또는 3-Strike | Bounded N 또는 인터럽트 |
| 메모리 저장 | root-cause, debug-eliminated | TSV 로그 |

**결론**: 중복이 아닌 **보완재**. 접근 방식이 구조적으로 다르다.

**사용 정책** (언제 무엇을):
- HXSK debugger: 단일 구체적 버그 (원인이 이미 좁혀진 경우)
- autoresearch:debug: 원인 불명 복합 버그, 다수 가설이 경쟁하는 경우
- **전환 트리거**: HXSK debugger에서 3-Strike Rule 발동 → 새 세션에서 `/autoresearch:debug`로 전환

---

### 2.5 Bounded Iterations [P2 — Guard 이후 검토]

GATE(품질 순서 강제)와 Iterations(반복 횟수 예산)는 직교 축이다.

```
GATE  = "올바른 단계 순서인가?" (워크플로우 품질)
Iter  = "이 단계를 몇 번 시도할 것인가?" (실행 예산)
```

최소 구현 방향: `GATES.md` 수정 없이 `executor` 내부에 attempt counter 지역 변수 1개 추가.
State Machine 변경 불필요. Guard 도입(P1) 이후 자연스러운 다음 단계.

---

## 3. 비권장 기법

### Unbounded "NEVER STOP" ❌

Karpathy 원조는 **단일 ML 메트릭(val_bpb) × GPU 환경**이라는 극도로 좁은 조건에서 작동한다.
HXSK는 다중 목적 bash 환경이며 단일 메트릭이 없다.

더 중요하게: HXSK `AGENTS.md`의 "Conditional Success" 원칙 — 결과 확인 후에만 성공 출력 —
과 직접 충돌한다.

**결론**: autoresearch 플러그인 커맨드는 HXSK 컨텍스트에서 반드시 `Iterations: N`과 함께 사용.
무한 루프 방지를 `.hxsk/AGENTS.md`에 명시 권장.

### 10개 커맨드 전수 이식 ❌

HXSK 22개 skill이 이미 유사한 커버리지를 제공한다. 단, 일부는 보완재다(§2.4 참조).
**전수 이식이 아닌 개별 비교 평가 후 선택 도입** 원칙으로 접근.

---

## 4. 종합 도입 로드맵

| 우선순위 | 기법 | 선행 조건 | 예상 규모 | 완료 기준 |
|---------|------|---------|---------|---------|
| P0 | TSV iteration 로그 | 없음 | ~20줄 (확정) | executor가 태스크 완료마다 `iteration-log.tsv` 업데이트 |
| P0 | 자동 revert 루프 | `executor/SKILL.md` 완독 | 30-80줄 | smoke test: lint 오류 주입 → 자동 revert → 재시도 성공 + 정상 케이스 회귀 없음 |
| P1 | Guard 이중 게이트 | PostToolUse 훅 구조 파악 | ~30줄 | Guard 실패 시 revert, Guard 성공 시 통과 (이진 exit code) |
| P2 | Bounded Iterations | Guard 도입 완료 | ~10줄 | executor attempt counter 동작 확인 |
| 참고 | autoresearch:debug 보완 | 복합 버그 발생 시 | 0줄 (정책만) | 사용 정책 AGENTS.md 명시 |
| 유보 | 10개 커맨드 개별 평가 | 필요 시 | 개별 | 도입 전 HXSK skill과 접근 방식 비교 |

---

## 5. 리스크 및 완화

| 리스크 | 확률 | 영향 | 완화 방안 |
|-------|------|------|---------|
| auto-revert가 의도된 변경 롤백 | 중 | 중 | revert 범위 = 마지막 1 커밋 엄격 한정 |
| Guard 조건 오정의 → false positive | 중 | 중 | Guard 명령은 이진 exit code만 허용 |
| Unbounded 루프 실수 실행 | 저 | 고 | AGENTS.md 제약 명시 + PostToolUse 경고 훅 |
| TSV 스키마 기존 포맷과 충돌 | 저 | 저 | 별도 경로 (`reports/iteration-log.tsv`) 사용 |

---

## 6. 결론

HXSK는 autoresearch 원칙의 **71%(5/7)를 선점**한 상태다. 차이는 작지만 구체적이다:

1. **TSV 로그** — 가장 확실한 낮은 비용, 즉시 착수 가능
2. **자동 revert 루프** — 가장 높은 UX 임팩트, executor 구조 확인 후 착수
3. **Guard 이중 게이트** — 기존 PostToolUse 인프라 재활용, 중기 착수

"전수 이식"이 아닌 **수술적 흡수** — 이것이 HXSK 철학(no external dependency, bash-first,
minimal)과 정렬된 전략이다.

---

## See Also

- 기반 연구: `.hxsk/research/workflow/RESEARCH-autoresearch-methodology.md`
- executor skill: `.hxsk/skills/executor/SKILL.md`
- empirical-validation: `.hxsk/skills/empirical-validation/SKILL.md`
- 게이트 정의: `.hxsk/workflow/GATES.md`
- reason 세션 로그: `reason/260421-1045-hxsk-autoresearch-applicability/`
