# Build Guide

이 보일러플레이트를 다른 형식으로 빌드하는 방법입니다.

---

## 빌드 타겟

| 명령어 | 출력 | 용도 |
|--------|------|------|
| `make build-plugin` | `gsd-plugin/` | Claude Code 플러그인 |
| `make build-antigravity` | `antigravity-boilerplate/` | Google Antigravity IDE 워크스페이스 |
| `make build-opencode` | `opencode-boilerplate/` | OpenCode 워크스페이스 (모델 설정 지원) |

---

## 1. Claude Code Plugin 빌드

### 빌드 명령

```bash
make build-plugin
```

### 출력 구조

```
gsd-plugin/
├── .claude-plugin/
│   └── plugin.json          # 매니페스트 (name, version, description)
├── commands/                 # 31개 워크플로우 명령어
├── skills/                   # 15개 스킬
├── agents/                   # 13개 에이전트
├── hooks/
│   └── hooks.json           # 훅 설정 (경로 변환됨)
├── scripts/                  # 훅 스크립트
├── .mcp.json                # MCP 설정 (경로 변환됨)
├── templates/gsd/           # GSD 템플릿 + 예제
├── references/              # 인프라 레퍼런스 파일
└── README.md
```

### 빌드 과정

1. **디렉토리 생성**: 플러그인 구조 생성
2. **명령어 복사**: `.agent/workflows/*.md` → `commands/`
3. **스킬 복사**: `.claude/skills/` → `skills/`
4. **에이전트 복사**: `.claude/agents/` → `agents/`
5. **훅 변환**:
   - `settings.json` → `hooks/hooks.json`
   - 경로 변환: `$CLAUDE_PROJECT_DIR/.claude/hooks/` → `${CLAUDE_PLUGIN_ROOT}/scripts/`
6. **MCP 변환**:
   - `.mcp.json` → `.mcp.json`
   - args `.` → `${CLAUDE_PROJECT_DIR:-.}`
   - context7 제거 (API 키 필요)
7. **템플릿 복사**: `.gsd/templates/`, `.gsd/examples/`
8. **레퍼런스 복사**: `pyproject.toml`, `Makefile`, `.gitignore` 등
9. **검증**: 구조, 카운트, JSON 유효성

### 플러그인 사용

```bash
# 테스트
claude --plugin-dir ./gsd-plugin

# 글로벌 설치
cp -r gsd-plugin ~/.claude/plugins/gsd

# 명령어 확인
/gsd:help
```

### 자동 릴리즈

플러그인은 **release-please** 기반 GitHub Actions로 자동 릴리즈됩니다.

```
feat(gsd-plugin): 새 기능
    ↓
push to master
    ↓
Release PR 자동 생성
    ↓
PR 머지 → 자동 릴리즈
    ↓
gsd-plugin-v1.x.0 태그 + ZIP 첨부
```

---

## 2. Google Antigravity 빌드

### 빌드 명령

```bash
make build-antigravity
```

### 출력 구조

```
antigravity-boilerplate/
├── .agent/
│   ├── skills/              # 15개 스킬 (SKILL.md format)
│   │   ├── planner/
│   │   ├── executor/
│   │   └── ...
│   ├── workflows/           # 30개 워크플로우 (// turbo 지원)
│   │   ├── plan.md
│   │   ├── execute.md
│   │   └── ...
│   └── rules/               # 3개 패시브 규칙 (항상 적용)
│       ├── code-style.md    # Python/코드 스타일 규칙
│       ├── safety.md        # 안전 규칙 (금지/필수 사항)
│       └── gsd-workflow.md  # GSD 워크플로우 규칙
├── templates/gsd/           # GSD 템플릿 + 예제
├── scripts/
│   ├── scaffold-gsd.sh      # GSD 문서 초기화
│   ├── bash-guard.py        # Bash 명령 가드
│   └── file-protect.py      # 파일 보호
├── mcp-settings.json        # MCP 서버 설정 (Antigravity 표준)
└── README.md
```

### 빌드 과정

1. **디렉토리 생성**: `.agent/skills/`, `.agent/workflows/`, `.agent/rules/`
2. **스킬 마이그레이션**:
   - `.claude/skills/` → `.agent/skills/`
   - YAML frontmatter의 `description` 필드 검증
3. **워크플로우 복사**:
   - `.agent/workflows/` → `.agent/workflows/`
   - `description` 없으면 자동 추가
4. **규칙 생성**:
   - `CLAUDE.md`에서 규칙 추출
   - `code-style.md`: Python 표준, 패키지 관리, 코드 품질
   - `safety.md`: 금지 사항, 필수 사항, 터미널 안전
   - `gsd-workflow.md`: 검증 철학, GSD 사이클, MCP 우선순위
5. **MCP 변환**: `.mcp.json` → `mcp-settings.json` (Antigravity 표준)
6. **템플릿 복사**: `.gsd/templates/`, `.gsd/examples/`
7. **유틸리티 스크립트**: `scaffold-gsd.sh`, Python 훅
8. **검증**: 구조, 스킬 description, JSON 유효성

