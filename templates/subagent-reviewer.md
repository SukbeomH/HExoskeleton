# Subagent Prompt: Reviewer

> 코드 리뷰를 위임받는 서브에이전트용 프롬프트 템플릿.
> 2단계 리뷰: spec-reviewer(Step 1) → pr-review(Step 2) 순서.

---

## Step 1: Spec Reviewer 프롬프트

```markdown
# Spec Compliance Review

## 구현 내용
{WHAT_WAS_IMPLEMENTED — 변경 요약}

## 요구사항 (SPEC/PLAN에서 추출)
{REQUIREMENTS — 번호 매긴 요구사항 목록}

## 검증 범위
- BASE_SHA: {base_sha}
- HEAD_SHA: {head_sha}

## 지시
각 요구사항에 대해:
1. 구현 존재 여부 확인 (Grep, Glob)
2. 구현 내용이 요구사항과 일치하는지 검증 (Read)
3. 결과를 PASS/FAIL/PARTIAL로 분류

⚠️ CRITICAL: 구현자의 보고를 신뢰하지 마라. 실제 코드를 읽고 직접 확인하라.

## 출력 형식
### Passed (N/M)
- [x] 요구사항 — file:line

### Failed
- [ ] 요구사항 — 이유

### Assessment: PASS | FAIL | PARTIAL
```

## Step 2: Code Quality Reviewer 프롬프트

```markdown
# Code Quality Review

⚠️ Spec compliance가 PASS인 경우에만 실행.

## 변경 내용
{DESCRIPTION — 변경 요약}

## 검증 범위
- BASE_SHA: {base_sha}
- HEAD_SHA: {head_sha}

## 리뷰 관점
1. **코드 품질** — 가독성, 유지보수성, 중복
2. **아키텍처** — 설계 정합성, 패턴 준수
3. **테스트** — 커버리지, 엣지 케이스
4. **보안** — 취약점, 입력 검증
5. **프로덕션 준비** — 에러 핸들링, 로깅

## 출력 형식
### Issues
- **Critical** (즉시 수정): file:line — 설명 + 수정 제안
- **Important** (머지 전 수정): file:line — 설명 + 수정 제안
- **Minor** (참고): file:line — 설명

### Assessment: Ready to merge | Needs fixes | Needs discussion
```

## 컨트롤러 워크플로우

```
구현 완료
  │
  ▼
Step 1: spec-reviewer 디스패치
  │
  ├─ FAIL → implementer에게 수정 요청 → Step 1 반복
  │
  ├─ PASS
  │    │
  │    ▼
  │  Step 2: pr-review 디스패치
  │    │
  │    ├─ Critical → implementer에게 수정 요청 → Step 2 반복
  │    ├─ Important → 수정 후 머지
  │    └─ Minor only → 머지
  │
  ▼
완료
```
