# Self-Configure 배포 모델 전환 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 빌드-배포 모델을 폐기하고, 에이전트가 퍼블릭 GitHub 레포를 읽어 스스로 구성하는 self-configure 모델로 전환한다.

**Architecture:** 3-Phase 순차 전환(Add → Move → Remove). Phase 1에서 신규 파일을 추가하고 검증, Phase 2에서 소스 구조를 재배치하고 검증, Phase 3에서 빌드 인프라를 삭제한다. 각 Phase는 독립적으로 rollback 가능하다.

**Tech Stack:** Bash, Markdown — 외부 종속성 없음

---

## Phase 1: "Add" — 신규 구조 추가 (기존 유지)

### Task 1: INDEX.md 파일 생성 (Skills)

**Files:**
- Create: `.hxsk/skills/INDEX.md`

**Step 1: 스킬 목록 수집 후 INDEX.md 작성**

모든 `.hxsk/skills/*/SKILL.md`를 순회하여 frontmatter에서 name, description을 추출하고 인덱스 생성:

```markdown
# Skills Index

> 19개 스킬. 에이전트가 필요한 스킬만 선택적으로 fetch합니다.

| Skill | Description | Path |
|-------|-------------|------|
| arch-review | Validates architectural rules and ensures design quality | `skills/arch-review/SKILL.md` |
| bootstrap | Complete initial project setup | `skills/bootstrap/SKILL.md` |
...
(19개 전부 나열)
```

**Step 2: 검증**

Run: `test -f .hxsk/skills/INDEX.md && grep -c '|' .hxsk/skills/INDEX.md`
Expected: 22+ (헤더 + 구분선 + 19 스킬 + 1 헤더행)

**Step 3: Commit**

```bash
git add .hxsk/skills/INDEX.md
git commit -m "feat(self-configure): skills INDEX.md 생성"
```

---

### Task 2: INDEX.md 파일 생성 (Hooks, Agents)

**Files:**
- Create: `.hxsk/hooks/INDEX.md`
- Create: `.hxsk/agents/INDEX.md`

**Step 1: Hooks INDEX.md 작성**

```markdown
# Hooks Index

> 17개 훅 스크립트. Claude Code 전용 — 다른 에이전트는 AGENTS.md 규칙으로 대체.

| Hook | Event | Purpose | File |
|------|-------|---------|------|
| file-protect.py | PreToolUse (Edit/Write/Read) | 민감 파일 접근 차단 | `hooks/file-protect.py` |
| bash-guard.py | PreToolUse (Bash) | 파괴적 명령 차단 | `hooks/bash-guard.py` |
...
(17개 전부 나열)
```

**Step 2: Agents INDEX.md 작성**

```markdown
# Agents Index

> 17개 에이전트 정의. 스킬을 탑재하고 오케스트레이션을 수행합니다.

| Agent | Description | Model | File |
|-------|-------------|-------|------|
| executor | Executes HXSK plans with atomic commits | sonnet | `agents/executor.md` |
| planner | Creates executable phase plans | opus | `agents/planner.md` |
...
(17개 전부 나열)
```

**Step 3: 검증**

Run: `test -f .hxsk/hooks/INDEX.md && test -f .hxsk/agents/INDEX.md && echo OK`
Expected: `OK`

**Step 4: Commit**

```bash
git add .hxsk/hooks/INDEX.md .hxsk/agents/INDEX.md
git commit -m "feat(self-configure): hooks/agents INDEX.md 생성"
```

---

### Task 3: AGENTS.md 생성

**Files:**
- Create: `AGENTS.md`

**Step 1: 현재 CLAUDE.md에서 에이전트 비종속적 내용 추출하여 AGENTS.md 작성**

현재 CLAUDE.md를 읽고, Claude Code 특화 문구를 제거하여 범용 AGENTS.md를 작성:

- Project Overview → Claude Code 언급 제거
- Repository Layout → `.claude/` 대신 `.hxsk/` 구조
- Memory Protocol → `scripts/` 경로를 `.hxsk/hooks/`로
- Validation → 그대로
- Execution Constraints → Claude Code 전용 항목 제거
- Agent Boundaries → 그대로

**Step 2: 검증**

Run: `test -f AGENTS.md && grep -c 'Claude Code' AGENTS.md`
Expected: 파일 존재, Claude Code 언급 0회 (또는 호환성 설명에서만 최소)

**Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "feat(self-configure): AGENTS.md 범용 에이전트 지침 생성"
```

---

### Task 4: GEMINI.md 생성

**Files:**
- Create: `GEMINI.md`

**Step 1: AGENTS.md 참조 + Gemini CLI 특화 설정으로 GEMINI.md 작성**

```markdown
# GEMINI.md

