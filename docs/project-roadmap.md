# Project Roadmap

> HExoskeleton의 릴리스 히스토리와 향후 계획.
>
> 원본 로드맵: `.hxsk/ROADMAP.md` · 전체 CHANGELOG: `.hxsk/CHANGELOG.md`

## 1. Current Version: v5.7.0

**기준일**: 2026-05-06
**현재 라인**: v5.7.0 공개 문서 기준. v5.5.0의 하네스 독립 prune 위에 Phase 8 보안 강화, Phase 9 Progressive Disclosure, Phase 10 CSO 최적화, Phase 11 용어/메모리 정화, Codex/OpenCode 표면 정비, release lineage 정렬, active-state spine / Hermes / HITL 표면 정비가 누적된 상태.

### 현재 라인의 핵심 변경
- **하네스 독립 메모리 프룬** — cron/launchd 의존 없이 메모리 툴 호출 시 자연 발화 (sentinel mtime + mkdir atomic lock)
- **신뢰성 17건 수정** — YAML injection, race condition, stale lock, TYPE_DIR 자동 생성 등 핵심 결함 보강
- **보안 강화(Phase 8)** — bash-guard/file-protect/SHA256 필수화 등 P0/P1 반영
- **Progressive Disclosure(Phase 9)** — refactor 스킬 추가, 핵심 스킬 entry ≤200줄 정리

## 2. Release Timeline

### 2026-Q2 릴리스

| 버전 | 날짜 | 주제 | PR |
|------|------|------|-----|
| **v5.7.0** | 2026-05-04 | active-state spine, Hermes/HITL surface, local verification sync | — |
| **v5.6.1** | 2026-04-30 | 공개 version lineage 정렬, README/docs 현행화 | #172 |
| **v5.6.1** | 2026-04-30 | release lineage 재정렬 | #171 |
| **v5.6.x** | 2026-04-30 | 검증/정합성 하드닝 + Codex harness 지원 | #167, #169 |
| **v5.6.0** | 2026-04-24~28 | Phase 10/11: CSO 최적화, hook CWD 고정, ADR-006/007 용어·메모리 정화 표면 | #150, #160, #164 |
| **v5.5.0+** | 2026-04-23 | Phase 9: Progressive Disclosure + refactor 스킬 (skills 21→22, entry ≤200줄) | #144 |
| **v5.5.0+** | 2026-04-23 | Phase 8: 보안 강화 (bash-guard DESTRUCTIVE_FS, file-protect .secrets, grep option-injection, yaml_safe backslash, SHA256 필수) | — |
| **v5.5.0+** | 2026-04-22 | execution-summary + test 메모리 타입 + reason 세션 출력 | #138 |
| **v5.5.0+** | 2026-04-22 | Plan 6.1 신뢰성 패치 17건 수정 | #137 |
| **v5.5.0+** | 2026-04-22 | 하네스 비종속 신뢰성 + 1-liner 설치 개선 (Wave 1·2·3) | #140 |
| **v5.5.0** | 2026-04-16 | 하네스 독립 prune | #134 |
| v5.4.0 | 2026-04-15 | Git Forge + lessons-learned + 메모리 티어 | #131, #127, #133 |

### 2026-Q1 핵심 이정표

| 버전 | 주제 |
|------|------|
| v5.3.x | PATTERNS.md 경량화 |
| v5.2.x | doc-lint LINK-02 앵커 검증, prune-memories --dry-run |
| v5.1.x | Self-Configure 모델 안정화 |
| v5.0.0 | `.gsd/` → `.hxsk/` 대전환 |

## 3. Phase Milestones

### Phase 1: 안정화 (2026-Q1) ✅ 완료

**Goal**: 멀티 하네스 기능 완결성 + 기술 부채 해소

| Task | 상태 |
|------|------|
| hooks.json 경로 실증 검증 | ✅ done |
| Antigravity 훅 지원 여부 확인 | ✅ done |
| 빌드 통합 테스트 | ✅ done |
| ARCHITECTURE.md 컴포넌트 섹션 보완 | ✅ done |
| STACK.md manual-utility 분류 | ✅ done |

