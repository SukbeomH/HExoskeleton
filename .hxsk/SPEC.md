# SPEC.md — Project Specification

> **Status**: `FINALIZED`
>
> **Planning Lock**: 이 스펙은 확정됨. 구조적 변경 시 별도 ADR 작성 필요.

## Vision

HExoskeleton은 Claude Code 네이티브 환경에 최적화된 AI 에이전틱 워크플로우 보일러플레이트다.
순수 bash + 마크다운만으로 A-Mem(파일 기반 에이전트 메모리), ReWOO(계획-실행 분리), Nemori(중복 방지) 연구 개념을 구현한다.
외부 종속성(Node.js, Python 패키지, Vector DB, MCP 서버) 없이 Claude Code CLI만으로 동작하며, Claude Code Plugin·Google Antigravity·OpenCode 세 가지 배포 형식으로 빌드된다.

## Goals

1. **외부 종속성 제로** — 순수 bash + 마크다운. 프로덕션 외부 패키지 의존 없음
2. **파일 기반 에이전트 메모리** — `.hxsk/memories/` 14개 타입, 2-hop 그래프 검색, 중복 방지
3. **Agent-Skill 래핑 구조** — Skill(How) + Agent(When/With What) 분리로 재사용성 극대화
4. **HXSK 워크플로우** — `SPEC → PLAN → EXECUTE → VERIFY` 사이클로 계획-실행 추적
5. **멀티 플랫폼 빌드** — Claude Code Plugin / Google Antigravity / OpenCode 동시 지원

## Non-Goals (Out of Scope)

- Vector DB 또는 외부 임베딩 서비스 연동
- 웹 UI 또는 REST API 제공
- Python/Node.js 런타임 의존 핵심 기능
- Claude Code 외 LLM 플랫폼 직접 지원 (빌드 타겟을 통한 간접 지원은 포함)
- 실시간 협업 / 멀티 유저 세션

## Constraints

- **기술**: bash ≥3.2 (macOS/Linux 호환), Python 3 (시스템 내장 훅 전용)
- **크기**: CLAUDE.md ≤120줄, SKILL.md Quick Reference ≤5줄, PATTERNS.md ≤2KB/20항목
- **경로 중립화**: `scripts/md-*.sh`는 심볼릭 링크, 빌드 시 `${CLAUDE_PLUGIN_ROOT}/scripts/` 치환
- **보안**: `.env`·시크릿 파일 읽기/커밋 금지, `--dangerously-skip-permissions` 사용 금지

## Success Criteria

- [x] 외부 종속성 없이 Claude Code CLI만으로 에이전트 워크플로우 실행
- [x] 14개 메모리 타입 + 2-hop 검색으로 세션 간 컨텍스트 유지
- [x] 16개 Agent + 18개 Skill (공유 스킬 2개 포함) 정의 완료
- [x] 3개 빌드 타겟(Plugin/Antigravity/OpenCode) 스크립트 작성
- [x] shellcheck 복잡도 CLEAN, 레이어 경계 PASS
- [ ] `.hxsk/SPEC.md` 및 `STACK.md` 완전 작성 (이 작업)
- [ ] release-please 멀티 패키지 설정 검토

## Technical Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| bash ≥3.2 호환 | Must-have | macOS 기본 bash 포함 |
| 메모리 2-hop 검색 | Must-have | `md-recall-memory.sh` hop 파라미터 |
| Nemori 중복 방지 | Must-have | 동일 title/slug 자동 스킵 |
| shellcheck CLEAN | Must-have | `make check` 통과 |
| 빌드 경로 중립화 | Must-have | CLAUDE_PLUGIN_ROOT 치환 |
| A-Mem contextual_description | Should-have | 200자 이하 자동 생성 |
| 빌드 타겟 3종 | Should-have | Plugin, Antigravity, OpenCode |
| release-please 자동 릴리즈 | Nice-to-have | hxsk-plugin 단일 패키지 |

---

*Last updated: 2026-03-06*
