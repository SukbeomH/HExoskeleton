# GSD Methodology for Gemini

> 상세 규칙은 프로젝트 루트의 CLAUDE.md를 참조하세요.

## Quick Reference

- `uv` only (never pip/poetry)
- SPEC.md FINALIZED 후에만 구현
- 매 태스크 후 STATE.md 업데이트
- 3회 연속 실패 → STATE.md에 상태 덤프 + fresh session
- 경험적 증거 기반 검증 필수 ("코드가 맞아 보인다"는 증거 아님)

## Key Files

| 파일 | 용도 |
|------|------|
| `CLAUDE.md` | 전체 프로젝트 규칙 (canonical source) |
| `.gsd/SPEC.md` | 구현 명세 |
| `.gsd/PLAN.md` | 실행 계획 |
| `.gsd/STATE.md` | 진행 상태 |
| `.claude/agents/` | Agent 정의 (14개) |
| `.claude/skills/` | Skill 정의 (16개) |