### Antigravity 주요 개념

| 컴포넌트 | 설명 | 트리거 |
|----------|------|--------|
| **Workflows** | 표준화된 작업 레시피 | `/` 슬래시 커맨드 또는 자연어 |
| **Rules** | 패시브 가이드라인 (항상 적용) | 자동 |
| **Skills** | 전문화된 에이전트 기능 | 에이전트가 자동 인식 |

### Turbo Mode

워크플로우에서 명령어 자동 실행:

```markdown
1. 테스트 실행
// turbo
2. `npm run test`
```

- `// turbo`: 해당 명령어만 자동 실행
- `// turbo-all`: 워크플로우 내 모든 명령어 자동 실행

### Antigravity 사용

**방법 1: 독립 워크스페이스**
```bash
# Antigravity IDE에서 열기
antigravity antigravity-boilerplate/

# MCP 설정 (옵션 A): Agent "..." → MCP Servers → View raw config
# mcp-settings.json 내용 추가

# MCP 설정 (옵션 B): 글로벌 설정
mkdir -p ~/.gemini/antigravity
cp mcp-settings.json ~/.gemini/antigravity/
```

**방법 2: 기존 프로젝트에 적용**
```bash
# .agent 디렉토리 복사
cp -r antigravity-boilerplate/.agent /path/to/project/

# MCP 설정 복사
cp antigravity-boilerplate/mcp-settings.json /path/to/project/
```

**방법 3: GSD 문서 초기화**
```bash
cd /path/to/project
zsh antigravity-boilerplate/scripts/scaffold-gsd.sh
```

---

## 3. OpenCode 빌드

### 빌드 명령

```bash
make build-opencode
```

### 출력 구조

```
opencode-boilerplate/
├── .opencode/
│   ├── agents/              # 13개 에이전트 (모델 설정 포함)
│   │   ├── planner.md       # model: anthropic/claude-opus-4-20250514
│   │   ├── executor.md      # model: anthropic/claude-sonnet-4-20250514
│   │   └── ...
│   ├── commands/            # 30개 워크플로우 명령어
│   ├── plugins/             # TypeScript 플러그인 (빈 디렉토리)
│   └── skill/               # 15개 스킬
├── templates/gsd/           # GSD 템플릿 + 예제
├── scripts/
│   ├── scaffold-gsd.sh      # GSD 문서 초기화
│   └── *.py                 # 유틸리티 스크립트
├── opencode.json            # 메인 설정 (에이전트별 모델 매핑)
├── AGENTS.md                # 프로젝트 규칙 (CLAUDE.md에서 복사)
├── .mcp.json                # MCP 서버 설정
└── README.md
```

### 빌드 과정

1. **디렉토리 생성**: `.opencode/agents/`, `.opencode/commands/`, `.opencode/skill/`
2. **에이전트 마이그레이션** (핵심 기능):
   - `.claude/agents/*.md` → `.opencode/agents/`
   - **모델 필드 변환**: `opus` → `anthropic/claude-opus-4-20250514`
   - **도구 필드 변환**: `["Read", "Write"]` → YAML map `read: true, write: true`
   - CRLF 줄바꿈 자동 처리
3. **스킬 복사**: `.claude/skills/` → `.opencode/skill/`
4. **워크플로우 복사**: `.agent/workflows/` → `.opencode/commands/`
5. **opencode.json 생성**: 에이전트별 모델 설정 포함
6. **MCP 변환**: `.mcp.json` → `.mcp.json`
7. **AGENTS.md 생성**: `CLAUDE.md`에서 복사
8. **템플릿 복사**: `.gsd/templates/`, `.gsd/examples/`
9. **유틸리티 스크립트**: `scaffold-gsd.sh`
10. **검증**: 구조, 모델 설정, JSON 유효성

### 모델 매핑

| 원본 (Claude Code) | 변환 (OpenCode) |
|-------------------|-----------------|
| `haiku` | `anthropic/claude-haiku-4-20250514` |
| `sonnet` | `anthropic/claude-sonnet-4-20250514` |
| `opus` | `anthropic/claude-opus-4-20250514` |
| `gemini` | `google/gemini-2.5-pro` |
| `gpt-4o` | `openai/gpt-4o` |

### 에이전트별 모델 분포

| 모델 | 에이전트 |
|------|----------|
| **opus** (5) | planner, debugger, arch-review, impact-analysis, pr-review |
| **sonnet** (4) | executor, codebase-mapper, plan-checker, verifier |
| **haiku** (4) | clean, commit, context-health-monitor, create-pr |

### 토큰 절약 설정

`opencode.json`에 포함된 토큰 최적화 설정:

```json
{
  "compaction": {
    "auto": true,
    "prune": true
  },
  "small_model": "anthropic/claude-haiku-4-20250514"
}
```

- `auto`: 컨텍스트 초과 시 자동 압축
- `prune`: 오래된 도구 출력 제거
- `small_model`: 제목 생성 등 경량 작업에 사용

