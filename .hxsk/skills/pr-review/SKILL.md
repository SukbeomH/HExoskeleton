---
description: Use when a PR number or URL is provided to conduct a comprehensive code
  review and issue a merge verdict based on blocker severity.
name: pr-review
trigger: 코드 리뷰, PR 리뷰, 풀 리퀘스트 검토, review PR, code review, security review, PR 검토,
  코드 확인, 풀리퀘스트 리뷰, pr check, code audit, security audit, architecture review, devops
  review, qa review, ux review, PR 승인, 머지 승인, PR 거절, request changes, approve PR,
  blocker 확인, HXSK 리뷰, 스펙 준수 확인, 컨벤션 체크, 6 페르소나 리뷰, 코드 품질 평가, 테스트 커버리지 확인, 보안 취약점
  분석, 성능 영향도 분석, /pr-review, gh pr review, 코드 점검, 풀 요청 리뷰, 개발자 리뷰, QA 리뷰, 아키텍처 리뷰,
  데브옵스 리뷰, UX 리뷰, 보안 감사, 스펙 검증, ADR 검증, 컨벤션 검증, 레슨러너드 저장, blocker 식별, severity 분류,
  코드 스캔, 코드 분석, PR 분석, 머지 가능 여부, 코드 smell, 오버플로우, 리팩토링 제안, 이슈 분리, SPEC.md, DECISIONS.md,
  CONVENTIONS.md, HXSK 컨벤션, 6인 리뷰, 코드 리뷰 봇, 자동화 리뷰
---

## Quick Reference
- **Context**: 반드시 PR 컨텍스트 로드 후 6-Persona 평가 수행
- **Blocker**: 1개 이상 발견 시 즉시 REQUEST_CHANGES (머지 불가)
- **Scope**: 기존 코드 문제는 새 이슈로 분리, PR 범위 엄수
- **Alignment**: SPEC/DECISIONS 준수 여부 필수 검증
- **Memory**: [High] 이상 발견 시 Lessons-Learned 저장 필수

## Usage

```
/pr-review <PR number or URL>
```

---

## Review Process

### Step 1: Load PR Context

```bash
gh pr view <PR> --json title,body,files,additions,deletions,commits
gh pr diff <PR>
```

Read changed files to understand the full context of modifications.

### Step 2: Execute 6-Persona Review

Each persona reviews independently, producing findings with severity classification.

---

## Personas

### 1. Developer Review

**Focus**: Code quality, readability, maintainability

- Naming conventions and consistency
- Function/class design (SRP, complexity)
- Error handling completeness
- Type hints and documentation
- Ruff/mypy compliance
- Anti-patterns and code smells

### 2. QA Engineer Review

**Focus**: Test coverage, edge cases, regression risk

- Test coverage for new/changed code
- Edge case handling (empty inputs, boundaries, concurrency)
- Regression risk assessment
- Integration test needs
- Mock usage appropriateness (per Test Policy: minimize mocks)

### 3. Security Review

**Focus**: Vulnerabilities, data handling, compliance

- OWASP Top 10 checks (injection, XSS, CSRF, etc.)
- Sensitive data exposure (secrets, PII logging)
- Input validation and sanitization
- Authentication/authorization correctness
- Dependency vulnerabilities

### 4. Architecture Review

**Focus**: Design decisions, scalability, alignment

- SPEC alignment — changes match `.hxsk/SPEC.md` requirements
- Module boundaries and coupling
- API contract consistency
- Database schema impact
- Breaking changes detection

### 5. DevOps Review

**Focus**: Build, deploy, monitoring

- CI/CD pipeline compatibility
- Configuration changes (env vars, secrets)
- Docker/infrastructure impact
- Logging and observability
- Performance impact at scale

### 6. UX Review (UI 변경이 있는 경우만)

**Focus**: User experience, accessibility

- Visual consistency with design system
- Accessibility (WCAG 2.1 AA)
- Interaction flow and usability
- Responsive design
- Error messaging for users

---

## Severity Classification

모든 발견 사항에 심각도 부여:

| Severity | 의미 | 조치 |
|----------|------|------|
| **[Blocker]** | PR 머지 불가. 기능 장애, 보안 취약점, 데이터 손실 위험 | 즉시 수정 필수 |
| **[High]** | 심각한 품질 문제. 성능 저하, 테스트 누락, 설계 위반 | 머지 전 수정 권장 |
| **[Medium]** | 개선 사항. 리팩토링, 문서화, 더 나은 패턴 적용 | 후속 PR에서 처리 가능 |
| **[Nitpick]** | 사소한 스타일/취향. 네이밍 제안, 코드 포맷 | 선택적 반영 |