### Phase 2: 기능 확장 (2026-Q2) 🚧 진행 중

**Goal**: 멀티 에이전트 협업 + 메모리 고도화

| Task | 상태 | 우선순위 |
|------|------|---------|
| 메모리 age-based prune 티어 추가 | 📋 planned | medium |
| 메모리 2-hop 검색 성능 벤치마크 | 📋 planned | medium |
| spec-reviewer 2단계 리뷰 플로우를 기본 경로에 편입할지 결정 | 🧪 experimental | medium |
| define-term / glossary 용어 계층을 기본 운영 표면으로 승격할지 결정 | 🧪 experimental | medium |
| Antigravity Rules → 실행 가능 워크플로우 변환 연구 | 📋 planned | low |
| release-please 멀티 패키지 지원 검토 | 📋 planned | low |
| OpenCode TypeScript 플러그인 실동작 검증 | 📋 planned | medium |
| ✅ v5.4.0 Git Forge 통합 | ✅ done | — |
| ✅ v5.4.0 lessons-learned 5 카테고리 | ✅ done | — |
| ✅ v5.5.0 하네스 독립 prune | ✅ done | — |
| ✅ Plan 6.1 신뢰성 17건 수정 (YAML injection, race condition, stale lock, etc.) | ✅ done | #137 |
| ✅ execution-summary + test 메모리 타입 + reason 세션 출력 | ✅ done | #138 |
| ✅ Phase 7: 신뢰성 개선 + install.sh + hxsk-harness-sync.sh + [필수]/[선택] UX | ✅ done | #140 |
| ✅ Phase 8: 보안 강화 (STRIDE/OWASP 감사 + P0/P1/P2 수정) | ✅ done | — |
| ✅ Phase 9: Progressive Disclosure (refactor 스킬 + executor/planner/verifier/debugger 분할) | ✅ done | #144 |

### Phase 3: 배포 최적화 (2026-Q3) 📋 계획

**Goal**: 외부 사용자 온보딩 + 생태계

| Task | 상태 | 우선순위 |
|------|------|---------|
| 사용자 가이드 문서 보완 | 🚧 (이 docs/ 생성) | medium |
| CI 통합 테스트 자동화 | 📋 planned | medium |
| GitHub Marketplace 등록 준비 | 📋 planned | low |

### Phase 4: (미정)

방향 후보:
- 다국어(다른 프로그래밍 언어) 지원 확장 연구 (현재 archived)
- 분산 팀 협업 (`.hxsk/` 공유 레포지토리 모드)
- AI 모델 독립성 (Anthropic 외 LLM 프로토콜 확장)

## 4. Completed Major Milestones

### PR #138 (2026-04-22) — execution-summary + test 메모리 타입 + reason 세션 출력

- `.hxsk/memories/test/` 디렉토리 신규 추가 (테스트/검증용 확장 메모리 타입)
- execution-summary 메모리 타입 개선
- reason 세션 출력 기능 추가

### Plan 6.1 / PR #137 (2026-04-22) — 신뢰성 17건 수정

**17개 신뢰성 이슈 해결: YAML injection, race condition, stale lock, CLAUDE_PROJECT_DIR 검증, NO_MATCH 시그널, TYPE_DIR 자동 생성, 2-hop frontmatter 제약**

