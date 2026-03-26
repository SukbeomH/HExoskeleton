---
name: arch-review
description: Validates architectural rules and ensures design quality
version: 4.0.0
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
trigger: "아키텍처 검토, 레이어 위반 확인, 순환 의존성, 설계 문서 검토, 설계 모순 검사, review architecture, check layer violations, before merging structural changes, design review, design contradiction check"
---

## Quick Reference
- **순환 import**: `Grep(pattern: "from.*import", path: "src/")` → 그래프 분석
- **복잡도 검사**: `bash .hxsk/skills/arch-review/scripts/check_complexity.sh`
- **레이어 검증**: UI → Service → Repository 순방향만 허용
- **설계 문서 검토**: 논리 모순, 실현 가능성, 엣지 케이스, 기존 시스템 호환성
- **Severity**: LOW (log), MEDIUM (DECISIONS.md 기록), HIGH (block), CRITICAL (stop)
- **Memory recall**: `md-recall-memory.sh "architecture"` 검색 후 일관성 확인

---

# Skill: Architecture Review

> **Goal**: Validate code changes against architectural rules and patterns.
> **Scope**: Uses Grep/Glob/Read로 architecture validation 수행. 외부 종속성 없음.

---

## Pre-Review: Memory Recall

아키텍처 리뷰 전 과거 결정 사항을 recall하여 일관성을 검증한다:

```bash
bash .hxsk/scripts/md-recall-memory.sh "architecture" "." 5 compact
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
bash .hxsk/skills/arch-review/scripts/check_complexity.sh
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
bash .hxsk/scripts/md-store-memory.sh \
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

- `scripts/check_complexity.sh`: Check shell script complexity via shellcheck
