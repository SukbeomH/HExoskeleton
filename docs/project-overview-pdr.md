# HExoskeleton (HXSK) — Project Overview & PDR

> **H**Exoskeleton: AI 에이전트를 위한 외골격 — 절제된 제약이 자율성을 만든다.
>
> Version 5.7.0 · Pure bash + markdown · Zero external dependencies

## 1. Problem Statement

현대 AI 코딩 에이전트(Claude Code, Gemini CLI, Copilot, Cursor, OpenCode, Antigravity 등)는 강력하지만 세 가지 고질적 문제를 공유한다:

1. **세션 간 기억 상실** — 매 세션이 제로 베이스. 지난주의 결정, 근본 원인, 패턴이 휘발.
2. **검증 없는 완료 선언** — "잘 되는 것 같다", "아마 동작할 것"이라는 자기 합리화가 실제 실패로 이어짐.
3. **플랫폼 락인 + 재발명** — 각 하네스가 자체 포맷을 요구 → 스킬·에이전트·훅을 중복 작성.

HXSK는 이 세 문제를 **단일 외부 의존성 없는 파일 기반 보일러플레이트**로 해결한다.

## 2. Vision

> "AI 에이전트가 팀원처럼 일하게 하려면, 팀원에게 주는 것을 똑같이 주라 — 공유 메모리, 일관된 워크플로우, 그리고 질문 대신 규율."

HXSK는 Claude Code 네이티브 환경에 최적화되었지만, Gemini·Copilot·Cursor·Windsurf·OpenCode·Codex·Hermes·Antigravity·Aider·Continue까지 10+ 하네스에서 동일한 `.hxsk/` 상태 디렉토리를 공유하도록 설계되었다. 플랫폼이 바뀌어도 에이전트의 "외골격"은 따라간다.

## 3. Core Principles (Why)

이 프로젝트는 세 가지 학술 연구의 실용적 구현체다. 이론적 배경은 @../.hxsk/research/memory-systems/ 참조.

| 원리 | 출처 | HXSK 구현 |
|------|------|----------|
| **A-Mem** (Agentic Memory) | 파일 기반 에이전트 메모리 연구 | `.hxsk/memories/` canonical 17 타입, 2-hop 검색, keywords+contextual_description+related 필드 |
| **ReWOO** (Reasoning Without Observation) | 계획-실행 분리 | `planner` skill(PLAN.md 생성) → `executor` skill(원자 실행) 분리 |
| **Nemori** (Self-Organizing Memory) | 중복 방지 + Predict-Calibrate | `md-store-memory.sh`에서 title/slug 기반 자동 dedup |

### 설계 철학 9원칙 (.hxsk/docs/DESIGN-PHILOSOPHY.md)

1. **Lazy Loading 계층** — L0 frontmatter(~50 tokens) → L1 policy(≤120 lines) → L2 procedure(≤1000 tokens) → L3 research(on-demand). SkillReducer 연구(2026): 48% 설명 압축 + 2.8% 품질 개선.
2. **Skill-Agent 분리** — Skill=How(100~300 lines), Agent=When/With What(~20 lines). 시스템 프롬프트 ~1,800 tokens 최적(Anthropic 내부).
3. **Claude Search Optimization (CSO)** — Skill description은 트리거 조건만 담는다. 워크플로우 요약 금지.
4. **Empirical Validation** — 모든 주장은 실행 결과로 증명. 자신감이 아닌 증거.
5. **Iron Laws** — 밝은 선 규칙 `NO X WITHOUT Y FIRST`. 권위 기반 규칙은 준수율 33%→72%(Meincke+ 2025, N=28,000).
6. **Prompt + Infrastructure Dual Defense** — 4 레이어: 정책(AGENTS.md, 항상 로드) + 절차(SKILL.md, 스킬 로드) + 훅(PreToolUse/Stop, thinking 독립) + CSO 라우팅.
7. **Anti-Rationalization Table** — 12 항목 룩업표로 거짓 완료 선언(5) + 건너뛴 읽기(4) + 파일 덮어쓰기(3) 차단. RLHF 아첨 편향(Sharma+ ICLR 2024) 대응.
8. **Convergent Bootstrap** — `bootstrap.sh`가 fresh/update/verify 어느 모드든 최종 상태 동일. 부분 구성 상태 없음.
9. **Multi-Agent Convergence** — 5+ 플랫폼이 동일한 `.hxsk/` 작업 상태(STATE.md, SPEC.md, PATTERNS.md, memories) 공유. 순수 마크다운으로 lock-in 차단.

## 4. Non-Goals (무엇을 하지 않는가)

의도된 제약은 가능성이다:

- ❌ Vector DB 또는 외부 임베딩 서비스 연동 — bash `grep`이 충분
- ❌ 웹 UI 또는 REST API — CLI 네이티브
- ❌ Python/Node.js 런타임 의존 핵심 기능 — bash + 시스템 Python 3만
- ❌ Claude Code 외 LLM 직접 지원 — 빌드 타겟을 통한 간접 지원만
- ❌ 실시간 협업 / 멀티 유저 세션 — 단일 개발자 × N 에이전트 패턴
- ❌ `--dangerously-skip-permissions` 허용 — 안전 우선