This file provides guidance to Gemini CLI agents working with this repository.

See AGENTS.md for shared project instructions.

## Gemini CLI Specific

- **Skills**: `.hxsk/skills/{name}/SKILL.md` — `.agent/skills/{name}/SKILL.md`로 배치
- **Rules**: AGENTS.md의 Agent Boundaries 섹션 참조
- **Hooks**: Gemini CLI는 event hooks를 지원하지 않음. AGENTS.md 규칙으로 대체
- **Memory**: `.hxsk/hooks/md-store-memory.sh`, `.hxsk/hooks/md-recall-memory.sh` 사용
```

**Step 2: 검증**

Run: `test -f GEMINI.md && head -3 GEMINI.md`
Expected: 파일 존재, 첫 줄 `# GEMINI.md`

**Step 3: Commit**

```bash
git add GEMINI.md
git commit -m "feat(self-configure): GEMINI.md 생성"
```

---

### Task 5: Setup 프롬프트 생성

**Files:**
- Create: `prompts/setup.md`
- Create: `prompts/setup-claude.md`

**Step 1: 범용 setup 프롬프트 작성 (prompts/setup.md)**

설계 문서의 "Setup 프롬프트 설계" 섹션에 정의된 5-step 구성 프로세스를 마크다운으로 작성. 핵심:
- Step 1: llms.txt fetch
- Step 2: 에이전트 유형 판단 → 지침 파일 저장
- Step 3: .hxsk/ 문서 구조 생성
- Step 4: 스킬 설치 (선택)
- Step 5: 훅 설치 (Claude Code만, 선택)

raw.githubusercontent.com URL은 `{owner}/{repo}` 플레이스홀더 사용.

**Step 2: Claude Code 특화 프롬프트 작성 (prompts/setup-claude.md)**

Claude Code 전용 추가 사항:
- `.claude/settings.json` 훅 설정 생성
- `.hxsk/skills/` 심볼릭 링크 또는 직접 배치
- 플러그인이 아닌 네이티브 skills/hooks 구조 사용

**Step 3: 검증**

Run: `test -f prompts/setup.md && test -f prompts/setup-claude.md && echo OK`
Expected: `OK`

**Step 4: Commit**

```bash
git add prompts/setup.md prompts/setup-claude.md
git commit -m "feat(self-configure): setup 프롬프트 생성 (범용 + Claude Code)"
```

---

### Task 6: llms.txt 생성

**Files:**
- Create: `llms.txt`

**Step 1: 설계 문서의 llms.txt 구조에 따라 작성**

llms.txt 스펙 준수:
- H1: 프로젝트 이름 (필수)
- Blockquote: 프로젝트 요약
- H2 섹션: Setup, Agent Instructions, Skills, Hooks, Templates, Optional

모든 URL은 상대 경로 사용 (GitHub raw URL이 아닌 레포 내 경로).

**Step 2: 검증**

Run: `head -1 llms.txt`
Expected: `# HExoskeleton`

Run: `grep -c '## ' llms.txt`
Expected: 6 (Setup, Agent Instructions, Skills, Hooks, Templates, Optional)

**Step 3: Commit**

```bash
git add llms.txt
git commit -m "feat(self-configure): llms.txt 진입점 인덱스 생성"
```

---

### Task 7: Phase 1 통합 검증

**Files:**
- 없음 (검증만)

**Step 1: 신규 파일 존재 확인**

Run: `ls llms.txt AGENTS.md GEMINI.md prompts/setup.md prompts/setup-claude.md .hxsk/skills/INDEX.md .hxsk/hooks/INDEX.md .hxsk/agents/INDEX.md`
Expected: 8개 파일 모두 존재

**Step 2: 기존 빌드가 여전히 동작하는지 확인**

Run: `make build 2>&1 | grep -E 'SUCCESSFUL|FAIL'`
Expected: 3개 모두 `BUILD SUCCESSFUL`

**Step 3: llms.txt 내 링크 유효성 확인**

Run: `grep -oP '\(([^)]+)\)' llms.txt | tr -d '()' | while read f; do test -f "$f" && echo "OK: $f" || echo "MISSING: $f"; done`
Expected: 모든 파일 `OK`

---

## Phase 2: "Move" — 소스 구조 재배치

### Task 8: .hxsk/skills/ → .hxsk/skills/ 이동

**Files:**
- Move: `.hxsk/skills/*` → `.hxsk/skills/`
- Modify: `.gitignore` (`.hxsk/skills/` 추적 허용)

**Step 1: .gitignore에 추적 허용 추가**

