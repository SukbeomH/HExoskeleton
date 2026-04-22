# Deployment Guide

> HExoskeleton 설치·업그레이드·검증 가이드. **Self-Configure 모델**이 핵심.
>
> 지원 하네스: Claude Code, Gemini CLI, Cursor, Windsurf, GitHub Copilot CLI, OpenCode, Codex CLI, Aider, Continue.dev, Antigravity

## 1. Deployment Philosophy: Self-Configure

HXSK는 **빌드 아티팩트를 배포하지 않는다**. 대신:

1. 사용자는 리포를 `git clone` 한다
2. 에이전트(어떤 하네스든)에게 `.hxsk/prompts/setup.md`을 실행시킨다
3. 에이전트가 **스스로** 환경을 수렴(converge)시킨다

이 모델의 장점:
- **Zero distribution infra** — npm 레지스트리, PyPI, Docker Hub 불필요
- **Self-updating** — `git pull` + setup 재실행으로 자동 업그레이드
- **Harness-agnostic** — Claude Code 없이도 동작 (Gemini/Cursor/...)
- **Audit trail** — 모든 변경은 git commit

> 과거 `build-plugin.sh`, `build-antigravity.sh`, `build-opencode.sh` 빌드 스크립트는 **superseded** 되었다. 상세: `.hxsk/research/deployment-strategy/RESEARCH-plugin-vs-safe-apply.md`.

## 2. Prerequisites

### 필수
- **Bash ≥3.2** (macOS 기본 bash 포함)
- **Git ≥2.x**
- **AI 코딩 에이전트** (하네스 — 10+ 지원)

### 선택 (기능별)
| 도구 | 필요한 경우 |
|------|------------|
| `gh` CLI | GitHub PR 생성 (create-pr skill) |
| `glab` CLI | GitLab 사용 시 |
| `tea` CLI | Gitea/Forgejo 사용 시 |
| `qlty` | 고급 lint (`make install-qlty`) |
| `node` | system-prompt 패치 (`make patch-prompt`) |
| `jq` | JSON 파싱 가속 (없으면 python3 폴백) |

## 3. Fresh Installation (첫 설치)

### Step 0: 리포 클론
```bash
git clone https://github.com/SukbeomH/HExoskeleton.git my-project
cd my-project
# 또는 기존 프로젝트에 .hxsk/만 복사해서 사용 가능
```

### Step 1: 에이전트에게 setup 지시

**Claude Code**:
```
(세션 시작 후)
@.hxsk/prompts/setup.md 를 읽고 실행해주세요.
```

**Gemini CLI / Cursor / Copilot / 기타**:
```
llms.txt → .hxsk/prompts/setup.md 순서로 읽고 실행
```

### Step 2: 감지 스크립트 실행 (자동)

setup.md의 Step 0이 3분기 분류를 자동 수행. **CORRUPTED 브랜치 감지**도 포함 — `git status` 실패 시 CORRUPTED로 분류하고 수동 복구를 안내한다.

```bash
TARGET_VERSION=5.5.0
CUR_VERSION=$(grep '^version:' .hxsk/.bootstrap-version 2>/dev/null | awk '{print $2}')
case "${CUR_VERSION:-}" in
    "")                echo "FRESH" ;;
    "$TARGET_VERSION") echo "VERIFY" ;;
    *)                 echo "UPGRADE"; echo "  from=$CUR_VERSION to=$TARGET_VERSION" ;;
esac
```

- **FRESH** → Step 1~9 (초기 설치 전체)
- **VERIFY** → 빠른 검증만
- **UPGRADE** → Step U1~U6 (마이그레이션)
- **CORRUPTED** → 수동 복구 필요 (setup.md 지시에 따라 처리)

### Step 3: 필수 스킬 설치

setup.md가 다음 스킬을 심볼릭 링크로 설치:

| 스킬 | 용도 |
|------|------|
| `bootstrap` | 환경 수렴 엔진 |
| `planner` | SPEC 기반 PLAN 작성 |
| `executor` | 원자 커밋 실행 |
| `verifier` | 경험적 검증 |
| `memory-protocol` | 메모리 저장/회상 |

**Claude Code 설치 패턴**:
```bash
mkdir -p .claude/skills .claude/agents
for skill_dir in .hxsk/skills/*/; do
    skill_name=$(basename "$skill_dir")
    ln -sfn "../../.hxsk/skills/$skill_name" ".claude/skills/$skill_name"
done
for agent in .hxsk/agents/*.md; do
    [[ "$(basename "$agent")" == "INDEX.md" ]] && continue
    ln -sf "../../.hxsk/agents/$(basename "$agent")" ".claude/agents/$(basename "$agent")"
done
```

**심볼릭 링크 사용 이유**: `.hxsk/` 수정이 `.claude/`에 즉시 반영 — 이중 유지보수 불필요.

### Step 4: 훅 등록 (Claude Code)

