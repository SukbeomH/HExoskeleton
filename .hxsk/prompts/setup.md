# HXSK Setup

> **Last aligned with: v5.5.0** — 이 파일은 릴리즈마다 갱신됩니다. `TARGET_VERSION` 값이 실제 타겟 버전과 다르면 상위 setup.md를 가져오세요.
>
> **지원 하네스**: Claude Code, Gemini CLI, Cursor, Windsurf, GitHub Copilot CLI, OpenCode, Codex CLI, Aider, Continue.dev, Antigravity
>
> **에이전트 하네스 주의**: 이 프롬프트의 bash 명령을 직접 실행할 수 없는 하네스(Continue.dev, Antigravity 일부, IDE 확장)는 **Step 0 하단 "Bash 실행 불가 폴백"** 섹션을 따르세요.

아래 지침에 따라 현재 프로젝트에 HExoskeleton(HXSK) 개발 방법론을 구성·유지하세요.

> **빠른 시작 (약 5분):** Step 1 → Step 4 → Step 6 만 완료하면 기본 동작합니다.
> 나머지(Step 2·3·5·7·8·9)는 필요에 따라 선택 적용하세요.

## Step 0: 상태 감지 (3분기)

```bash
TARGET_VERSION=5.5.0
VERSION_FILE=".hxsk/.bootstrap-version"
if [ ! -f "$VERSION_FILE" ]; then
    echo "FRESH"
elif ! grep -q '^version:' "$VERSION_FILE"; then
    echo "CORRUPTED"
else
    CUR_VERSION=$(grep '^version:' "$VERSION_FILE" | awk '{print $2}')
    case "$CUR_VERSION" in
        "$TARGET_VERSION") echo "VERIFY" ;;
        *)                 echo "UPGRADE"; echo "  from=$CUR_VERSION to=$TARGET_VERSION" ;;
    esac
fi
```

출력 첫 줄이 분기 토큰입니다. 분기별 이동:
- **`FRESH`** → "초기 설치" (Step 1~9)
- **`VERIFY`** → "일상 확인 (VERIFY)" 섹션
- **`UPGRADE`** → "업그레이드 (UPGRADE)" 섹션 (Step U1~U6, 두 번째 줄의 `from/to` 버전 활용)
- **`CORRUPTED`** → `.bootstrap-version` 파일이 손상됨. `cat .hxsk/.bootstrap-version`으로 확인. 정상 내용: `version: X.Y.Z`. 손상 시 `echo "version: X.Y.Z" > .hxsk/.bootstrap-version` 후 Step 0 재실행.

### Bash 실행 불가 폴백

이 세션에서 shell 명령을 직접 실행할 수 없는 경우(Continue.dev 등):

1. 사용자에게 터미널에서 위 감지 스니펫을 실행해 달라고 요청
2. 결과(`FRESH` / `VERIFY` / `UPGRADE`)를 대화에 붙여넣도록 안내
3. 이후 단계의 `bash` 명령도 동일 패턴으로 "사용자 수동 실행 → 결과 붙여넣기" 반복

---

## 초기 설치

### [필수] Step 1: 진입점 읽기

이 레포의 `llms.txt`를 읽어 사용 가능한 리소스 목록을 파악하세요.

### [선택] Step 2: 에이전트 지침 설정

당신의 에이전트 유형에 맞는 지침 파일을 프로젝트 루트에 저장하세요:

| 에이전트 | 파일 |
|----------|------|
| Claude Code | `CLAUDE.md` |
| Gemini CLI | `GEMINI.md` |
| 기타 (Copilot, Cursor, Windsurf 등) | `AGENTS.md` |

### [선택] Step 3: HXSK 문서 구조 생성

`.hxsk/` 디렉토리를 만들고 working docs를 생성하세요:

```
.hxsk/
├── SPEC.md       ← 프로젝트 명세 (필수)
├── STATE.md      ← 현재 상태 (필수)
├── PATTERNS.md   ← 학습된 패턴 (필수)
├── DECISIONS.md  ← 아키텍처 결정 기록
├── templates/    ← 문서 템플릿 (llms.txt에서 fetch)
└── examples/     ← 사용 예시
```

