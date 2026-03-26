# HXSK Setup — Claude Code

Claude Code 전용 구성 가이드입니다. 범용 setup은 `.hxsk/prompts/setup.md`를 참조하세요.

## 상태 감지

먼저 설치 상태를 확인하세요:

```bash
test -f .hxsk/.bootstrap-version && echo "UPDATE" || echo "FRESH"
```

- **FRESH** → 아래 "초기 설치"를 따르세요
- **UPDATE** → 아래 "업데이트"를 따르세요

---

## 초기 설치

### Quick Setup

1. 이 레포의 `CLAUDE.md`를 프로젝트 루트에 저장
2. `.hxsk/` 디렉토리 생성 및 working docs 초기화
3. 필요한 스킬을 `.claude/skills/`에 배치
4. `.claude/settings.json`에 훅 설정

### 스킬 설치

`skills/INDEX.md`에서 필요한 스킬을 선택하여 `.claude/skills/{name}/SKILL.md`에 저장:

```bash
# 필수 스킬 (권장)
mkdir -p .claude/skills/{planner,executor,verifier,memory-protocol}
# 각 SKILL.md를 해당 디렉토리에 저장
```

### 훅 설치

`hooks/INDEX.md`에서 훅 스크립트를 가져와 `.hxsk/hooks/`에 저장하고 `.claude/settings.json`에 등록:

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

### 메모리 시스템

```bash
# 메모리 저장
bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그" "타입"

# 메모리 검색
bash .hxsk/hooks/md-recall-memory.sh "검색어" "." 5 compact
```

### README 뱃지

프로젝트 README에 HExoskeleton 뱃지를 추가하세요:

```markdown
[![HExoskeleton](https://img.shields.io/badge/assisted%20with-HExoskeleton-blueviolet?style=flat-square)](https://github.com/SukbeomH/HExoskeleton)
```

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

`[NEW]`/`[UPDATED]` 태그와 `↳ 관련:` 2-hop 컨텍스트를 확인하세요.

### Step 2: Claude Code 전용 갱신

`[NEW]` 또는 `[UPDATED]`가 있는 경우:

**스킬 갱신이 필요하면:**
```bash
# 새 스킬 또는 변경된 스킬을 .claude/skills/에 복사
cp .hxsk/skills/{name}/SKILL.md .claude/skills/{name}/SKILL.md
```

**훅 갱신이 필요하면:**
- `.hxsk/hooks/` 내 변경된 훅 확인
- `.claude/settings.json`에 새 훅 이벤트 등록 필요 여부 확인

**CLAUDE.md 갱신이 필요하면:**
- HExoskeleton 레포의 최신 `CLAUDE.md`와 프로젝트의 `CLAUDE.md` 비교
- 변경 사항 반영

### Step 3: 확인

```bash
bash .hxsk/scripts/bootstrap.sh
```

모든 항목이 `[OK]`이면 업데이트 완료.

### 업데이트 후 다음 단계

> **업데이트가 완료되었습니다. `[UPDATED]` 항목의 관련 컴포넌트를 확인하고 작업을 이어가세요.**
