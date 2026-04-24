---
allowed-tools:
- Read
- Grep
- Glob
- Bash
description: Use when validating code for circular imports, layer violations, or design
  doc logic errors before merging architecture-level changes.
name: arch-review
trigger: 아키텍처 검토, 레이어 위반 확인, 순환 의존성, 설계 문서 검토, 설계 모순 검사, review architecture, check
  layer violations, before merging structural changes, design review, design contradiction
  check, 구조 검증, 코드 구조 점검, 아키텍처 일관성 확인, 과거 아키텍처 결정 검토, memory recall architecture,
  boundary compliance check, 경계 준수 확인, 복잡도 검사, shellcheck 구조 분석, 설계 실현 가능성 검증, 엣지
  케이스 아키텍처, severity 평가, arch review before merge, validate code structure, circular
  import check, layer isolation check, design doc consistency
version: 4.0.0
---

## Quick Reference
- **Memory Recall**: `md-recall-memory.sh` 로 과거 아키텍처 결정과 일관성 필수 검증
- **구조 무결성**: 순환 import, 레이어 위반 (UI→Service→Repo), 복잡도 즉시 차단
- **설계 검증**: 논리 모순, 실현 불가능성, 엣지 케이스 누락 시 HIGH/CRITICAL 판정
- **Severity 행동**: LOW(로그), MEDIUM(문서화), HIGH(차단), CRITICAL(전체 중지)
- **보고서 생성**: 위반 사항 구조화 (JSON) 후 결정 사항 메모리 저장

## Pre-Review: Memory Recall

아키텍처 리뷰 전 과거 결정 사항을 recall하여 일관성을 검증한다:

```bash
bash .hxsk/hooks/md-recall-memory.sh "architecture" "." 5 compact
```

또는 네이티브 도구:
```
Grep(pattern: "architecture|arch.*decision", path: ".hxsk/memories/architecture-decision/", output_mode: "files_with_matches")
```

---

## Procedure

### Step 1: Run Architecture Check

Grep/Glob을 사용하여 구조 검증:

```
# 순환 import 후보 검출 (같은 디렉토리 내 상호 참조)
Grep(pattern: "from \\.\\. import|from \\. import", path: "src/", output_mode: "files_with_matches")

# 레이어 위반 검출 (예: UI가 Repository를 직접 호출)
Grep(pattern: "from.*repository.*import|import.*repository", path: "src/ui/", output_mode: "files_with_matches")
Grep(pattern: "from.*ui.*import|import.*ui", path: "src/repository/", output_mode: "files_with_matches")
```

복잡도 검사 (shellcheck 기반):
```bash
shellcheck .hxsk/hooks/*.sh 2>&1 || true
```

### Step 2: Verify Boundary Compliance

Cross-check against defined boundaries:

| Boundary | Check |
|----------|-------|
| Layer isolation | UI → Service → Repository only |
| Circular deps | No cycles in call graph |
| External calls | Only via approved adapters |

### Step 3: Design Document Review (설계 문서 검토)

설계 문서(design doc, PLAN.md, SPEC.md 등)가 대상인 경우 아래 체크리스트를 수행:

**논리적 일관성 검증:**
- Phase/Step 간 순서 모순 여부 (순차 표기이나 실제 인터리브 필요 등)
- 문서 내 동일 개념에 대한 상충 설명 (예: tracked vs untracked 혼용)
- 의존성 규칙의 완전성 (순환, 다이아몬드, 다중 의존성 처리)

**실현 가능성 검증:**
- 명시된 도구/스크립트로 해당 작업이 실제 가능한지 (예: bash로 XML 파싱)
- 기존 시스템과의 호환성 (변경 대상 파일 목록 누락 여부)
- 전제 조건의 유효성 (gitignore 상태, 디렉토리 존재 여부 등)

**엣지 케이스 검증:**
- 장애/중단 시 복구 경로 존재 여부
- 동시성 문제 (병렬 읽기/쓰기, 파일 잠금)
- 사이드이펙트 경로 (lock 파일, 자동 생성 파일)

**Severity 기준:**
- 논리 모순 → HIGH (설계 수정 필수)
- 실현 불가 → HIGH (대안 제시 필수)
- 엣지 케이스 미처리 → MEDIUM (문서화 권장)
- 네이밍/포맷 불일치 → LOW (로그)

### Step 4: Generate Report & Store Memory

Compile findings into a structured report.
중요한 아키텍처 결정은 메모리에 저장:

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Architecture Decision: {title}" \
  "{context and decision}" \
  "architecture,decision" \
  "architecture-decision"
```

---

## Output Format

```json
{
  "status": "PASS | WARN | FAIL",
  "violations": [
    {
      "type": "layer_violation",
      "source": "src/ui/Dashboard.tsx",
      "target": "src/repository/UserRepo.ts",
      "severity": "HIGH",
      "recommendation": "Add service layer"
    }
  ],
  "patterns_matched": ["repository-pattern", "facade-pattern"]
}
```

---

## Escalation Matrix

| Severity | Action |
|----------|--------|
| LOW | Log warning, proceed |
| MEDIUM | Require acknowledgment in DECISIONS.md |
| HIGH | Block and require human approval |
| CRITICAL | Stop all work, escalate to tech lead |

## Scripts

(없음 — shellcheck, Grep, Glob 등 에이전트 네이티브 도구로 직접 수행)

## Iron Laws
NO ARCHITECTURE REVIEW WITHOUT MEMORY RECALL FIRST
NO LAYER VIOLATION WITHOUT UNIDIRECTIONAL FLOW (UI -> SERVICE -> REPOSITORY)
NO CIRCULAR DEPENDENCY WITHOUT GRAPH CYCLE DETECTION
NO DESIGN IMPLEMENTATION WITHOUT LOGIC AND FEASIBILITY VERIFICATION
NO CRITICAL VIOLATION RESOLUTION WITHOUT STOPPING ALL WORK
NO HIGH SEVERITY BLOCK RESOLUTION WITHOUT HUMAN APPROVAL
NO REPORT GENERATION WITHOUT STRUCTURED VIOLATION LOGGING