### [필수] Step 4: 스킬 및 에이전트 설치

`.hxsk/skills/INDEX.md`를 참조하여 스킬을, `.hxsk/agents/INDEX.md`를 참조하여 에이전트를 가져오세요.

**필수 스킬** (반드시 설치):

| 스킬 | 용도 |
|------|------|
| `bootstrap` | 프로젝트 초기화 + 업데이트 감지 |
| `planner` | SPEC 기반 실행 계획 수립 |
| `executor` | 계획 실행 (atomic commits) |
| `verifier` | 경험적 증거 기반 검증 |
| `memory-protocol` | 메모리 저장/검색 프로토콜 |

**Claude Code 설치 방법:**
```bash
# 스킬: .hxsk/skills/ → .claude/skills/ (심볼릭 링크 — 원본 수정 시 자동 반영)
mkdir -p .claude/skills
for skill_dir in .hxsk/skills/*/; do
    skill_name=$(basename "$skill_dir")
    if ! ln -sfn "../../.hxsk/skills/$skill_name" ".claude/skills/$skill_name" 2>/dev/null; then
        echo "[WARN] symlink 실패 — cp 폴백 사용 (Windows 환경)"
        cp -r ".hxsk/skills/$skill_name" ".claude/skills/$skill_name"
    fi
done

# 에이전트: .hxsk/agents/*.md → .claude/agents/ (INDEX.md 제외)
mkdir -p .claude/agents
for agent in .hxsk/agents/*.md; do
    [[ "$(basename "$agent")" == "INDEX.md" ]] && continue
    ln -sf "../../.hxsk/agents/$(basename "$agent")" ".claude/agents/$(basename "$agent")"
done
```

> 심볼릭 링크를 사용하므로 `.hxsk/`의 스킬/에이전트 수정이 `.claude/`에 즉시 반영됩니다.
> 모든 스킬이 `/skill-name` 슬래시 커맨드로 자동 등록됩니다.

**Gemini CLI** → `.agent/skills/{name}/SKILL.md`, `.agent/agents/{name}.md`에 배치
**기타** → 에이전트 문서에 따라 배치

> **주의**: `.hxsk/.bootstrap-version` 파일을 직접 생성하지 마세요. `bootstrap.sh`가 자동 생성합니다.

### [선택] Step 5: 에이전트별 자동 로드 경로 연결

`AGENTS.md`를 각 에이전트의 자동 로드 경로에 심볼릭 링크로 연결하세요:

```bash
# GitHub Copilot
mkdir -p .github
ln -sf ../AGENTS.md .github/copilot-instructions.md

# Cursor
ln -sf AGENTS.md .cursorrules

# Windsurf
ln -sf AGENTS.md .windsurfrules
```

### [필수] Step 6: 훅 설치 (Claude Code만)

> Claude Code가 아닌 에이전트는 이 단계를 건너뛰세요. AGENTS.md의 Agent Boundaries 규칙으로 대체됩니다.

`.hxsk/hooks/INDEX.md`에서 훅 스크립트를 가져와 `.claude/settings.json`에 등록:

```json
{
  "hooks": {
    "SessionStart": [
      {"matcher": "startup|resume", "hooks": [{"type": "command", "command": ".hxsk/hooks/session-start.sh", "timeout": 10}]}
    ],
    "PreToolUse": [
      {"matcher": "Edit|Write|Read", "hooks": [{"type": "command", "command": ".hxsk/hooks/file-protect.py", "timeout": 5}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": ".hxsk/hooks/bash-guard.py", "timeout": 5}]}
    ],
    "PostToolUse": [
      {"matcher": "Edit|Write", "hooks": [
        {"type": "command", "command": ".hxsk/hooks/auto-format.sh", "timeout": 30},
        {"type": "command", "command": ".hxsk/hooks/track-modifications.sh", "timeout": 2}
      ]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": ".hxsk/hooks/track-modifications.sh", "timeout": 2}]}
    ],
    "PreCompact": [
      {"matcher": "auto|manual", "hooks": [{"type": "command", "command": ".hxsk/hooks/pre-compact-save.sh", "timeout": 10}]}
    ],
    "Stop": [
      {"hooks": [
        {"type": "command", "command": ".hxsk/hooks/post-turn-verify.sh", "timeout": 15},
        {"type": "command", "command": ".hxsk/hooks/stop-context-save.sh", "timeout": 10}
      ]}
    ],
    "SubagentStop": [
      {"hooks": [{"type": "prompt", "prompt": "## SubagentStop\n- 핵심 결과 2-3문장 요약\n- 코드 변경 시: `touch .hxsk/.modified-this-session`\n- 재사용 패턴 발견 시: PATTERNS.md에 추가 검토\n- 스킬 본문을 결과에 복제하지 말 것"}]}
    ],
    "SessionEnd": [
      {"hooks": [
        {"type": "command", "command": ".hxsk/hooks/save-transcript.sh", "timeout": 10},
        {"type": "command", "command": ".hxsk/hooks/save-session-changes.sh", "timeout": 10}
      ]}
    ]
  }
}
```

### [선택] Step 7: 메모리 시스템 확인 (Claude Code만)

> Claude Code가 아닌 에이전트는 이 단계를 건너뛰세요.

```bash
# 메모리 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그" "타입"

# 메모리 검색
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact
```

### [선택] Step 8: README에 뱃지 추가 (선택)

```markdown
[![HExoskeleton](https://img.shields.io/badge/assisted%20with-HExoskeleton-blueviolet?style=flat-square)](https://github.com/SukbeomH/HExoskeleton)
```

### [선택] Step 9: Multi-Harness 활성화 (선택, v5.5.0+)

| Tier | 하네스 | 지원 수준 | 어댑터 |
|------|--------|-----------|--------|
| **Tier 1** | Claude Code | 완전 지원 (네이티브) | 내장 |
| **Tier 1** | Cursor 1.7+ | 완전 지원 | cursor-hooks.json |
| **Tier 1** | GitHub Copilot CLI | 완전 지원 | copilot-hooks.json |
| **Tier 2** | Gemini CLI | 부분 지원 | gemini-settings.json |
| **Tier 2** | Windsurf | 부분 지원 | windsurf-hooks.json |
| **Tier 2** | OpenCode | 부분 지원 (JS 래퍼 필요) | opencode-plugin.ts |
| **Tier 2** | OpenAI Codex CLI | 부분 지원 | codex-hooks.json |
| **Tier 3** | Aider / Continue / Antigravity | 커뮤니티 기여 | git 훅 폴백 |

> Tier 1만 설치해도 핵심 기능이 완전히 동작합니다.
> Tier 2·3는 필요 시 추가하세요.

Claude Code 외 다른 하네스를 함께 쓰는 경우, 각 하네스의 훅 시스템에 HXSK prune을 연결합니다. **부록 A** 참고.

기본 발화(opportunistic tick)는 하네스 무관하게 작동하므로 필수는 아닙니다 — `md-store-memory.sh`/`md-recall-memory.sh`/`bootstrap.sh`가 호출되면 자동 정리.

### 완료 확인

- [ ] 에이전트 지침 파일이 프로젝트 루트에 존재
  - 검증: `ls CLAUDE.md AGENTS.md 2>/dev/null && echo OK || echo MISSING`
- [ ] `.hxsk/` 디렉토리에 SPEC.md, STATE.md, PATTERNS.md 존재
  - 검증: `ls .hxsk/SPEC.md .hxsk/STATE.md .hxsk/PATTERNS.md 2>/dev/null && echo OK || echo MISSING`
- [ ] SPEC.md에 프로젝트 실제 내용 반영 (플레이스홀더 `{...}` 가 남아있으면 안 됨)
  - 검증: `grep -c '{[A-Za-z]' .hxsk/SPEC.md 2>/dev/null && echo "WARN: 미교체 플레이스홀더 있음" || echo OK`
