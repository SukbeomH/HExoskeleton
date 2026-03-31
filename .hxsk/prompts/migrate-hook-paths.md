# HXSK Hook 경로 마이그레이션 (v5.0.0 → v5.0.1)

## 배경

v5.0.0까지 `.claude/settings.json`의 훅 command 경로가 `"$CLAUDE_PROJECT_DIR"/.hxsk/hooks/...` 형식이었습니다.
Claude Code 훅 러너가 이 환경변수를 확장하지 못하는 경우 `PreToolUse hook error`가 간헐적으로 발생합니다.

v5.0.1부터 상대 경로(`.hxsk/hooks/...`)로 변경되었습니다.

## 마이그레이션

### 자동 (권장)

아래 명령을 실행하세요:

```bash
# macOS
sed -i '' 's|"\\\"\$CLAUDE_PROJECT_DIR\\\"/.hxsk/hooks/|".hxsk/hooks/|g' .claude/settings.json

# Linux
sed -i 's|"\\\"\$CLAUDE_PROJECT_DIR\\\"/.hxsk/hooks/|".hxsk/hooks/|g' .claude/settings.json
```

### 수동

`.claude/settings.json`을 열고 모든 훅 command에서:

**Before:**
```json
"command": "\"$CLAUDE_PROJECT_DIR\"/.hxsk/hooks/session-start.sh"
```

**After:**
```json
"command": ".hxsk/hooks/session-start.sh"
```

### 확인

```bash
# 변환 완료 확인 (결과가 없으면 성공)
grep 'CLAUDE_PROJECT_DIR' .claude/settings.json

# 훅 경로 확인
grep '"command"' .claude/settings.json
```

## 영향 범위

- `.claude/settings.json`의 `command` 필드만 변경
- 훅 스크립트 내부는 변경 불필요 (이미 `${CLAUDE_PROJECT_DIR:-.}` fallback 사용 중)
- 훅 동작 로직 변경 없음
