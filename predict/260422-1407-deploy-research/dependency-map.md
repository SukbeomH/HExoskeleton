---
commit_hash: 10f52791e66abef574dee28dd0d135e46e196394
---

## HXSK 배포 플로우

```
사용자
  ↓ (1) README.md / llms.txt 발견
AI 에이전트
  ↓ (2) setup.md 읽기
Step 0: 상태감지 (bash 스니펫)
  ├── FRESH → Step 1~9 (초기 설치)
  ├── VERIFY → 일상 확인
  ├── UPGRADE → U1~U6 (업그레이드)
  └── CORRUPTED → .bootstrap-version 수동 수정
        ↓
Step 4: 스킬/에이전트 심볼릭 링크
  .hxsk/skills/* → .claude/skills/*
  .hxsk/agents/* → .claude/agents/*
        ↓
Step 6: settings.json 훅 등록 (수동 JSON 편집)
        ↓
bootstrap.sh (수렴 엔진)
  ↓ 도구 검증 (bash, git, python3)
  ↓ .bootstrap-version 생성/갱신
완료
```

## autoresearch 배포 플로우

```
사용자
  ↓ (A) Claude Code Plugin Marketplace
/plugin marketplace add uditgoenka/autoresearch
  ↓ GitHub → marketplace.json 파싱
/plugin install autoresearch@autoresearch
  ↓ plugin.json → skills/ + commands/ 설치
Claude Code 재시작
  ↓ 자동 로드
완료 (2 명령)

  ↓ (B) scripts/install.sh
./scripts/install.sh  ← 인터랙티브 선택
  ├── --claude (--global / --local)
  ├── --opencode
  └── --codex
  ↓ 파일 복사 + 설정 병합
완료
```

## 하네스 호환성 체인 (HXSK)

```
Claude Code → hooks/INDEX.md → settings.json 수동 편집
Gemini CLI  → adapters/gemini-settings.json → ~/.gemini/settings.json 복사
Cursor      → adapters/cursor-hooks.json → .cursor/hooks.json 복사
Copilot     → adapters/copilot-hooks.json → .copilot/hooks.json 복사
Windsurf    → adapters/windsurf-hooks.json → .windsurf/hooks.json 복사
OpenCode    → adapters/opencode-plugin.ts → JS wrapper 수동 작성
Aider       → .hxsk/githooks/ → git config core.hooksPath
```

## 업데이트 플로우 비교

| | HXSK | autoresearch |
|-|------|--------------|
| 업데이트 감지 | .bootstrap-version 버전 비교 | /plugin marketplace update |
| 업데이트 실행 | setup.md UPGRADE 섹션 (U1~U6) | 자동 (플러그인 시스템) |
| 롤백 | git revert (수동) | 버전 고정 지원 (SHA 해시) |
| 버전 고정 | 불가 | 지원 (plugin.json version 필드) |

## 사용자 의존성 체인

```
HXSK 신규 사용자:
  (1) git clone
  (2) AI 에이전트에 setup.md 전달
  (3) bash 스니펫 직접 실행 (또는 에이전트 실행)
  (4) Step 4 bash 루프 승인
  (5) settings.json 수동 JSON 편집 ← 최대 마찰점
  (6) Claude Code 재시작
  총 예상 소요: 10~20분 (에이전트 숙련도에 따라 편차)

autoresearch 신규 사용자:
  (1) /plugin marketplace add uditgoenka/autoresearch
  (2) /plugin install autoresearch@autoresearch
  (3) Claude Code 재시작
  총 예상 소요: 2~3분
```