- [ ] 필수 스킬 5개가 에이전트 설정 디렉토리에 배치됨 (bootstrap, planner, executor, verifier, memory-protocol)
  - 검증: `bash .hxsk/scripts/bootstrap.sh 2>&1 | tail -3`
- [ ] 에이전트 정의 파일이 에이전트 설정 디렉토리에 배치됨
  - 검증: `ls .hxsk/agents/*.md 2>/dev/null | wc -l`
- [ ] (선택) 에이전트별 심볼릭 링크 생성됨
- [ ] (Claude Code) 훅 **8개 이벤트** 모두 `.claude/settings.json`에 등록됨 (SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SubagentStop, SessionEnd)
  - 검증: `grep -c '"type": "command"' .claude/settings.json 2>/dev/null`
- [ ] (Claude Code) 메모리 명령어 동작 확인
  - 검증: `bash .hxsk/hooks/md-recall-memory.sh "memory" "." 3 compact 2>&1 | head -5`

### 초기 설치 후 다음 단계

```
/bootstrap    # 프로젝트 분석 및 메모리 초기화 (← .bootstrap-version 자동 생성)
/planner      # SPEC 기반 실행 계획 수립
```

---

## 업그레이드 (UPGRADE)

`$CUR_VERSION` → `$TARGET_VERSION` 프레임워크 동기화. 프로젝트 고유 파일(SPEC, STATE, CURRENT, PATTERNS, DECISIONS 등)과 애플리케이션 코드는 건드리지 않습니다. **부록 B**의 파일 경계 참조표를 반드시 숙지하세요.

### Step U1: 사전 감사 — 프레임워크 커스텀 수정/신규 파일 감지

```bash
FRAMEWORK_DIRS=(
    .hxsk/skills .hxsk/agents .hxsk/hooks .hxsk/scripts
    .hxsk/prompts .hxsk/templates .hxsk/docs
    .hxsk/workflow .hxsk/adapters .hxsk/githooks
)

# (1) 수정·삭제된 추적 파일
echo "-- modified --"
git diff HEAD --name-only -- "${FRAMEWORK_DIRS[@]}"

# (2) untracked(새로 추가된) 파일 — rsync --delete 가 조용히 지우는 범위
echo "-- untracked --"
git ls-files --others --exclude-standard -- "${FRAMEWORK_DIRS[@]}"
```

위 두 섹션 중 어디든 출력이 있으면 **프레임워크 파일에 로컬 수정/신규 파일 존재** — Step U3의 `rsync --delete`로 사라집니다 (untracked도 포함).

**결정 트리**:
1. 의도된 프로젝트 확장 → `.hxsk/skills-custom/`, `.hxsk/hooks-custom/` 같은 **프로젝트 고유 폴더로 이동** (sync 범위 외)
2. 프레임워크에 기여할 만한 개선 → 별도 PR로 상위 레포에 반영 후 신버전으로 받기
3. 단발성 실험 → `git stash` 또는 `git commit`으로 일단 보존 후 필요 시 cherry-pick

미결정 상태로 Step U2로 진행하지 마세요.

### Step U2: 소스 확보

HXSK 릴리즈 아카이브를 로컬 임시 경로로 획득. **아래 두 옵션 중 하나만 선택 실행**하세요 (둘 다 돌리면 경로 혼합).

공통 초기화:

```bash
# TMPDIR 폴백: /tmp 없는 환경(일부 컨테이너) 대응
HX_SRC="${TMPDIR:-/tmp}/hxsk-upgrade-$TARGET_VERSION"
rm -rf "$HX_SRC"   # 이전 시도 잔재 제거 (멱등)
```

**옵션 A — git clone** (네트워크/인증 여유 있음):

```bash
git clone --depth 1 -b setup-v$TARGET_VERSION \
    https://github.com/SukbeomH/HExoskeleton.git "$HX_SRC"
```

**옵션 B — Release tarball** (corp proxy, 오프라인 후속, 경량 환경):