`.hxsk/*` 섹션에 `!.hxsk/skills/` 추가.

**Step 2: 스킬 이동**

```bash
cp -r .hxsk/skills/* .hxsk/skills/
rm -rf .hxsk/skills/
```

**Step 3: 검증**

Run: `ls -d .hxsk/skills/executor .hxsk/skills/planner .hxsk/skills/dispatcher`
Expected: 3개 디렉토리 존재

Run: `test -d .claude/skills && echo "NOT REMOVED" || echo "REMOVED"`
Expected: `REMOVED`

**Step 4: Commit**

```bash
git add .hxsk/skills/ .gitignore
git rm -r .hxsk/skills/
git commit -m "refactor(self-configure): .hxsk/skills/ → .hxsk/skills/ 이동"
```

---

### Task 9: .hxsk/agents/ → .hxsk/agents/ 이동

**Files:**
- Move: `.hxsk/agents/*` → `.hxsk/agents/`
- Modify: `.gitignore` (`!.hxsk/agents/` 추가)

**Step 1: .gitignore에 추가**

`!.hxsk/agents/` 추가.

**Step 2: 에이전트 이동**

```bash
cp .hxsk/agents/*.md .hxsk/agents/
rm -rf .hxsk/agents/
```

**Step 3: 검증**

Run: `ls .hxsk/agents/executor.md .hxsk/agents/planner.md .hxsk/agents/dispatcher.md`
Expected: 3개 파일 존재

**Step 4: Commit**

```bash
git add .hxsk/agents/ .gitignore
git rm -r .hxsk/agents/
git commit -m "refactor(self-configure): .hxsk/agents/ → .hxsk/agents/ 이동"
```

---

### Task 10: .hxsk/hooks/ → .hxsk/hooks/ 이동 + settings.json 경로 갱신

**Files:**
- Move: `.hxsk/hooks/*` → `.hxsk/hooks/`
- Modify: `.claude/settings.json` (훅 경로 변경)
- Modify: `.gitignore` (`!.hxsk/hooks/` 추가)

**Step 1: .gitignore에 추가**

`!.hxsk/hooks/` 추가.

**Step 2: 훅 이동**

```bash
cp .hxsk/hooks/* .hxsk/hooks/
rm -rf .hxsk/hooks/
```

**Step 3: settings.json 훅 경로 갱신**

`.claude/settings.json`의 모든 훅 경로를 변경:
```
"$CLAUDE_PROJECT_DIR"/.hxsk/hooks/  →  "$CLAUDE_PROJECT_DIR"/.hxsk/hooks/
```

sed 사용:
```bash
sed -i '' 's|\.hxsk/hooks/|.hxsk/hooks/|g' .claude/settings.json
```

**Step 4: 검증**

Run: `grep -c '\.hxsk/hooks/' .claude/settings.json`
Expected: `0`

Run: `grep -c '\.hxsk/hooks/' .claude/settings.json`
Expected: 6+ (각 훅 참조)

Run: `ls .hxsk/hooks/session-start.sh .hxsk/hooks/file-protect.py`
Expected: 존재

**Step 5: Commit**

```bash
git add .hxsk/hooks/ .claude/settings.json .gitignore
git rm -r .hxsk/hooks/
git commit -m "refactor(self-configure): .hxsk/hooks/ → .hxsk/hooks/ 이동, settings.json 경로 갱신"
```

---

### Task 11: CLAUDE.md → AGENTS.md import 구조로 전환

**Files:**
- Modify: `CLAUDE.md`

**Step 1: CLAUDE.md를 AGENTS.md import + Claude Code 전용으로 축소**

CLAUDE.md를 다시 작성:
- `@AGENTS.md` import로 공통 지침 참조
- Claude Code 전용 내용만 유지: hook 경로, settings.json 참조, 문서 계층, Compaction Rules
- 120줄 한도 엄수

**Step 2: 검증**

Run: `wc -l CLAUDE.md`
Expected: ≤120줄

Run: `grep -c '@AGENTS.md' CLAUDE.md`
Expected: 1+

**Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "refactor(self-configure): CLAUDE.md → AGENTS.md import + Claude 전용으로 축소"
```

---

### Task 12: scripts/ 중복 스크립트 정리

**Files:**
- Modify: `scripts/_json_parse.sh`, `scripts/compact-context.sh`, `scripts/md-recall-memory.sh`, `scripts/md-store-memory.sh`, `scripts/organize-docs.sh`

**Step 1: canonical이 .hxsk/hooks/로 이동했으므로 scripts/의 5개 파일을 래퍼로 교체**

각 파일을 `.hxsk/hooks/`로 위임하는 래퍼로 교체:

```bash
#!/usr/bin/env bash
# Canonical: .hxsk/hooks/$(basename "$0")
exec "$(cd "$(dirname "$0")/../.hxsk/hooks" && pwd)/$(basename "$0")" "$@"
```

**Step 2: 검증**

Run: `bash scripts/md-recall-memory.sh --help 2>&1 | head -1`
Expected: 정상 출력 (래퍼가 canonical로 위임)

**Step 3: Commit**

```bash
git add scripts/_json_parse.sh scripts/compact-context.sh scripts/md-recall-memory.sh scripts/md-store-memory.sh scripts/organize-docs.sh
git commit -m "refactor(self-configure): scripts/ 중복 5개를 .hxsk/hooks/ 위임 래퍼로 교체"
```

---

### Task 13: 내부 경로 참조 일괄 갱신

**Files:**
- Modify: 다수 SKILL.md, agent .md, PATTERNS.md 내 경로 참조

**Step 1: `.hxsk/skills/` → `.hxsk/skills/` 참조 갱신**

```bash
grep -rl '\.hxsk/skills/' .hxsk/ CLAUDE.md AGENTS.md | while read f; do
  sed -i '' 's|\.hxsk/skills/|.hxsk/skills/|g' "$f"
done
```

**Step 2: `.hxsk/agents/` → `.hxsk/agents/` 참조 갱신**

```bash
grep -rl '\.hxsk/agents/' .hxsk/ CLAUDE.md AGENTS.md | while read f; do
  sed -i '' 's|\.hxsk/agents/|.hxsk/agents/|g' "$f"
done
```

**Step 3: `.hxsk/hooks/` → `.hxsk/hooks/` 참조 갱신 (settings.json 외)**

```bash
grep -rl '\.hxsk/hooks/' .hxsk/ CLAUDE.md AGENTS.md docs/ | while read f; do
  sed -i '' 's|\.hxsk/hooks/|.hxsk/hooks/|g' "$f"
done
```

**Step 4: 검증**

Run: `grep -r '\.hxsk/skills/\|\.hxsk/agents/\|\.hxsk/hooks/' .hxsk/ CLAUDE.md AGENTS.md docs/ 2>/dev/null | grep -v settings.json | wc -l`
Expected: `0`

**Step 5: Commit**

```bash
git add -A
git commit -m "refactor(self-configure): 내부 경로 참조 .claude/ → .hxsk/ 일괄 갱신"
```

---

### Task 14: Phase 2 통합 검증

**Files:**
- 없음 (검증만)

**Step 1: 디렉토리 구조 확인**

Run: `ls -d .hxsk/skills/executor .hxsk/agents/executor.md .hxsk/hooks/session-start.sh .claude/settings.json`
Expected: 모두 존재

Run: `test -d .claude/skills && echo "FAIL" || echo "OK: .claude/skills removed"`
Expected: `OK: .claude/skills removed`

**Step 2: .claude/settings.json 경로 검증**

Run: `grep '\.hxsk/hooks/' .claude/settings.json | wc -l`
Expected: 6+

**Step 3: setup 프롬프트 경로 유효성**

llms.txt 및 prompts/ 내 참조가 새 경로를 반영하는지 확인.

---

## Phase 3: "Remove" — 빌드 인프라 삭제

### Task 15: 빌드 스크립트 삭제

**Files:**
- Delete: `scripts/build-plugin.sh`
- Delete: `scripts/build-antigravity.sh`
- Delete: `scripts/build-opencode.sh`
- Delete: `scripts/build-common.sh`
- Delete: `scripts/convert-hooks-to-plugins.py`

**Step 1: 삭제**

```bash
git rm scripts/build-plugin.sh scripts/build-antigravity.sh scripts/build-opencode.sh scripts/build-common.sh scripts/convert-hooks-to-plugins.py
```

**Step 2: 검증**

Run: `ls scripts/build-*.sh 2>/dev/null | wc -l`
Expected: `0`

**Step 3: Commit**

```bash
git commit -m "feat(self-configure): 빌드 스크립트 5개 삭제 (~2,640줄)"
```

---

### Task 16: 릴리즈 인프라 삭제

**Files:**
- Delete: `release-please-config.json`
- Delete: `.release-please-manifest.json`
- Delete: `.github/workflows/release-plugin.yml`

**Step 1: 삭제**

```bash
git rm release-please-config.json .release-please-manifest.json .github/workflows/release-plugin.yml
```

**Step 2: Commit**

```bash
git commit -m "feat(self-configure): release-please + CI 워크플로우 삭제"
```

---

### Task 17: Makefile build 타겟 제거

**Files:**
- Modify: `Makefile`

**Step 1: build 관련 타겟 제거**

`build`, `build-plugin`, `build-antigravity`, `build-opencode`, `clean` 타겟을 삭제.
`setup`, `status`, `check-deps`, `install-deps`, `init-env`, `help` 타겟은 보존.

**Step 2: .PHONY 갱신**

build 관련 타겟을 .PHONY에서도 제거.

**Step 3: 검증**

Run: `make help 2>&1 | grep -c build`
Expected: `0`

Run: `make help 2>&1 | grep -c setup`
Expected: `1`

**Step 4: Commit**

```bash
git add Makefile
git commit -m "refactor(self-configure): Makefile에서 build 타겟 제거"
```

---

### Task 18: .gitignore 빌드 출력 항목 제거

**Files:**
- Modify: `.gitignore`

**Step 1: 빌드 출력 디렉토리 항목 제거**

```
# Build outputs (make build - generated in CI)  ← 이 주석 + 아래 3줄 삭제
hxsk-plugin/
antigravity-boilerplate/
opencode-boilerplate/
```

**Step 2: 검증**

Run: `grep -c 'hxsk-plugin\|antigravity-boilerplate\|opencode-boilerplate' .gitignore`
Expected: `0`

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "chore(self-configure): .gitignore 빌드 출력 항목 제거"
```

