# HXSK Setup

아래 지침에 따라 현재 프로젝트에 HExoskeleton(HXSK) 개발 방법론을 구성하세요.

## Step 0: 상태 감지

```bash
test -f .hxsk/.bootstrap-version && echo "UPDATE" || echo "FRESH"
```

- **FRESH** → 아래 "초기 설치" (Step 1~8)
- **UPDATE** → 아래 "업데이트"

---

## 초기 설치

### Step 1: 진입점 읽기

이 레포의 `llms.txt`를 읽어 사용 가능한 리소스 목록을 파악하세요.

### Step 2: 에이전트 지침 설정

당신의 에이전트 유형에 맞는 지침 파일을 프로젝트 루트에 저장하세요:

| 에이전트 | 파일 |
|----------|------|
| Claude Code | `CLAUDE.md` |
| Gemini CLI | `GEMINI.md` |
| 기타 (Copilot, Cursor, Windsurf 등) | `AGENTS.md` |

### Step 3: HXSK 문서 구조 생성

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

### Step 4: 스킬 설치

`.hxsk/skills/INDEX.md`를 참조하여 스킬을 가져오세요.

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
# .hxsk/skills/ 에서 .claude/skills/ 로 복사
for skill in bootstrap planner executor verifier memory-protocol; do
    mkdir -p .claude/skills/$skill
    cp .hxsk/skills/$skill/SKILL.md .claude/skills/$skill/SKILL.md
done
```

**Gemini CLI** → `.agent/skills/{name}/SKILL.md`에 배치
**기타** → 에이전트 문서에 따라 배치

> **주의**: `.hxsk/.bootstrap-version` 파일을 직접 생성하지 마세요. `bootstrap.sh`가 자동 생성합니다.

### Step 5: 에이전트별 자동 로드 경로 연결

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

### Step 6: 훅 설치 (Claude Code만)

> Claude Code가 아닌 에이전트는 이 단계를 건너뛰세요. AGENTS.md의 Agent Boundaries 규칙으로 대체됩니다.

`.hxsk/hooks/INDEX.md`에서 훅 스크립트를 가져와 `.claude/settings.json`에 등록:

```json
{
  "hooks": {
    "SessionStart": [{"matcher": "startup|resume", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/session-start.sh", "timeout": 10}]}],
    "PreToolUse": [
      {"matcher": "Edit|Write|Read", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/file-protect.py", "timeout": 5}]},
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/bash-guard.py", "timeout": 5}]}
    ]
  }
}
```

### Step 7: 메모리 시스템 확인 (Claude Code만)

> Claude Code가 아닌 에이전트는 이 단계를 건너뛰세요.

```bash
# 메모리 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그" "타입"

# 메모리 검색
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact
```

### Step 8: README에 뱃지 추가 (선택)

```markdown
[![HExoskeleton](https://img.shields.io/badge/assisted%20with-HExoskeleton-blueviolet?style=flat-square)](https://github.com/SukbeomH/HExoskeleton)
```

### 완료 확인

- [ ] 에이전트 지침 파일이 프로젝트 루트에 존재
- [ ] `.hxsk/` 디렉토리에 SPEC.md, STATE.md, PATTERNS.md 존재
- [ ] 필수 스킬 5개가 에이전트 설정 디렉토리에 배치됨 (bootstrap, planner, executor, verifier, memory-protocol)
- [ ] (선택) 에이전트별 심볼릭 링크 생성됨
- [ ] (Claude Code) 훅이 `.claude/settings.json`에 등록됨
- [ ] (Claude Code) 메모리 명령어 동작 확인

### 초기 설치 후 다음 단계

```
/bootstrap    # 프로젝트 분석 및 메모리 초기화 (← .bootstrap-version 자동 생성)
/planner      # SPEC 기반 실행 계획 수립
```

---

## 업데이트

이전 설치가 감지되었습니다.

### Step 1: bootstrap 실행

```bash
bash .hxsk/scripts/bootstrap.sh
```

출력 태그:
- `[OK]` — 변경 없음
- `[NEW]` — 새로 추가됨
- `[UPDATED]` — 변경됨 (↳ 관련: 2-hop 컨텍스트 표시)

### Step 2: 에이전트별 설정 갱신

`[NEW]` 또는 `[UPDATED]`가 있는 경우:
- 스킬 추가/변경 → 에이전트 스킬 디렉토리 갱신
- 에이전트 지침 변경 → CLAUDE.md/GEMINI.md/AGENTS.md 갱신

**Claude Code인 경우 추가로:**
- 훅 변경 → `.claude/settings.json` 갱신
- 스킬 변경 → `.claude/skills/{name}/SKILL.md` 복사

### Step 3: 확인

```bash
bash .hxsk/scripts/bootstrap.sh
```

모든 항목이 `[OK]`이면 업데이트 완료.