```bash
mkdir -p "$HX_SRC"
curl -sL "https://github.com/SukbeomH/HExoskeleton/archive/refs/tags/setup-v$TARGET_VERSION.tar.gz" \
    | tar xz -C "$HX_SRC" --strip-components=1
```

성공 확인: `cat "$HX_SRC/.hxsk/.bootstrap-version"` 에 `version: $TARGET_VERSION` 표시.

**SHA256 검증 (선택 — 릴리스 노트에 체크섬이 제공된 경우)**:

```bash
# SHA256 검증 (선택 — 릴리스 노트에 체크섬이 제공된 경우)
# sha256sum -c <<< "EXPECTED_HASH  setup-v$TARGET_VERSION.tar.gz"
```

### Step U3: 프레임워크 동기화

```bash
TG="$(pwd)"

# 백업 (롤백 대비)
[[ -f "$TG/.claude/settings.json" ]] && \
    cp "$TG/.claude/settings.json" "$TG/.claude/settings.json.v$CUR_VERSION.bak"
cp "$TG/.hxsk/.bootstrap-version" "$TG/.hxsk/.bootstrap-version.v$CUR_VERSION.bak"

# 프레임워크 delete-and-sync (루프는 멱등 — 중단 시 같은 명령 재실행 안전)
for d in skills agents hooks scripts prompts templates docs workflow adapters githooks; do
    if command -v rsync >/dev/null; then
        rsync -a --delete "$HX_SRC/.hxsk/$d/" "$TG/.hxsk/$d/"
    else
        # rsync 없는 환경(Windows Git Bash, minimal container) 폴백
        rm -rf "$TG/.hxsk/$d" && cp -r "$HX_SRC/.hxsk/$d" "$TG/.hxsk/$d"
    fi
done

# 신규 memory tier (v5.4+ lessons-learned, 이후 버전도 동일 패턴)
mkdir -p "$TG/.hxsk/memories/lessons-learned"

# 메타 파일 교체
cp "$HX_SRC/.hxsk/.bootstrap-version" "$TG/.hxsk/.bootstrap-version"
```

**`.claude/settings.json` 교체 전 diff 확인** (프로젝트 커스텀 훅 보호). Claude Code를 사용하지 않는 프로젝트(Gemini CLI 전용 등)는 이 파일이 없을 수 있으므로 존재 여부로 분기:

```bash
if [[ -f "$TG/.claude/settings.json" && -f "$HX_SRC/.claude/settings.json" ]]; then
    diff "$TG/.claude/settings.json" "$HX_SRC/.claude/settings.json" | head -40
    # 차이가 경로·version 차이뿐이면 그대로 교체:
    #   cp "$HX_SRC/.claude/settings.json" "$TG/.claude/settings.json"
    # 프로젝트 고유 훅 블록(테스트 실행, 린터 등)이 있으면 수동 병합 후 사용자 확인 필수
elif [[ -f "$HX_SRC/.claude/settings.json" ]]; then
    # 대상에 settings.json 없음 → Claude Code 신규 도입이면 복사
    # mkdir -p "$TG/.claude" && cp "$HX_SRC/.claude/settings.json" "$TG/.claude/settings.json"
    echo "target has no .claude/settings.json — Claude Code 미사용 프로젝트면 건너뛰기"
fi
```

**롤백** (문제 발생 시):
```bash
# settings.json은 백업이 있을 때만 복원
[[ -f "$TG/.claude/settings.json.v$CUR_VERSION.bak" ]] && \
    cp "$TG/.claude/settings.json.v$CUR_VERSION.bak" "$TG/.claude/settings.json"
cp "$TG/.hxsk/.bootstrap-version.v$CUR_VERSION.bak" "$TG/.hxsk/.bootstrap-version"
# 프레임워크 파일은 git checkout HEAD -- .hxsk/{범주} 또는 HX_SRC에서 재sync
```

### Step U4: 검증 (4종)