---

### Task 19: 문서 최종 갱신

**Files:**
- Modify: `.hxsk/ARCHITECTURE.md`
- Modify: `.hxsk/STACK.md`
- Modify: `.hxsk/STATE.md`
- Modify: `.hxsk/PATTERNS.md`

**Step 1: ARCHITECTURE.md — 빌드 시스템 → self-configure 아키텍처 반영**

- System Diagram 전면 교체 (빌드 파이프라인 → llms.txt + setup prompt 구조)
- Components 섹션: Build System 제거, Self-Configure System 추가
- Data Flow: 빌드 흐름 → self-configure 흐름

**Step 2: STACK.md — 빌드 관련 항목 제거**

- Build Targets 섹션 삭제
- Utility Scripts 카운트 갱신 (빌드 5개 제거)

**Step 3: STATE.md — 현재 상태 갱신**

**Step 4: PATTERNS.md — self-configure 패턴 추가**

`## Architecture` 섹션에:
```
- **Self-Configure 배포**: llms.txt + AGENTS.md + setup 프롬프트. 빌드 스크립트 없음, 레포 = 배포
```

**Step 5: Commit**

```bash
git add .hxsk/ARCHITECTURE.md .hxsk/STACK.md .hxsk/STATE.md .hxsk/PATTERNS.md
git commit -m "docs(self-configure): 문서 전면 갱신 — self-configure 아키텍처 반영"
```

---

### Task 20: End-to-End 검증

**Files:**
- 없음 (검증만)

**Step 1: 레포 구조 최종 확인**

Run: `ls llms.txt AGENTS.md GEMINI.md CLAUDE.md prompts/setup.md .hxsk/skills/INDEX.md .hxsk/hooks/INDEX.md .hxsk/agents/INDEX.md`
Expected: 8개 파일 존재

Run: `test -f scripts/build-plugin.sh && echo "FAIL" || echo "OK: build scripts removed"`
Expected: `OK`

**Step 2: 빌드 스크립트 잔존 확인**

Run: `ls scripts/build-*.sh 2>/dev/null`
Expected: 출력 없음

**Step 3: .claude/ 구조 확인**

Run: `ls .claude/`
Expected: `settings.json` 만 존재

**Step 4: llms.txt 링크 유효성**

Run: `grep -oP '\(([^)]+)\)' llms.txt | tr -d '()' | while read f; do test -e "$f" && echo "OK: $f" || echo "MISSING: $f"; done`
Expected: 모든 파일 OK

---

## 실행 요약

```
Phase 1 "Add" (Task 1-7):    신규 파일 8개 추가, 기존 유지
Phase 2 "Move" (Task 8-14):  .claude/ → .hxsk/ 이동, 경로 갱신
Phase 3 "Remove" (Task 15-20): 빌드 인프라 삭제, 문서 갱신

총 커밋: ~19개
삭제: ~2,640줄 + 설정 3개 + CI 1개
신규: 마크다운 8개
```

| Phase | 태스크 | Rollback |
|-------|--------|----------|
| 1 (Add) | T1-T7 | 신규 파일 삭제만 하면 됨 |
| 2 (Move) | T8-T14 | `git revert` 가능 |
| 3 (Remove) | T15-T20 | Phase 2 검증 통과 후에만 진행 |
