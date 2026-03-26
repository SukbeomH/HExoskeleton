# Self-Configure 배포 모델 전환 설계

> Brainstorming 완료: 2026-03-24
> 상태: 설계 확정, 구현 대기
> 리서치: `.hxsk/research/2026-03-24-self-configure-distribution.md`

**Goal:** 빌드-배포(3개 빌드 스크립트 → ZIP → GitHub Release) 모델을 폐기하고, 에이전트가 퍼블릭 GitHub 레포를 읽어 스스로 구성하는 self-configure 모델로 전환한다.

---

## 의사결정 요약

| 항목 | 결정 |
|------|------|
| 주된 동기 | 사용자 진입 장벽 해소 (+ 유지보수, 범용성) |
| 진입 방식 | 프롬프트 복붙 또는 URL 전달 |
| 기존 플러그인 | **완전 폐기** — self-configure로 전환 |
| fetch 방식 | llms.txt 기반 선택적 fetch |
| 에이전트 범위 | AGENTS.md 표준 기반 범용 (60K+ 프로젝트 호환) |
| 파일 배치 | `.hxsk/` 공통 구조 + 에이전트별 진입점 |

---

## 아키텍처

```
현재 (빌드-배포):
  소스 → build-*.sh × 3 → ZIP × 3 → GitHub Release

전환 후 (self-configure):
  GitHub 레포 (= 배포)
  ├── llms.txt              ← 모든 에이전트 진입점
  ├── AGENTS.md             ← 범용 에이전트 지침 (single source of truth)
  ├── CLAUDE.md             ← Claude Code 전용 (@AGENTS.md import)
  ├── GEMINI.md             ← Gemini CLI 전용
  ├── .hxsk/                ← 공통 에셋
  │   ├── skills/           ← 에이전트 비종속적 스킬 (현 .claude/skills/)
  │   ├── hooks/            ← 훅 스크립트 (현 .claude/hooks/)
  │   ├── agents/           ← 에이전트 정의 (현 .claude/agents/)
  │   ├── templates/
  │   ├── examples/
  │   ├── issues/
  │   └── *INDEX.md         ← 각 디렉토리 인덱스 (llms.txt에서 참조)
  ├── prompts/
  │   ├── setup.md          ← 범용 setup 프롬프트
  │   └── setup-claude.md   ← Claude Code 특화 프롬프트
  ├── .claude/
  │   └── settings.json     ← Claude Code 훅 설정만 잔류
  └── scripts/              ← 유틸리티 (빌드 스크립트 제거됨)
```

---

## llms.txt 설계

```markdown
# HExoskeleton

> AI 에이전트 기반 개발 방법론. 순수 bash + 마크다운 기반, 외부 종속성 없음.
> 어떤 코딩 에이전트든 이 문서를 읽고 프로젝트에 HXSK를 구성할 수 있습니다.

## Setup
- [Setup Prompt (범용)](prompts/setup.md): 어떤 에이전트든 이 프롬프트를 실행하면 HXSK 구성 완료
- [Setup Prompt (Claude Code)](prompts/setup-claude.md): Claude Code 특화 구성

## Agent Instructions
- [AGENTS.md](AGENTS.md): 범용 에이전트 지침
- [CLAUDE.md](CLAUDE.md): Claude Code 지침
- [GEMINI.md](GEMINI.md): Gemini CLI 지침

## Skills
- [Skills Index](.hxsk/skills/INDEX.md): 19개 스킬 목록 + 설명

## Hooks
- [Hooks Index](.hxsk/hooks/INDEX.md): 17개 훅 스크립트 목록

## Templates
- [Templates Index](.hxsk/templates/INDEX.md): 24개 문서 템플릿

## Optional
- [Memory System](docs/MEMORY.md): 파일 기반 메모리 시스템 상세
- [Workflow Guide](docs/WORKFLOWS.md): SPEC→PLAN→EXECUTE→VERIFY
- [Full Documentation](docs/llms-full.txt): 전체 문서 통합본
```

---

## Setup 프롬프트 설계

`prompts/setup.md` — 에이전트가 실행하는 구성 지침:

1. llms.txt fetch → 리소스 목록 파악
2. 에이전트 유형 판단 → 적절한 지침 파일(CLAUDE.md/AGENTS.md/GEMINI.md) 저장
3. .hxsk/ 문서 구조 생성 (SPEC.md, STATE.md, PATTERNS.md 필수)
4. 스킬 설치 (선택) — INDEX.md에서 필요한 것만
5. 훅 설치 (Claude Code만, 선택)

**핵심:** 빌드 스크립트 2,400줄의 경로 변환/포맷 변환을 프롬프트가 에이전트에게 위임.

---

## AGENTS.md 설계

- AGENTS.md = single source of truth (에이전트 비종속적 공통 지침)
- CLAUDE.md = `@AGENTS.md` import + Claude Code 전용 설정
- GEMINI.md = AGENTS.md 참조 + Gemini CLI 전용 설정

AGENTS.md 내용: Project Overview, Repository Layout, HXSK Workflow, Memory Protocol, Validation, Agent Boundaries (현재 CLAUDE.md에서 추출, Claude Code 특화 문구 제거)

---

## 소스 재구조화

```
이동:
  .claude/skills/  → .hxsk/skills/
  .claude/agents/  → .hxsk/agents/
  .claude/hooks/   → .hxsk/hooks/

잔류:
  .claude/settings.json (훅 경로 → .hxsk/hooks/ 변경)

삭제 (~2,640줄 + 설정 3개 + CI 1개):
  scripts/build-plugin.sh
  scripts/build-antigravity.sh
  scripts/build-opencode.sh
  scripts/build-common.sh
  scripts/convert-hooks-to-plugins.py
  release-please-config.json
  .release-please-manifest.json
  .github/workflows/release-plugin.yml
  Makefile build 타겟

보존:
  scripts/issue-*.sh, merge-worktrees.sh, detect-language.sh, bootstrap.sh
  Makefile (setup, status, check-deps 타겟)

신규 (8개):
  llms.txt, AGENTS.md, GEMINI.md
  prompts/setup.md, prompts/setup-claude.md
  .hxsk/skills/INDEX.md, .hxsk/hooks/INDEX.md, .hxsk/agents/INDEX.md
```

---

## 마이그레이션 전략 (3단계)

### Phase 1: "Add" — 신규 구조 추가 (기존 유지)
- llms.txt, AGENTS.md, GEMINI.md, prompts/, INDEX.md 파일 생성
- 기존 .claude/, scripts/build-*.sh 그대로 유지
- 검증: setup 프롬프트로 빈 프로젝트에 HXSK 구성 테스트

### Phase 2: "Move" — 파일 이동 + 경로 갱신
- .claude/skills/ → .hxsk/skills/ 이동
- .claude/agents/ → .hxsk/agents/ 이동
- .claude/hooks/ → .hxsk/hooks/ 이동
- settings.json 훅 경로 갱신
- CLAUDE.md → AGENTS.md import + Claude 전용만 잔류
- 빌드 스크립트는 아직 유지 (rollback 안전망)
- 검증: make build 동작 확인

### Phase 3: "Remove" — 빌드 인프라 삭제
- build-*.sh, build-common.sh, convert-hooks-to-plugins.py 삭제
- release-please 설정, CI 워크플로우 삭제
- Makefile build 타겟 제거
- 마지막 플러그인 릴리즈를 "final" 태그
- 검증: setup 프롬프트 end-to-end 테스트

---

## 위험과 대응

| 위험 | 심각도 | 대응 |
|------|--------|------|
| 기존 플러그인 사용자 깨짐 | 높 | CHANGELOG 마이그레이션 가이드 + 마지막 "final" 릴리즈 |
| settings.json 경로 변경 실패 | 중 | Phase 2에서 검증 후 Phase 3 진행 |
| GitHub raw URL 가용성 | 낮 | llms.txt에 "오프라인: git clone" 안내 |
| AGENTS.md import 미지원 에이전트 | 중 | AGENTS.md를 self-contained 유지 |

---

## 성공 기준

1. 사용자가 프롬프트 하나로 빈 프로젝트에 HXSK 구성 완료 (5분 이내)
2. Claude Code, Gemini CLI, Cursor, Copilot 중 3개 이상에서 동작
3. 빌드 스크립트 2,400줄 + CI 워크플로우 삭제
4. 새 에이전트 지원 시 코드 변경 없이 AGENTS.md 수정만으로 가능