## 5. Architecture Snapshot

```
┌──────────────────────────────────────────────────────┐
│ User (단일 개발자)                                     │
└─────────────────┬────────────────────────────────────┘
                  │
     ┌────────────┴───────────┐
     │                        │
┌────▼────┐           ┌───────▼──────┐
│ Claude  │           │ Other Harness│
│  Code   │  10 harness│ (Gemini,     │
│         │  adapters │  Cursor, ...)│
└────┬────┘           └──────┬───────┘
     │                       │
     └───────┬───────────────┘
             │
    ┌────────▼─────────┐
    │   .hxsk/         │  공유 상태 디렉토리
    ├──────────────────┤
    │ skills/  (24)    │  How — 재사용 가능한 절차
    │ agents/  (18)    │  When/With What — 스킬 오케스트레이션
    │ hooks/   (27)    │  Event-driven 가드레일
    │ scripts/ (23)    │  유틸리티 (이슈/메모리/설치/검증)
    │ memories/        │  17 types × 2-hop search
    │ workflow/        │  GATES.md
    │ templates/       │  34 templates
    │ research/        │  L3 근거 자료
    └──────────────────┘
```

상세 다이어그램: @system-architecture.md.

## 6. Who Should Use HXSK

**적합**:
- ✅ Claude Code / Gemini / Cursor / Copilot 등 AI 코딩 에이전트로 작업하는 개발자
- ✅ 세션 간 컨텍스트 유지가 필요한 장기 프로젝트
- ✅ 여러 하네스를 옮겨다니거나 팀이 다른 도구를 쓰는 환경
- ✅ "외부 의존성 최소화"가 조직 정책인 경우

**부적합**:
- ❌ Bash를 쓸 수 없는 환경 (Windows 네이티브 없이)
- ❌ 강력한 Vector DB 의미 검색이 필수인 경우 (파일 grep 대신 FAISS·Pinecone 필요)
- ❌ 웹 대시보드/UI를 원하는 경우

## 7. Quick Start

설치:
```bash
git clone https://github.com/SukbeomH/HExoskeleton
cd HExoskeleton
make setup          # install-deps + init-env
make check-deps     # bash ≥3.2, git, gh(선택)
```

첫 세션 (Claude Code):
```bash
claude code         # 또는 Cursor/Gemini/Copilot 등
# SessionStart 훅이 .hxsk/CURRENT.md + STATE.md 자동 로드
```

기본 워크플로우:
1. `/skill bootstrap` — 환경 검증
2. `/skill planner` — SPEC.md → PLAN.md
3. `/skill executor` — PLAN.md → 원자적 커밋
4. `/skill verifier` — SPEC.md 충족 확인
5. `/skill create-pr` — PR 생성
6. `/skill handoff` — 세션 종료 및 메모리 저장

상세: @deployment-guide.md.

## 8. Versioning & Release

- **Current**: v5.7.0 (2026-05-04)
- **Scheme**: SemVer (Major.Minor.Patch)
- **Breaking changes**: `.hxsk/CHANGELOG.md`에 명시
- **Major milestones**: @project-roadmap.md

## 9. Documentation Map

| 수준 | 문서 | 용도 |
|------|------|------|
| L1 | `CLAUDE.md` / `AGENTS.md` / `GEMINI.md` | 하네스별 진입점. 트리거·제약 요약 (≤120 lines) |
| L2 | `.hxsk/skills/*/SKILL.md` | 스킬별 상세 절차 |
| L2 | `.hxsk/docs/*.md` | 주제별 심화 문서 (HOOKS.md, MEMORY.md 등) |
| L3 | `.hxsk/research/*/RESEARCH-*.md` | 학술적 근거, 외부 출처 |
| **이 docs/** | `docs/*.md` | **외부 리더(신규 컨트리뷰터, 통합 개발자)를 위한 공개 문서** |

## 10. License & Repository

- **Repo**: https://github.com/SukbeomH/HExoskeleton
- **License**: 리포 LICENSE 파일 참조
- **Issues**: GitHub Issues + `.hxsk/issues/*.md` 파일 기반 레지스트리 병행

## See Also

- [Codebase Summary](codebase-summary.md) — 파일 인벤토리와 의존성
- [System Architecture](system-architecture.md) — 컴포넌트 관계 + Mermaid 다이어그램
- [Code Standards](code-standards.md) — 컨벤션과 Iron Laws
- [Deployment Guide](deployment-guide.md) — 빌드/배포 타겟
- [Testing Guide](testing-guide.md) — 검증·lint·doc-lint
- [Configuration Guide](configuration-guide.md) — 설정 키 레퍼런스
- [Project Roadmap](project-roadmap.md) — 로드맵과 릴리스 히스토리