```bash
bash .hxsk/scripts/bootstrap.sh                        # 구조 (PASS/FAIL/WARN)
bash .hxsk/hooks/check-consistency.sh                  # 정합성 (INDEX/경로/버전)
bash .hxsk/scripts/doc-lint.sh                         # 문서 링크
bash .hxsk/scripts/prune-memories.sh --auto --dry-run  # v5.5+ 모드 smoke
```

프로젝트 테스트 수트는 `CLAUDE.md` 또는 `AGENTS.md`의 **Project Context > Test** 블록 참조하여 실행 (pytest / npm test / cargo test / go test 등).

### Step U5: 사후 설정 (선택)

- **tier별 cap 커스터마이즈** — 공격적 정리 또는 특정 tier만 여유:
    ```bash
    cp .hxsk/templates/prune-config.sample .hxsk/.prune-config
    # 편집: PRUNE_DEFAULT_CAP=3 또는 PRUNE_CAP_session_summary=10 등
    ```
- **다른 하네스도 사용 중** → **부록 A**의 설치 명령 실행
- **Aider/Continue.dev/Antigravity 사용** → git 훅 폴백:
    ```bash
    git config core.hooksPath .hxsk/githooks
    ```

### Step U6: 커밋

```bash
# 백업 파일 제거 (검증 완료 후)
rm -f .claude/settings.json.v$CUR_VERSION.bak .hxsk/.bootstrap-version.v$CUR_VERSION.bak

# .env 등 프로젝트 파일 제외 — 프레임워크 파일만 명시적 스테이징
git add .hxsk/ CLAUDE.md AGENTS.md GEMINI.md .claude/settings.json 2>/dev/null || true
git commit -m "chore(hxsk): v$CUR_VERSION → v$TARGET_VERSION 프레임워크 동기화"
```

PR 생성 여부는 팀 컨벤션에 따라. 단일 저장소에서 직접 머지하거나 릴리즈 PR 생성 모두 가능.

---

## 일상 확인 (VERIFY)

버전이 동일한 경우의 정합성 체크.

### Step V1: bootstrap 실행

```bash
bash .hxsk/scripts/bootstrap.sh
```

출력 태그:
- `[OK]` — 변경 없음
- `[NEW]` — 새로 추가됨
- `[UPDATED]` — 변경됨 (↳ 관련: 2-hop 컨텍스트 표시)

### Step V2: 에이전트별 설정 동기화

`[NEW]` 또는 `[UPDATED]`가 있는 경우:
- 스킬 추가/변경 → 에이전트 스킬 디렉토리 갱신 (심볼릭 링크 환경이면 자동)
- 에이전트 지침 변경 → 루트 지침 파일은 건드리지 않음. `.hxsk/agents/*.md`만 갱신됨
- Claude Code: 훅 변경 시 `.claude/settings.json` 수동 병합

### Step V3: 재확인

```bash
bash .hxsk/scripts/bootstrap.sh
```

모든 항목이 `[OK]`이면 완료.

---

## 부록 A: Multi-Harness 활성화

기본 opportunistic tick은 하네스 무관하게 발화하지만, 각 하네스의 훅 시스템에 명시적 연결을 원하면 아래 어댑터 설치.