`.claude/settings.json`에 훅 바인딩:
```json
{
  "hooks": {
    "SessionStart": [{"command": "bash .hxsk/hooks/session-start.sh"}],
    "PostToolUse": [
      {"matchers": ["Edit", "Write"], "command": "bash .hxsk/hooks/track-modifications.sh"},
      {"matchers": ["Edit", "Write"], "command": "bash .hxsk/hooks/auto-format.sh"}
    ],
    "Stop": [{"command": "bash .hxsk/hooks/stop-context-save.sh"}],
    "PreCompact": [{"command": "bash .hxsk/hooks/pre-compact-save.sh"}],
    "SessionEnd": [{"command": "bash .hxsk/hooks/save-session-changes.sh"}]
  }
}
```

### Step 5: Makefile setup
```bash
make setup          # install-deps → init-env
make check-deps     # 도구 확인
make status         # 현재 상태
```

### Step 6: 첫 SPEC.md 작성
```bash
cp .hxsk/templates/spec.md .hxsk/SPEC.md
# 편집: Goals, Scope, Constraints, Success Criteria
```

## 4. Upgrade (기존 설치 → 최신)

### 4.1 자동 업그레이드 (권장)

setup.md Step 0에서 `UPGRADE` 분기로 진입하면 Step U1~U6 자동 실행:

1. **U1**: 버전 diff 분석 (`.hxsk/CHANGELOG.md` 참조)
2. **U2**: Breaking changes 감지
3. **U3**: 스킬/에이전트/훅 재동기화 (심볼릭 링크 재생성)
4. **U4**: 템플릿 업데이트 (사용자 작성 파일은 보존)
5. **U5**: `.bootstrap-version` 갱신
6. **U6**: 검증 (`verify-self-configure.sh`) — 명시적 git staging 사용 (`git add <file>`, `git add -A` 아님)

### 4.2 수동 업그레이드
```bash
git fetch origin
git pull --rebase
# Claude Code 세션에서:
@.hxsk/prompts/setup.md (U 분기 실행 지시)
```

### 4.3 주요 버전 마이그레이션
| From | To | 주요 변경 | 마이그레이션 |
|------|-----|---------|------------|
| v5.3.x | v5.4.0 | Git Forge + lessons-learned A-E + 메모리 티어 | 자동 |
| v5.4.x | v5.5.0 | 하네스 독립 prune + cap=5 + local-tier 전체 | `.hxsk/.prune-config` 새로 생성 |

## 5. Harness-Specific Installation

### 5.1 Claude Code (네이티브)
- `.claude/settings.json` 훅 등록 (위 Step 4)
- `.claude/skills/`, `.claude/agents/` 심볼릭 링크

### 5.2 Gemini CLI
```bash
cp .hxsk/adapters/gemini-settings.json ~/.config/gemini/settings.json
# GEMINI.md를 진입점으로 사용
```

### 5.3 Cursor 1.7+
```bash
# Cursor의 hooks 디렉토리 위치 확인 후:
cp .hxsk/adapters/cursor-hooks.json .cursor/hooks.json
```

### 5.4 GitHub Copilot CLI
```bash
cp .hxsk/adapters/copilot-hooks.json ~/.copilot/hooks.json
```

### 5.5 Windsurf (Cascade)
```bash
cp .hxsk/adapters/windsurf-hooks.json .windsurf/hooks.json
```

### 5.6 OpenCode
```bash
# JS 플러그인:
cp .hxsk/adapters/opencode-plugin.ts .opencode/plugins/hxsk.ts
```

### 5.7 OpenAI Codex
```bash
cp .hxsk/adapters/codex-hooks.json ~/.codex/hooks.json
```

### 5.8 Lifecycle 훅 미지원 하네스 (Aider / Continue / Antigravity)

Git hooks 폴백:
```bash
git config core.hooksPath .hxsk/githooks
# 이제 post-commit / post-merge가 자동으로 prune-tick.sh 호출
```

## 5.9 Completion Checklist (setup.md)

setup.md의 완료 체크리스트 각 항목에는 검증 명령이 포함되어 있다:

| 체크 항목 | 검증 명령 |
|----------|----------|
| CLAUDE.md / AGENTS.md 존재 | `ls CLAUDE.md AGENTS.md` |
| SPEC.md placeholder 없음 | `grep -c '{[A-Za-z]' .hxsk/SPEC.md` → 출력 0 |
| 메모리 디렉토리 생성 | `ls .hxsk/memories/` |
| 훅 바인딩 | `.claude/settings.json` 내 hooks 섹션 확인 |

**bootstrap.sh FAIL 동작**: FAIL 항목 발생 시 결과 블록 하단에 "다음 단계: `.hxsk/prompts/setup.md` 를 열어 FAIL 항목을 수동으로 수정하세요." 메시지를 출력한다.

**planner SPEC.md guard**: `planner` skill은 SPEC.md에 미해결 `{placeholder}` 패턴이 있으면 계획 생성을 거부한다. (`grep '{[A-Za-z]'` 패턴으로 감지)

## 6. Self-Configure 검증

### 6.1 verify-self-configure.sh
설치 후 검증:
```bash
bash .hxsk/scripts/verify-self-configure.sh
```

