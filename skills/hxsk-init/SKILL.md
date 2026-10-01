---
name: hxsk-init
description: "Initializes HExoskeleton (HXSK) in the current project: creates the per-project .hxsk/ working state (SPEC, STATE, CURRENT, SESSION_HANDOFF, VERIFICATION, PATTERNS, memories/) from the plugin templates without overwriting existing files, and adds an HXSK pointer block to AGENTS.md. Use when setting up HXSK in a project, when .hxsk/ is missing, or to re-check the structure after an update (프로젝트 초기화, HXSK 설치, 셋업)."
allowed-tools:
- Read
- Edit
- Bash
---

## Quick Reference
- **실행**: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh" "${CLAUDE_PROJECT_DIR}"`
- **멱등**: 기존 파일은 절대 덮어쓰지 않음 — 재실행 안전 (`[NEW]` 생성 / `[OK]` 기존 유지)
- **업그레이드**: 플러그인은 `claude plugin update hxsk@hexoskeleton`, `.agents/skills` 복사본은 `init-project.sh --skills <project>` 재실행
- **opt-in**: `.hxsk/` 가 생긴 프로젝트에서만 HXSK 훅이 상태를 기록함

## Procedure

### Step 1: 스캐폴드 생성

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/init-project.sh" "${CLAUDE_PROJECT_DIR}"
```

- `${CLAUDE_PLUGIN_ROOT}` 가 치환되지 않는 환경(Codex, Copilot, Cursor, Antigravity, Devin, OpenCode 등)에서는
  HXSK 저장소 체크아웃에서 `scripts/init-project.sh --skills <project-dir>` 를 실행한다.
  `--skills` 는 스킬을 `<project>/.agents/skills/` 로 복사한다.
- 출력 줄이 모두 `[NEW]` / `[OK]` / `[SYNC]` 이면 성공. 비정상 종료 시 출력 전체를 보고하고 중단한다.

### Step 2: SPEC 작성

`.hxsk/SPEC.md` 는 `DRAFT` 상태의 템플릿이다. 사용자와 함께 Vision / Goals / Non-Goals / Constraints 를 채운다.
`FINALIZED` 전에는 계획·구현을 시작하지 않는다.

### Step 3: 코드베이스 분석 (기존 코드가 있을 때)

`codebase-mapper` 스킬로 `.hxsk/ARCHITECTURE.md`, `.hxsk/STACK.md` 를 생성한다. 실패해도 Step 4 로 진행하고 보고에 남긴다.

### Step 4: 초기화 기록

```bash
bash ../memory-protocol/scripts/md-store-memory.sh \
  "Project Init" \
  "HXSK initialized: .hxsk/ scaffold created, AGENTS.md pointer added." \
  "bootstrap,init,setup" \
  "bootstrap"
```

### Step 5: 보고

Step 1 출력, SPEC 상태(DRAFT/FINALIZED), codebase-mapper 결과를 요약한다.

## Iron Laws
- NO OVERWRITE OF EXISTING .hxsk/ FILES — 스크립트만 사용하고 수동 복사로 덮어쓰지 않는다
- NO PLANNING BEFORE SPEC IS FINALIZED
