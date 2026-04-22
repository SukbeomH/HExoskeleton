---
phase: 7
plan: 3
wave: 2
status: COMPLETED
completed_at: 2026-04-22
---

# Plan 7.3 실행 요약: setup.md UX 재구조화 — 필수/선택 분리 + 하네스 Tier

## 목표

DA-7("단계 수보다 필수/선택 불명확이 진입장벽") + DA-6("9개 하네스 Pareto 위반") 소수의견 반영.
신규 사용자의 핵심 경로를 3단계로 인지할 수 있도록 레이블을 추가하고,
멀티 하네스 설정에 Tier 구분을 도입.

## 완료된 태스크

### Task 1: setup.md 필수/선택 레이블 + 핵심 경로 안내 + symlink 폴백

커밋: `feat(7-3): setup.md 필수/선택 레이블 + 핵심 경로 안내 + symlink 폴백 추가`

변경 내용:
- Step 0 헤더 직후 "빠른 시작 (약 5분)" 핵심 경로 요약 박스 추가 (Step 1→4→6)
- 9개 Step 헤더에 [필수]/[선택] 레이블 추가:
  - `[필수]`: Step 1, Step 4, Step 6
  - `[선택]`: Step 2, Step 3, Step 5, Step 7, Step 8, Step 9
- Step 4 Claude Code 설치 bash 블록에 symlink 실패 시 `cp -r` 폴백 추가 (Windows 환경 대응)

### Task 2: Step 9 하네스 Tier 1/2/3 표 추가 (DA-6 반영)

커밋: `feat(7-3): Step 9 하네스 Tier 1/2/3 표 추가 (DA-6 반영)`

변경 내용:
- Step 9 섹션 상단에 Tier 표 추가:
  - Tier 1 (완전 지원): Claude Code, Cursor 1.7+, GitHub Copilot CLI
  - Tier 2 (부분 지원): Gemini CLI, Windsurf, OpenCode, OpenAI Codex CLI
  - Tier 3 (커뮤니티 기여): Aider / Continue / Antigravity
- "Tier 1만 설치해도 핵심 기능이 완전히 동작합니다" 안내 추가
- 기존 어댑터 설치 명령 테이블 유지 (수정 없음)

## 검증 결과

| 조건 | 결과 |
|------|------|
| `grep '\[필수\]'` → 3개 이상 | 11개 (통과) |
| `grep '\[선택\]'` → 6개 이상 | 20개 (통과) |
| `grep 'symlink 실패\|cp -r'` → 존재 | 존재 (통과) |
| `grep 'Tier 1'` → 존재 | 존재 (통과) |
| `check-reliability.sh` → ISSUE COUNT: 0 | ISSUE COUNT: 0 (통과) |

## 불변 조건 확인

- setup.md Step 0 CORRUPTED 분기: 유지됨 (수정 없음)
- setup.md U6 명시적 스테이징: 유지됨 (수정 없음)
- 기존 내용 재구조화/삭제: 없음 (레이블·안내·표만 추가)