---

## Output Format

```markdown
# PR Review: <PR title>

## Summary
<Overall assessment: APPROVE / REQUEST_CHANGES / COMMENT>
<1-2 sentence overview>

## Findings

### [Blocker] <Finding title>
**Persona**: <which reviewer>
**File**: `<path>:<line>`
**Issue**: <description>
**Fix**: <specific recommendation>

### [High] <Finding title>
**Persona**: <which reviewer>
**File**: `<path>:<line>`
**Issue**: <description>
**Fix**: <specific recommendation>

### [Medium] <Finding title>
...

### [Nitpick] <Finding title>
...

## Statistics
| Severity | Count |
|----------|-------|
| Blocker  | <N>   |
| High     | <N>   |
| Medium   | <N>   |
| Nitpick  | <N>   |

## Verdict
- **Blockers**: <N> (must fix before merge)
- **Recommendation**: <APPROVE | REQUEST_CHANGES>
```

---

## Convention Compliance Check

PR 리뷰 시 `.hxsk/docs/CONVENTIONS.md` 기반으로 추가 검증:

**PR 범위 검증**:
- 변경 목적이 2개 이상 혼합되어 있지 않은가?
- 프로덕션 코드 변경이 500줄을 넘지 않는가?
- 이슈의 Done Criteria를 모두 충족하는가?

**리뷰 중 발견된 문제 처리**:
| 유형 | 처리 |
|------|------|
| 현재 PR의 직접적인 버그 | 현재 PR에서 수정 |
| 기존 코드 구조적 문제 | **새 이슈 등록** → 코멘트에 링크 |
| "이것도 개선하면 좋겠다" | **새 이슈 등록** → 현재 PR에서 하지 않음 |

범위 초과 발견 시 `[High]` severity로 보고하고 이슈 분리를 권장한다.

## HXSK Alignment

- **SPEC 검증**: 변경 사항이 `.hxsk/SPEC.md`의 must-haves를 충족하는지 확인
- **DECISIONS 참조**: 아키텍처 변경이 `.hxsk/DECISIONS.md`에 기록된 ADR과 일치하는지 확인
- **Impact 분석**: `analyze_code_impact`를 사용하여 변경 영향 범위 사전 파악

---

## Post-Review Actions

Review 결과에 따라:

```bash
# GitHub에 리뷰 코멘트 게시
gh pr review <PR> --comment --body "<review>"

# 변경 요청
gh pr review <PR> --request-changes --body "<review>"

# 승인
gh pr review <PR> --approve --body "<review>"
```

## Lessons-Learned 저장 (REQUEST_CHANGES 또는 [High]/[Blocker] 발견 시)

리뷰에서 발견된 패턴을 A/B/C/D/E로 분류하여 저장한다.

**카테고리 판단 기준:**
- A (doc-drift): docstring/plan 불일치, stale 경로, 주석 오류
- B (test-quality): mock-only 테스트, coverage 부족, resource close 누락
- C (state-sync): invariant 위반, timing 오류, semantic 불일치
- D (lifecycle): thread safety, cleanup 누락, fixture scope 문제
- E (compat): 미사용 param, dead weight, forward-compat dead code

**저장 명령 (각 패턴별):**

```bash
bash .hxsk/hooks/md-store-memory.sh \
  "Lesson {카테고리}: {패턴 제목}" \
  "증상: {구체적 코드/상황}
PR: #{N}
예방: {다음에 이 실수를 방지하려면}" \
  "lessons-learned,category-{A|B|C|D|E},pr-{N}" \
  "lessons-learned/{카테고리 디렉토리}"
```

APPROVE인 경우에도 [High] 이상 발견이 있었다면 저장.

## Scripts

(없음 — `gh pr diff`, `gh pr view` 등 에이전트 네이티브 도구로 직접 수행)

## Iron Laws
NO REVIEW WITHOUT CONTEXT LOADING FIRST
NO REVIEW WITHOUT 6-PERSONA EVALUATION FIRST
NO FINDING WITHOUT SEVERITY CLASSIFICATION FIRST
NO APPROVAL WITHOUT SPEC_ALIGNMENT CHECK FIRST
NO VERDICT WITHOUT SCOPE_VALIDATION FIRST
NO REQUEST_CHANGES WITHOUT LESSONS_LEARNED STORAGE FIRST
NO FIXING_OUT_OF_SCOPE_ISSUES_WITHOUT_NEW_ISSUE_CREATION FIRST