| 하네스 | 최소 버전 / 전제 | 설치 명령 | 공식 문서 |
|---|---|---|---|
| **Cursor** | 1.7+ (hooks.json 지원) | `mkdir -p .cursor && cp .hxsk/adapters/cursor-hooks.json .cursor/hooks.json` (기존 `hooks.json` 있으면 병합 필요) | [cursor.com/docs/hooks](https://cursor.com/docs/hooks) |
| **Gemini CLI** | 최신 | `mkdir -p .gemini && cp .hxsk/adapters/gemini-settings.json .gemini/settings.json` (프로젝트 우선, 글로벌은 `~/.gemini/`) | [geminicli.com/docs/hooks](https://geminicli.com/docs/hooks/) |
| **Copilot CLI** | 2026-02 GA+ | `mkdir -p .copilot && cp .hxsk/adapters/copilot-hooks.json .copilot/hooks.json` | [GitHub Docs](https://docs.github.com/en/copilot/how-tos/copilot-cli/use-hooks) |
| **Windsurf** | Cascade 활성 | `mkdir -p .windsurf && cp .hxsk/adapters/windsurf-hooks.json .windsurf/hooks.json` | [docs.windsurf.com/windsurf/cascade/hooks](https://docs.windsurf.com/windsurf/cascade/hooks) |
| **Codex CLI** | `codex_hooks=true` 활성 | `codex config set experimental.codex_hooks true && mkdir -p .codex && cp .hxsk/adapters/codex-hooks.json .codex/hooks.json` | [developers.openai.com/codex/hooks](https://developers.openai.com/codex/hooks) |
| **OpenCode** | Bun 런타임 필요 | `mkdir -p ~/.config/opencode/plugin && cp .hxsk/adapters/opencode-plugin.ts ~/.config/opencode/plugin/hxsk.ts` | [opencode.ai/docs/plugins](https://opencode.ai/docs/plugins/) |
| **Aider** | lifecycle 훅 부재 | `git config core.hooksPath .hxsk/githooks` | [aider.chat](https://aider.chat/) |
| **Continue.dev** | 동일 (VS Code 확장 제약) | 동일 | [docs.continue.dev](https://docs.continue.dev/) |
| **Antigravity** | 동일 | 동일 | [antigravity.google](https://antigravity.google/) |

### 버전 체크 (설치 전 권장)

```bash
# Cursor 1.7+ 확인
cursor --version 2>/dev/null | head -1

# Codex feature flag 확인
codex config get experimental.codex_hooks 2>/dev/null
```

미달 시 설치해도 훅이 무시됨 — 해당 하네스는 기본 opportunistic tick만 활용.

---

## 부록 B: 파일 경계 참조표

업그레이드 시 각 파일이 어떻게 다뤄지는지 정리. Step U3의 `rsync --delete` 대상을 명확히 파악하세요.

| 범주 | 경로 | sync 동작 | 사용자 수정 시 |
|---|---|---|---|
| **프레임워크 코어** | `.hxsk/{skills,agents,hooks,scripts,prompts,templates,docs,workflow,adapters,githooks}/` | `--delete` 완전 교체 | Step U1에서 감지 → 프로젝트 고유 폴더로 이동 또는 상위 PR |
| **프레임워크 메타** | `.hxsk/.bootstrap-version`, `.claude/settings.json` | 백업 후 교체 (settings.json은 diff 확인 후) | settings.json은 수동 병합 |
| **프로젝트 명세** | `.hxsk/{SPEC,STATE,CURRENT,PATTERNS,DECISIONS,ARCHITECTURE,STACK}.md` 및 프로젝트별 추가 문서 | 건드리지 않음 | 프로젝트 작업 산출물 — 자유롭게 유지 |
| **프로젝트 메모리** | `.hxsk/memories/*/*.md` | 내용 보존, 신규 tier 디렉터리만 `mkdir -p` | 그대로 유지 |
| **프로젝트 산출물** | `.hxsk/{issues,phases,reports,research,examples,archive}/` | 보존 | 그대로 유지 |
| **루트 지침** | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md`, `.cursorrules`, `.windsurfrules`, `llms.txt` (선택) | 건드리지 않음 (초기 설치 시만 생성) | Project Context 블록에 프로젝트 정보 기재 |
| **런타임 상태** | `.hxsk/{.track-modifications.log, .context-save.log, .last-prune-ts, .prune-lock/}`, `.hxsk/memories/*/*.bak` 등 | 건드리지 않음 (gitignore 대상) | 자동 생성/회전 |
| **사용자 설정** | `.hxsk/.prune-config`, `.hxsk/context-config.yaml` | 건드리지 않음 (있으면 보존) | 필요 시 템플릿에서 복사 생성 |

**주의**: 프레임워크 코어 범주에 프로젝트별 커스텀 스킬/훅을 직접 추가하면 업그레이드 시 사라집니다. 프로젝트 고유 확장은 `skills-custom/`, `hooks-custom/` 같은 범주 외 폴더에 두는 것을 권장.
