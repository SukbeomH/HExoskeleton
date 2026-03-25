# HXSK Setup

아래 지침에 따라 현재 프로젝트에 HExoskeleton(HXSK) 개발 방법론을 구성하세요.

## Step 1: 진입점 읽기

이 레포의 `llms.txt`를 읽어 사용 가능한 리소스 목록을 파악하세요.

## Step 2: 에이전트 지침 설정

당신의 에이전트 유형에 맞는 지침 파일을 가져오세요:
- **Claude Code** → `CLAUDE.md`를 프로젝트 루트에 저장
- **Gemini CLI** → `GEMINI.md`를 프로젝트 루트에 저장
- **기타** (Copilot, Cursor, Windsurf 등) → `AGENTS.md`를 프로젝트 루트에 저장

## Step 3: HXSK 문서 구조 생성

프로젝트에 `.hxsk/` 디렉토리를 만들고 working docs를 생성하세요:

```
.hxsk/
├── SPEC.md       ← 프로젝트 명세 (필수)
├── STATE.md      ← 현재 상태 (필수)
├── PATTERNS.md   ← 학습된 패턴 (필수)
├── DECISIONS.md  ← 아키텍처 결정 기록
├── templates/    ← 문서 템플릿 (llms.txt Templates 섹션에서 fetch)
└── examples/     ← 사용 예시 (llms.txt Templates 섹션에서 fetch)
```

`templates/INDEX.md`를 참조하여 필요한 템플릿만 선택적으로 가져오세요.

## Step 4: 스킬 설치 (선택)

`skills/INDEX.md`를 참조하여 필요한 스킬만 가져오세요:
- **Claude Code** → `.claude/skills/{name}/SKILL.md`에 배치
- **Gemini CLI** → `.agent/skills/{name}/SKILL.md`에 배치
- **기타** → 에이전트 문서에 따라 배치

권장 필수 스킬: `planner`, `executor`, `verifier`, `memory-protocol`

## Step 5: 에이전트별 자동 로드 경로 연결

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

이렇게 하면 별도 옵션 없이 에이전트를 실행해도 HXSK 지침이 자동 로드됩니다.

## Step 6: 훅 설치 (Claude Code만, 선택)

훅은 Claude Code에서만 동작합니다. 다른 에이전트는 AGENTS.md의 Agent Boundaries 규칙으로 대체됩니다.

`hooks/INDEX.md`를 참조하여 필요한 훅을 가져오고 `.claude/settings.json`에 등록하세요.

## 완료 확인

- [ ] 에이전트 지침 파일이 프로젝트 루트에 존재
- [ ] `.hxsk/` 디렉토리에 SPEC.md, STATE.md, PATTERNS.md 존재
- [ ] (선택) 스킬이 에이전트 설정 디렉토리에 배치됨
- [ ] (선택) 에이전트별 심볼릭 링크 생성됨 (.cursorrules, .windsurfrules 등)
- [ ] (선택, Claude Code) 훅이 설치되고 settings.json에 등록됨

## Step 7: README에 뱃지 추가 (선택)

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
