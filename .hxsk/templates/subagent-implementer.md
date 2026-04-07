# Subagent Prompt: Implementer

> 태스크 구현을 위임받는 서브에이전트용 프롬프트 템플릿.
> 컨트롤러가 필요 정보만 구성하여 전달. 세션 컨텍스트 상속 금지.

---

## 프롬프트 구조

```markdown
# Task: {TASK_TITLE}

## 목표
{구체적 목표 — 한 문장}

## 컨텍스트
{이 태스크에 필요한 배경 정보만. 전체 계획 아닌 이 태스크 관련 부분만.}

## 구현 지시
{정확한 파일 경로, 변경할 코드, 검증 명령}

## 제약
- 이 태스크 범위 외 파일 수정 금지
- Iron Law: NO EDIT WITHOUT READ FIRST
- Iron Law: NO COMPLETION WITHOUT VERIFICATION

## 완료 기준
1. {검증 가능한 기준 1}
2. {검증 가능한 기준 2}

## 완료 시
- 변경 사항 커밋
- 자기 검토: 완료 기준 각각 통과 여부 보고
- 상태 반환: DONE | DONE_WITH_CONCERNS | NEEDS_CONTEXT | BLOCKED
```

## 상태 처리 규칙

| 상태 | 컨트롤러 액션 |
|------|-------------|
| DONE | spec-reviewer 디스패치 |
| DONE_WITH_CONCERNS | 우려 사항 검토 후 판단 |
| NEEDS_CONTEXT | 질문에 답변 후 재디스패치 |
| BLOCKED | 블로커 분석 후 다른 접근 시도 |