### OpenCode 사용

```bash
# 프로젝트에 적용
cp -r opencode-boilerplate/.opencode /path/to/project/
cp opencode-boilerplate/opencode.json /path/to/project/
cp opencode-boilerplate/AGENTS.md /path/to/project/
cp opencode-boilerplate/.mcp.json /path/to/project/

# GSD 문서 초기화
bash opencode-boilerplate/scripts/scaffold-gsd.sh

# OpenCode 실행
cd /path/to/project && opencode
```

---

## Antigravity vs Claude Code 비교

### 디렉토리 매핑

| 보일러플레이트 | Claude Code Plugin | Antigravity |
|---------------|-------------------|-------------|
| `.claude/skills/` | `skills/` | `.agent/skills/` |
| `.agent/workflows/` | `commands/` | `.agent/workflows/` |
| `.claude/agents/` | `agents/` | (내부 시스템) |
| `.claude/hooks/` | `hooks/hooks.json` + `scripts/` | `.agent/rules/` |
| `CLAUDE.md` | (그대로) | `.agent/rules/*.md` |
| `.mcp.json` | `.mcp.json` | `mcp-settings.json` |

### 기능 차이

| 기능 | Claude Code Plugin | Antigravity |
|------|-------------------|-------------|
| **Skills** | 자동 호출 | Progressive Disclosure |
| **Agents** | 서브에이전트 | Agent Manager 통합 |
| **Hooks** | 이벤트 기반 | Rules로 대체 |
| **MCP** | settings.json | UI 기반 MCP Store |
| **워크플로우** | `/gsd:*` 명령어 | `/` 명령어 |

---

## 빌드 스크립트 상세

### scripts/build-plugin.sh

```bash
# 7단계 빌드 프로세스
Phase 1: 디렉토리 구조 + 매니페스트
Phase 2: 명령어 (워크플로우)
Phase 3: 스킬
Phase 4a: 에이전트
Phase 4b: 훅 (경로 변환)
Phase 4c: 훅 스크립트
Phase 5a: MCP 설정
Phase 5b: GSD 템플릿
Phase 5c: 인프라 레퍼런스
Phase 5d: 유틸리티 스크립트
Phase 6: 스캐폴딩 스크립트
Phase 7: 검증
```

### scripts/build-antigravity.sh

```bash
# 9단계 빌드 프로세스
Phase 1: 디렉토리 구조
Phase 2: 스킬 마이그레이션 (description 검증)
Phase 3: 워크플로우 (description 자동 추가)
Phase 4: 규칙 생성 (CLAUDE.md → rules/*.md)
Phase 5: MCP 설정
Phase 6: GSD 템플릿
Phase 7: 유틸리티 스크립트
Phase 8: README
Phase 9: 검증
```

---

## 환경 요구사항

### 공통

| 도구 | 용도 |
|------|------|
| **zsh** | 빌드 스크립트 실행 |
| **python3** | JSON 변환, 훅 스크립트 |

### Claude Code Plugin

| 도구 | 용도 |
|------|------|
| **Claude Code CLI** | 플러그인 테스트 (`claude --plugin-dir`) |
| **Node.js 18+** | code-graph-rag MCP |
| **pipx** | memorygraph 설치 |

### Antigravity

| 도구 | 용도 |
|------|------|
| **Google Antigravity IDE** | 워크스페이스 열기 |
| **Node.js 18+** | code-graph-rag MCP |
| **pipx** | memorygraph 설치 |

---

## 트러블슈팅

### 빌드 실패: permission denied

```bash
chmod +x scripts/build-plugin.sh scripts/build-antigravity.sh
```

### 빌드 실패: zsh not found

```bash
# macOS/Linux
brew install zsh  # 또는 apt install zsh
```

### 스킬 description 누락 경고

```bash
# SKILL.md 파일 확인
head -5 .claude/skills/*/SKILL.md

# 누락된 경우 추가
# ---
# name: skill-name
# description: "스킬 설명"  # 이 줄 필수
# ---
```

### MCP 서버 연결 실패 (Antigravity)

**옵션 1: 프로젝트 레벨**
1. Agent panel "..." → MCP Servers → Manage MCP Servers
2. "View raw config" 클릭
3. `mcp-settings.json` 내용 수동 추가
4. Antigravity 재시작

**옵션 2: 글로벌 설정**
```bash
mkdir -p ~/.gemini/antigravity
cp mcp-settings.json ~/.gemini/antigravity/
```

---

## 관련 문서

- [README - 플러그인 빌드](../README.md#gsd-plugin-빌드)
- [README - 자동 릴리즈](../README.md#gsd-plugin-자동-릴리즈)
- [GITHUB-WORKFLOW.md](./GITHUB-WORKFLOW.md) - CI/CD 파이프라인
- [.gsd/research/RESEARCH-google-antigravity-migration.md](../.gsd/research/RESEARCH-google-antigravity-migration.md) - Antigravity 리서치
