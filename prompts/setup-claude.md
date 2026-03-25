# HXSK Setup — Claude Code

Claude Code 전용 구성 가이드입니다. 범용 setup은 `prompts/setup.md`를 참조하세요.

## Quick Setup

1. 이 레포의 `CLAUDE.md`를 프로젝트 루트에 저장
2. `.hxsk/` 디렉토리 생성 및 working docs 초기화
3. 필요한 스킬을 `.claude/skills/`에 배치
4. `.claude/settings.json`에 훅 설정

## 상세 구성

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

## 다음 단계

설정이 완료되면 사용자에게 다음 메시지를 보내도록 안내하세요:

> **"HXSK 초기 설정이 완료되었습니다. 아래 명령어로 워크플로우를 시작하세요."**
>
> ```
> /bootstrap    # 프로젝트 분석 및 메모리 초기화
> /planner      # SPEC 기반 실행 계획 수립
> ```