| 수정 영역 | 상세 |
|---------|------|
| YAML injection 방지 | `md-store-memory.sh`: `yaml_safe()` 함수 추가 |
| Race condition 방지 | `stop-context-save.sh`: atomic `mv` flag claim |
| Stale lock 감지 | `prune-tick.sh`: 300s 임계값 고아 락 제거 |
| CLAUDE_PROJECT_DIR 검증 | hooks + scripts: `.hxsk/` 존재 사전 확인 |
| NO_MATCH 시그널 | `md-recall-memory.sh`: 결과 없음 시 stderr `[NO_MATCH]` |
| TYPE_DIR 자동 생성 | `md-store-memory.sh`: 타입 디렉토리 자동 mkdir |
| 2-hop frontmatter 제약 | `md-recall-memory.sh`: related 파싱 frontmatter 범위 한정 |
| Config 소싱 보안 | `prune-memories.sh` + `prune-tick.sh`: owner + permissions 검증 |
| SPEC placeholder guard | `planner`: `{placeholder}` 패턴 감지 시 계획 거부 |
| ORPHAN 제외 확장 | `doc-lint.sh`: scenario/predict/.hxsk/docs/.hxsk/phases 추가 |
| 신뢰성 카운터 신규 | `check-reliability.sh`: 11-패턴 이슈 카운터 스크립트 |
| shebang 표준화 | `pre-compact-save.sh`: `#!/usr/bin/env bash` |
| ORPHAN 제외 확장(추가) | `doc-lint.sh`: `./scenario ./predict ./.hxsk/docs ./.hxsk/phases` |

### v5.4.0 (2026-04-15) — Git Forge + lessons-learned

