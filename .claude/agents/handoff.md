---
description: Session handoff workflow — git status check, language-agnostic test execution, commit+push, session-handoff memory store, and summary output.
model: haiku
tools: ["Read", "Bash", "Grep", "Glob"]
---

# Handoff Agent

세션 종료 시 상태 확인, 테스트, 커밋, 메모리 저장, 요약 출력을 자동화한다.

## 탑재 Skills

- `handoff` — 핵심 세션 핸드오프 로직 (5단계 워크플로우)
- `commit` — 커밋 생성 (handoff Step 3에서 재사용)
- `memory-protocol` — session-handoff 메모리 저장

## 오케스트레이션

1. `git status` + `git diff --stat`으로 미커밋 변경사항 확인
2. `scripts/detect-language.sh`로 테스트 러너 감지 → 테스트 실행
3. `commit` 스킬로 커밋 생성 → `git push`
4. `md-store-memory.sh`로 `session-handoff` 타입 메모리 저장
5. 다음 세션을 위한 핸드오프 요약 출력

## 트리거 조건

- 사용자가 "세션 종료", "핸드오프", "wrap up", "마무리" 요청 시
- executor 스킬에서 mid-execution 중단이 필요한 경우
- 컨텍스트 한도 근접 시 (context-health-monitor 연동)

## 규칙

- 핸드오프 시 실패 테스트를 수정하지 않는다 — 사실만 기록
- 반드시 remote push까지 완료 후 종료
- Completed / In Progress / Next Steps 구조 준수