검증 항목:
- 훅이 Claude 설정에 등록되었는가
- 메모리 디렉토리(16 타입)가 존재하는가
- 버전 일관성 (llms.txt, .bootstrap-version, CHANGELOG)
- 심볼릭 링크가 정상 해결되는가
- 필수 스킬/에이전트가 모두 설치되었는가

### 6.2 수동 Smoke Test
```bash
# 1. 메모리 저장 동작
bash .hxsk/hooks/md-store-memory.sh general "test" "smoke test" --keywords test

# 2. 회상 동작
bash .hxsk/hooks/md-recall-memory.sh "smoke test" "." 3

# 3. 게이트 검증
bash .hxsk/hooks/gate-check.sh status

# 4. doc-lint
bash .hxsk/scripts/doc-lint.sh
```

## 7. Environment Variables

| 변수 | 기본값 | 용도 |
|------|-------|------|
| `CLAUDE_PROJECT_DIR` | (자동 주입) | 프로젝트 루트 — Claude Code가 세팅 |
| `CLAUDE_PLUGIN_ROOT` | (자동 주입) | 플러그인 루트 (플러그인 모드) |
| `HXSK_MEMORY_CAP` | 5 | local-tier 메모리 최대 개수 |
| `HXSK_PRUNE_COOLDOWN_SEC` | 60 | prune-tick 쿨다운 초 |
| `HXSK_FORGE_CMD` | 자동감지 | `gh` / `glab` / `tea` 강제 지정 |

`.env.example`을 `.env`로 복사 후 필요한 값 설정.

## 8. Uninstall

```bash
# 훅 바인딩 제거
rm .claude/settings.json   # 또는 hooks 섹션만 삭제

# 심볼릭 링크 제거
rm -rf .claude/skills .claude/agents

# HXSK 상태 완전 제거 (주의: 메모리 손실)
rm -rf .hxsk/
```

**주의**: `.hxsk/memories/shared/`에는 git 추적 장기 메모리가 있다. 제거 전 백업 고려.

## 9. CI/CD Integration

### 9.1 GitHub Actions 예시
```yaml
# .github/workflows/hxsk-check.yml
name: HXSK Consistency
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Doc Lint
        run: bash .hxsk/scripts/doc-lint.sh
      - name: Consistency Check
        run: bash .hxsk/hooks/check-consistency.sh
      - name: Pre-PR Validation
        run: bash .hxsk/hooks/pre-pr-check.sh
```

### 9.2 Pre-commit Hook
```bash
# .git/hooks/pre-commit (또는 core.hooksPath=.hxsk/githooks)
#!/usr/bin/env bash
bash .hxsk/hooks/pre-commit-doc-lint.sh && \
bash .hxsk/hooks/pre-commit-version-check.sh
```

## 10. Troubleshooting

| 증상 | 원인 | 해결 |
|------|------|------|
| `session-start.sh: command not found` | `CLAUDE_PROJECT_DIR` 미설정 | 훅 바인딩에 `bash` 명시 |
| 스킬이 `/command`로 안 보임 | 심볼릭 링크 누락 | Step 3 재실행 |
| 메모리 쌓임 (>100 files) | prune-tick 쿨다운 락 | `rm .hxsk/.prune-tick.lock` |
| `_json_parse.sh`: jq 없음 경고 | jq 미설치 | `brew install jq` 또는 python3 폴백 사용(무시 가능) |
| `.bootstrap-version` mismatch | UPGRADE 중단 | setup.md U 분기 재실행 |
| 빌드 스크립트 못 찾음 | Self-Configure로 전환됨 | build-* 참조는 무효 — setup.md 사용 |

## 11. Multi-Project Deployment

같은 조직에서 여러 프로젝트에 HXSK 배포 시:

### 전략 A: 각 프로젝트에 복사
```bash
for proj in ~/projects/*/; do
    cp -r hxsk-source/.hxsk "$proj/"
    # 각 프로젝트에서 setup 실행
done
```

### 전략 B: 중앙 HXSK + 심볼릭 링크
```bash
# 조직 공통 HXSK
export HXSK_ROOT=~/.hxsk-shared

# 각 프로젝트
ln -s $HXSK_ROOT/skills .hxsk/skills
ln -s $HXSK_ROOT/agents .hxsk/agents
# SPEC.md, STATE.md 등 프로젝트 고유 파일은 로컬
```

### 전략 C: Git submodule
```bash
git submodule add https://github.com/SukbeomH/HExoskeleton.git .hxsk-base
# .hxsk-base/의 skills/agents/hooks만 사용, 로컬 .hxsk/는 프로젝트 고유
```

## See Also

- [Configuration Guide](configuration-guide.md) — 모든 설정 키
- [Testing Guide](testing-guide.md) — 설치 후 검증
- `.hxsk/prompts/setup.md` — Self-Configure 스크립트
- `.hxsk/scripts/bootstrap.sh` — 수렴 엔진
- `.hxsk/scripts/verify-self-configure.sh` — 설치 검증
- `.hxsk/research/deployment-strategy/` — 왜 Self-Configure인가