**신규 — Git Forge 통합 작업 관리 (PR #131)**
- `GATES.md` — SPEC→PLAN→EXECUTE→VERIFY→DONE 단일 진실 원천
- `gate-check.sh` — PreToolUse/Stop 훅으로 게이트 조건 자동 집행
- `forge-detect.sh` — remote URL로 플랫폼 감지(GitHub/GitLab/Gitea/Forgejo) → gh/glab/tea CLI 추상화
- AGENTS.md에 게이트 규칙 섹션 추가 — opencode/Copilot/Antigravity 호환

**신규 — lessons-learned 체계 (PR #127)**
- `lessons-learned` 메모리 타입 — A/B/C/D/E 5개 카테고리
- `planner` — 계획 수립 전 lessons recall + `cross_phase_invariants` 체크리스트
- `executor` — invariants 로드 + deviation A-E 분류 자동 저장
- `create-pr` — Pre-PR Self-Check A-E 품질 점검

### v5.3.x — PATTERNS.md 경량화
- 2KB / 20 items 한계 강제
- `compact-context.sh` 자동 프룬

### v5.2.x — doc-lint 강화
- LINK-02 앵커 링크 유효성 검사 추가 (#126)
- `prune-memories.sh --dry-run` 옵션 (#125)

### v5.1.x — Self-Configure 안정화
- llms.txt 진입점 표준화
- `.hxsk/prompts/setup.md` 3분기 감지 (FRESH/VERIFY/UPGRADE)

### v5.0.0 — `.gsd/` → `.hxsk/` 대전환
- 명칭 변경: Get Shit Done → HExoskeleton
- 디렉토리 구조 전면 재편
- Self-Configure 모델 확립

## 5. Backwards Compatibility

### Breaking Changes 정책
- Major 버전 증가 시에만 허용
- `.hxsk/CHANGELOG.md`에 명시
- `setup.md` U 분기에 마이그레이션 스크립트 포함

### Deprecation 기간
- 기능 deprecated 선언 → 최소 1 minor 버전 유지 후 제거
- Research 아카이브: `superseded` 상태로 보존 (역사적 참조)

## 6. Contribution Areas

새 컨트리뷰터가 기여하기 좋은 영역:

### 🟢 Entry-Level
- **Doc lint 규칙 추가** — `doc-lint.sh`에 새 규칙 추가
- **템플릿 개선** — `.hxsk/templates/` 신규/개선
- **번역** — 한글 → 영문 문서 번역 (특히 이 `docs/`)
- **Example 시나리오** — `.hxsk/examples/` 확장

### 🟡 Intermediate
- **Harness adapter 추가** — 새 AI 하네스 지원
- **Skill 신규 작성** — 특정 도메인 워크플로우
- **Memory 시각화** — `.hxsk/memories/`를 시각화하는 뷰어

### 🔴 Advanced
- **Workflow 게이트 확장** — 새 게이트 정의 + 검증 스크립트
- **Dispatcher 개선** — Wave 병렬 스케줄링 최적화
- **A-Mem 2-hop 성능 개선** — grep 기반 → 인덱스 구조 검토

## 7. Research Pipeline

활발히 연구 중인 주제 (아직 결정 안 됨):

| 주제 | 목적 | 상태 |
|------|------|------|
| FTS5 + RRF 하이브리드 검색 | 메모리 검색 성능 | active 연구 |
| 컨텍스트 98% 압축 기법 | 장기 세션 지원 | active 연구 |
| RLM (Recursive Language Models) | Skill 재귀 구조 | active 연구 |
| Ontology for LLM Agents | 메모리/용어 taxonomy + type-relations 정리 | active |

전체: `.hxsk/research/INDEX.md`.

## 8. Out of Scope (명시적 미지원)

Non-goals로 설계된 항목. 단기에 변경 없음:

- ❌ Vector DB 연동 — grep 기반 철학 유지
- ❌ 웹 UI / REST API — CLI 네이티브 전용
- ❌ Python/Node.js 런타임 필수화 — bash 우선
- ❌ 실시간 협업 — 단일 사용자 × N 에이전트 패턴
- ❌ `--dangerously-skip-permissions` 허용

## 9. Upcoming Research Integrations

2026-Q3 논의 예정:
- **Karpathy autoresearch 통합** — 자동 revert 루프 + TSV iteration 로그 + Guard 이중 게이트 (`.hxsk/research/workflow/RESEARCH-autoresearch-methodology.md` 참조)
- **Superpowers 플러그인 분석 적용** — 8개 권장 항목 중 미적용 3개

## 10. Known Limitations (현재 버전)

솔직한 한계 (Karpathy의 "Honest Limitations" 원칙):

| 한계 | 완화 방안 | 미래 계획 |
|------|---------|----------|
| bash ≥3.2만 지원 (Windows native 불가) | WSL/Git Bash 사용 | 없음 (설계 의도) |
| grep 기반 검색 (의미 검색 없음) | keywords 필드 활용 | FTS5 연구 진행 |
| 단일 사용자 패턴 | — | 분산 모드 미계획 |
| AI 모델 독립성 낮음 | Claude 외 하네스 어댑터로 부분 해소 | 프로토콜 확장 연구 |
| 메모리 크기 확장성 | tier 분리 + 프룬 | 인덱스 구조 연구 |

## 11. Version Support Matrix

| HXSK 버전 | Claude Code | Gemini | Cursor | Copilot | Windsurf | OpenCode | Codex | Aider | Continue | Antigravity |
|----------|-------------|--------|--------|---------|----------|----------|-------|-------|----------|-------------|
| v5.7.x | ✅ | ✅ | ✅ 1.7+ | ✅ | ✅ | ✅ | ✅ | ✅ (git) | ✅ (git) | ✅ (git) |
| v5.6.x | ✅ | ✅ | ✅ 1.7+ | ✅ | ✅ | ✅ | ✅ | ✅ (git) | ✅ (git) | ✅ (git) |
| v5.5.x | ✅ | ✅ | ✅ 1.7+ | ✅ | ✅ | ✅ | ✅ | ✅ (git) | ✅ (git) | ✅ (git) |
| v5.4.x | ✅ | ✅ | ⚠️ 일부 | — | — | ⚠️ | — | — | — | — |
| v5.3.x | ✅ | ⚠️ | — | — | — | — | — | — | — | — |

✅ 공식 지원 · ⚠️ 실험적 · — 미지원

## 12. Feedback Channels

- **GitHub Issues**: https://github.com/SukbeomH/HExoskeleton/issues
- **Pull Requests**: 상세한 PR 설명 + 테스트 증거
- **Discussions**: 기능 제안, 사용 사례 공유

## See Also

- [Project Overview](project-overview-pdr.md) — 비전과 원리
- [Deployment Guide](deployment-guide.md) — 업그레이드 방법
- `.hxsk/ROADMAP.md` — 원본 로드맵
- `.hxsk/CHANGELOG.md` — 전체 릴리스 노트 (내부)
- `CHANGELOG.md` — 루트 릴리스 노트 (공개)
- `.hxsk/DECISIONS.md` — 아키텍처 결정 이력
