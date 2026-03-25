# Google Antigravity IDE 적용 리서치

**작성일**: 2026-01-29
**수정일**: 2026-01-29 (공식 문서 내용 반영)
**목적**: 현재 boilerplate 프로젝트를 Google Antigravity IDE에 완벽하게 적용하기 위한 방안 분석
**상태**: ✅ 리서치 완료

---

## 1. Google Antigravity 개요

### 1.1 핵심 개념

Google Antigravity는 2025년 11월 Gemini 3와 함께 발표된 **에이전트-우선(Agent-First) 개발 플랫폼**입니다. 기존 자동완성 도구와 달리, 자율 AI 에이전트가 계획(Plan) → 실행(Execute) → 검증(Verify)을 독립적으로 수행합니다.

**핵심 철학**: "개발자는 타이피스트에서 아키텍트로" - AI 에이전트가 구현 세부사항을 처리하고 개발자는 아키텍처 결정에 집중

### 1.2 기술 스택

| 구성요소 | 설명 |
|---------|------|
| **기반** | VS Code 포크 (Windsurf 팀 인수) |
| **AI 모델** | Gemini 3 Pro/Flash, Claude Sonnet 4.5, GPT-OSS-120B |
| **전송 프로토콜** | MCP (Model Context Protocol) |
| **작업 영역** | 에디터 + 터미널 + 브라우저 (3-Surface Architecture) |

### 1.3 핵심 기능

- **Agent Manager**: 작업 상태, 진행률, 추론 과정 표시
- **Artifacts System**: 계획서, 스크린샷, diff, 테스트 결과 등 검증 가능한 산출물
- **Browser Subagent**: DOM 조작, 클릭/타이핑, E2E 테스트 자동화
- **Multi-Agent 병렬 실행**: 코드 작성/테스트/문서화 동시 진행

### 1.4 에이전트 모드 (공식 문서 기반)

Antigravity는 대화 수준에서 두 가지 주요 모드를 제공합니다:

| 모드 | 설명 | 권장 상황 |
|------|------|----------|
| **Planning** | 실행 전 계획 수립. Task Groups로 작업 구성, Artifacts 생성, 철저한 연구와 사고 | 복잡한 작업, 심층 연구, 협업 작업 |
| **Fast** | 직접 실행. 변수 이름 변경, bash 명령 실행 등 단순 작업 | 속도가 중요하고 품질 걱정이 적은 단순 작업 |

### 1.5 에이전트 설정 (Agent Settings)

**Artifact Review Policy**:
| 정책 | 동작 |
|------|------|
| **Always Proceed** | 에이전트가 리뷰 요청 없이 자동 진행 |
| **Request Review** | 에이전트가 항상 사용자 리뷰 요청 후 대기 |

**Terminal Command Auto Execution**:
| 정책 | 동작 |
|------|------|
| **Request Review** | 터미널 명령 자동 실행 안 함 (Allow list 제외) |
| **Always Proceed** | 터미널 명령 자동 실행 (Deny list 제외) |

Allow/Deny list는 Settings > Agent 탭에서 설정 가능합니다.

---

## 2. 현재 프로젝트 분석

### 2.1 아키텍처 매핑

현재 boilerplate 프로젝트와 Antigravity의 개념적 매핑:

| 현재 구조 | Antigravity 대응 | 호환성 |
|----------|-----------------|--------|
| `.agent/workflows/` | `.agent/workflows/` | ✅ 완벽 호환 |
| `.agent/rules/` | `.agent/rules/` | ✅ 완벽 호환 (심링크 → 직접 구조로 변환 필요) |
| `.claude/skills/` | `.agent/skills/` | ⚠️ 경로 변경 필요 |
| `.claude/agents/` | 내부 에이전트 시스템 | ⚠️ 마이그레이션 필요 |
| `.claude/hooks/` | Antigravity 네이티브 훅 | ⚠️ 마이그레이션 필요 |
| `.mcp.json` | `mcp_config.json` | ✅ 형식 호환 |
| `CLAUDE.md` | `.antigravity/rules.md` | ⚠️ 변환 필요 |
| `.gsd/` | `.context/` 또는 유지 | ✅ 그대로 사용 가능 |

### 2.2 호환되는 핵심 자산

**완벽 호환 (그대로 사용 가능)**:
- 29개 워크플로우 (`/plan`, `/execute`, `/verify` 등)
- GSD 문서 체계 (SPEC.md, PLAN.md, STATE.md)
- MCP 서버 설정 (graph-code, memorygraph, context7)
- Python 프로젝트 구성 (pyproject.toml, uv)

**변환 필요**:
- 14개 Skills → `.agent/skills/` 형식으로
- 13개 Agents → Antigravity 에이전트 시스템으로
- 9개 Hooks → Antigravity 네이티브 훅으로

---

## 3. 마이그레이션 전략

### 3.1 디렉토리 구조 변환

```
# 현재 구조
.agent/
├── agent.md → ../.github/agents/agent.md (심링크)
├── skills → ../.claude/skills (심링크)
└── workflows/

.claude/
├── agents/
├── skills/
├── hooks/
└── settings.json

# Antigravity 목표 구조
.agent/
├── rules/          # 새로 생성 (.cursorrules + rules.md 병합)
├── skills/         # .claude/skills/ 마이그레이션
└── workflows/      # 기존 유지

.antigravity/
├── rules.md        # CLAUDE.md 변환
└── agents.md       # 에이전트 정의 (선택)

mcp_config.json     # .mcp.json 변환
```

### 3.2 Skills 마이그레이션 (공식 문서 기반)

Skills는 에이전트 기능을 확장하는 **오픈 표준**입니다. 각 스킬은 SKILL.md 파일이 포함된 폴더입니다.

#### 스킬 저장 위치

| 위치 | 범위 |
|------|------|
| `<workspace-root>/.agent/skills/<skill-folder>/` | 워크스페이스 전용 |
| `~/.gemini/antigravity/global_skills/<skill-folder>/` | 전역 (모든 워크스페이스) |

#### 스킬 폴더 구조

```
.agent/skills/my-skill/
├── SKILL.md       # 메인 지침 (필수)
├── scripts/       # 헬퍼 스크립트 (선택)
├── examples/      # 참조 구현 (선택)
└── resources/     # 템플릿 및 자산 (선택)
```

#### SKILL.md 형식 (공식 스펙)

```yaml
---
name: my-skill                    # 선택, 기본값은 폴더명
description: "명확한 설명..."      # 필수! 에이전트가 스킬 적용 여부 결정에 사용
---

# My Skill

## When to use this skill

- Use this when...
- This is helpful for...

## How to use it

Step-by-step guidance, conventions, and patterns.
```

**중요**: `description`은 에이전트가 스킬 사용 여부를 결정하는 핵심입니다. 3인칭으로 작성하고 관련 키워드를 포함하세요.

#### 스킬 작동 방식 (Progressive Disclosure)

1. **Discovery**: 대화 시작 시 에이전트가 사용 가능한 스킬 목록(이름+설명) 확인
2. **Activation**: 스킬이 관련 있어 보이면 전체 SKILL.md 내용 읽기
3. **Execution**: 스킬 지침을 따라 작업 수행

명시적으로 스킬 사용을 요청할 필요 없음 - 에이전트가 컨텍스트 기반으로 결정

#### 현재 스킬 → Antigravity 변환 예시

**변환 전 (.claude/skills/planner/SKILL.md)**:
```markdown
(기존 Claude Code 형식)
```

**변환 후 (.agent/skills/planner/SKILL.md)**:
```yaml
---
name: planner
description: "Creates executable phase plans with task breakdown, dependency analysis, and goal-backward verification. Use when user asks to plan, design, or architect a multi-step implementation."
---

# Planner Skill

## When to use this skill

- When user asks to plan an implementation
- When designing multi-step features
- When breaking down complex requirements

## How to use it

1. Read .gsd/SPEC.md for requirements
2. Break down into phases and atomic tasks
3. Define dependencies and checkpoints
4. Output to .gsd/PLAN.md

## Constraints

- Never skip impact analysis for changes affecting 3+ files
- Always include empirical verification steps
- Follow GSD methodology: SPEC → PLAN → EXECUTE → VERIFY
```

#### Best Practices (공식 권장사항)

1. **스킬은 집중되게**: 각 스킬은 한 가지만 잘 해야 함
2. **명확한 description**: 스킬 사용 시점과 용도를 구체적으로
3. **스크립트는 블랙박스로**: `--help` 먼저 실행 권장, 소스 전체 읽기 지양
4. **결정 트리 포함**: 복잡한 스킬에는 상황별 접근 방법 안내

### 3.3 Hooks 마이그레이션

| 현재 Hook | Antigravity 대응 |
|----------|-----------------|
| `bash-guard.py` | Rules로 변환 (금지 명령 규칙) |
| `file-protect.py` | Rules로 변환 (민감 파일 규칙) |
| `auto-format-py.sh` | Workflows로 변환 (`/format`) |
| `session-start.sh` | Session 초기화 Workflow |
| `pre-compact-save.sh` | 내장 기능 활용 |
| `post-turn-*.sh` | Workflows로 변환 |

### 3.4 MCP 설정 마이그레이션 (공식 문서 기반)

Antigravity는 MCP(Model Context Protocol)를 통해 로컬 도구, 데이터베이스, 외부 서비스와 연결됩니다.

#### MCP 핵심 기능

1. **Context Resources**: 연결된 MCP 서버에서 데이터 읽기 (예: Neon/Supabase 스키마 조회)
2. **Custom Tools**: 정의된 안전한 작업 실행 (예: "이 TODO로 Linear 이슈 생성")

#### MCP 서버 연결 방법

1. **MCP Store 접근**: 에디터 사이드 패널 상단 "..." 드롭다운 → MCP Servers
2. **설치**: 목록에서 서버 선택 → Install 클릭
3. **인증**: 화면 안내에 따라 계정 연결

#### 커스텀 MCP 서버 연결

1. "..." 드롭다운 → MCP Servers → Manage MCP Servers
2. "View raw config" 클릭
3. `mcp_config.json` 수정

#### Antigravity 지원 MCP 서버 (공식)

| 카테고리 | 서버 |
|---------|------|
| **데이터베이스** | AlloyDB, BigQuery, Cloud SQL (PostgreSQL/MySQL/SQL Server), MongoDB, Neon, Pinecone, Redis, Spanner, Supabase |
| **개발 도구** | GitHub, Figma Dev Mode, Locofy, Prisma, SonarQube |
| **프로젝트 관리** | Atlassian, Dart, Harness, Linear, Notion |
| **클라우드/배포** | Firebase, Heroku, Netlify |
| **AI/분석** | Arize, Looker, Perplexity Ask, Sequential Thinking |
| **결제/기타** | Airweave, Dataplex, PayPal, Stripe |

#### 현재 프로젝트 MCP 설정 변환

**현재 `.mcp.json`**:
```json
{
  "mcpServers": {
    "graph-code": { ... },
    "memorygraph": { ... },
    "context7": { ... }
  }
}
```

**Antigravity `mcp_config.json`** (View raw config에서 수정):
```json
{
  "mcpServers": {
    "graph-code": {
      "command": "npx",
      "args": ["-y", "@er77/code-graph-rag-mcp", "."],
      "env": {
        "MCP_TIMEOUT": "80000",
        "NODE_OPTIONS": "--max-old-space-size=4096"
      }
    },
    "memorygraph": {
      "command": "memorygraph",
      "args": ["--profile", "extended"]
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    }
  }
}
```

**참고**: graph-code, memorygraph, context7은 커스텀 서버이므로 "View raw config"에서 직접 추가해야 합니다.

### 3.5 Rules 생성

**`.agent/rules/code-style.md`**:
```markdown
# Code Style Rules

* Use Python 3.12 exclusively
* Follow PEP 8 with line-length 100
* Maximum McCabe complexity: 10
* Maximum function arguments: 6
* Use TypedDict for state definitions
* Package manager: uv only (never pip or poetry)
```

**`.agent/rules/safety.md`**:
```markdown
# Safety Rules

## Never
* Read/print .env or credential files
* Commit hardcoded secrets or API keys
* Run destructive git commands without explicit user request
* Skip failing tests to "fix later"

## Always
* Use analyze_code_impact before refactoring
* Verify empirically with command execution results
* Read SPEC.md before implementation
```

**`.antigravity/rules.md`**:
```markdown
# Project Rules

## Architecture
- AST-based code analysis via code-graph-rag MCP (19 tools)
- Persistent agent memory via memorygraph MCP (12 tools)
- GSD methodology: SPEC.md → PLAN.md → EXECUTE → VERIFY

## Validation
- Empirical evidence only - "it seems to work" is not evidence
- Collect all failures before reporting (don't stop at first)
- Mock only external APIs/network, prefer real objects

## Workflow
- Atomic commits per task
- Checkpoint protocol for human verification
- 3 consecutive failures = change approach
```

---

## 4. 구현 계획

### Phase 1: 기본 구조 설정 (Day 1)

1. **디렉토리 재구성**
   ```bash
   mkdir -p .agent/rules .agent/skills .antigravity
   ```

2. **심링크 제거 및 직접 구조로 변환**
   ```bash
   rm .agent/agent.md .agent/skills  # 심링크 제거
   ```

3. **MCP 설정 변환**
   ```bash
   cp .mcp.json mcp_config.json
   # 형식 조정 (필요시)
   ```

### Phase 2: Skills 마이그레이션 (Day 2-3)

1. **14개 스킬 SKILL.md 형식 변환**
   - planner, executor, verifier
   - arch-review, impact-analysis, codebase-mapper
   - pr-review, debugger, plan-checker
   - clean, commit, create-pr
   - context-health-monitor, bootstrap

2. **스킬 테스트**
   - 각 스킬 호출 테스트
   - description 매칭 검증

### Phase 3: Rules & Workflows (Day 4)

1. **Rules 생성**
   - code-style.md, safety.md, workflow.md
   - .antigravity/rules.md (CLAUDE.md 변환)

2. **Workflows 검증**
   - 29개 워크플로우 Antigravity 호환성 테스트
   - YAML frontmatter 추가 (필요시)

### Phase 4: 통합 테스트 (Day 5)

1. **전체 워크플로우 테스트**
   - `/plan` → `/execute` → `/verify` 사이클
   - MCP 서버 연결 검증
   - Multi-agent 협업 테스트

2. **문서화**
   - README 업데이트
   - Antigravity 전용 가이드 작성

---

## 5. 주요 고려사항

### 5.1 장점

| 항목 | 설명 |
|------|------|
| **네이티브 MCP 지원** | UI에서 직접 MCP 서버 관리 |
| **Multi-Agent 병렬화** | 코드/테스트/문서 동시 작업 |
| **Artifacts 시스템** | 검증 가능한 산출물 관리 |
| **Browser Integration** | E2E 테스트 자동화 |
| **무료 (현재)** | Public Preview 기간 중 무료 |

### 5.2 주의사항

| 항목 | 설명 |
|------|------|
| **클라우드 의존성** | 오프라인 사용 불가, 코드는 로컬이지만 인증은 Google 서버 |
| **데이터 보안** | 프로덕션 자격 증명이 있는 프로젝트 주의 |
| **레거시 코드** | 커스텀 라이브러리가 많은 프로젝트는 제약 있음 |
| **학습 곡선** | 에이전트 기반 개발 패러다임 적응 필요 |

### 5.3 현재 프로젝트 특화 고려사항

1. **GSD 워크플로우 유지**: `.gsd/` 디렉토리와 문서 체계 그대로 유지 가능
2. **code-graph-rag 활용**: Antigravity의 코드 분석과 시너지
3. **memorygraph 통합**: 에이전트 기억 시스템 강화
4. **Hook → Rules 전환**: 파괴적 명령 차단 등 안전 규칙으로 변환

---

## 6. 참고 자료

### 공식 문서 (antigravity.google/docs/)
- [Skills](https://antigravity.google/docs/skills) - 스킬 생성 및 구조
- [Agent Modes / Settings](https://antigravity.google/docs/agent-modes-settings) - Planning/Fast 모드, 정책 설정
- [MCP](https://antigravity.google/docs/mcp) - MCP 통합 및 커스텀 서버 설정
- [Rules / Workflows](https://antigravity.google/docs/rules-workflows) - 규칙 및 워크플로우 커스터마이징
- [Browser Subagent](https://antigravity.google/docs/browser-subagent) - 브라우저 자동화
- [Artifacts](https://antigravity.google/docs/artifacts) - Task List, Implementation Plan, Screenshots 등

### 튜토리얼
- [Getting Started Codelab](https://codelabs.developers.google.com/getting-started-google-antigravity)
- [Complete Guide](https://antigravity.codes/tutorial)
- [Codecademy 설정 가이드](https://www.codecademy.com/article/how-to-set-up-and-use-google-antigravity)
- [Rules & Workflows 커스터마이징](https://atamel.dev/posts/2025/11-25_customize_antigravity_rules_workflows/)

### 커뮤니티
- [Antigravity Workspace Template](https://github.com/study8677/antigravity-workspace-template)
- [Sample Skills Repository](https://github.com/rominirani/antigravity-skills)
- [Awesome Skills Collection](https://github.com/sickn33/antigravity-awesome-skills)

### 블로그 & 리뷰
- [Google Developers Blog 발표](https://developers.googleblog.com/build-with-google-antigravity-our-new-agentic-development-platform/)
- [KDnuggets AI-First Development](https://www.kdnuggets.com/google-antigravity-ai-first-development-with-this-new-ide)
- [Index.dev Agentic IDE 리뷰](https://www.index.dev/blog/google-antigravity-agentic-ide)

---

## 7. 결론 및 권장사항

### 7.1 적합성 평가

현재 boilerplate 프로젝트는 **Antigravity 마이그레이션에 매우 적합**합니다:

- ✅ 멀티 에이전트 아키텍처 이미 구현
- ✅ MCP 기반 도구 통합 완료
- ✅ 워크플로우 기반 개발 프로세스 확립
- ✅ GSD 문서 체계와 Antigravity Artifacts 철학 일치

### 7.2 권장 접근법

1. **점진적 마이그레이션**: 한 번에 모든 것을 변환하지 말고 단계별로 진행
2. **듀얼 지원**: Claude Code와 Antigravity 모두 지원하는 구조 유지 (심링크 활용)
3. **Skills 우선**: 14개 스킬 마이그레이션이 핵심 - SKILL.md 형식은 양쪽 호환
4. **테스트 주도**: 각 단계마다 실제 워크플로우 테스트로 검증

### 7.3 예상 효과

- **개발 속도**: Multi-agent 병렬 실행으로 복잡한 작업 가속화
- **검증 품질**: Artifacts 시스템으로 경험적 검증 강화
- **통합 환경**: 에디터 + 터미널 + 브라우저 통합으로 컨텍스트 스위칭 감소
- **확장성**: Google Cloud 서비스와의 네이티브 통합 가능

---

## 8. 자동 빌드 스크립트

### 빌드 명령

```bash
make build-antigravity
```

### 생성되는 구조

```
antigravity-boilerplate/
├── .agent/
│   ├── skills/          # 15개 스킬 (Antigravity 형식)
│   ├── workflows/       # 30개 워크플로우
│   └── rules/           # 3개 규칙 파일
│       ├── code-style.md
│       ├── safety.md
│       └── gsd-workflow.md
├── templates/gsd/       # GSD 문서 템플릿
├── scripts/             # 유틸리티 스크립트
├── mcp_config.json      # MCP 서버 설정
└── README.md
```

### 사용 방법

1. **독립 워크스페이스로 사용**
   ```bash
   # Antigravity IDE에서 열기
   antigravity antigravity-boilerplate/
   ```

2. **기존 프로젝트에 복사**
   ```bash
   cp -r antigravity-boilerplate/.agent /path/to/project/
   cp antigravity-boilerplate/mcp_config.json /path/to/project/
   ```

3. **MCP 서버 설정**
   - Agent panel "..." → MCP Servers → Manage MCP Servers → View raw config
   - `mcp_config.json` 내용 복사

---

## 9. 마이그레이션 체크리스트

### Phase 1: 기본 설정
- [ ] Antigravity 다운로드 및 설치 (antigravity.google/download)
- [ ] 워크스페이스로 프로젝트 열기 (기존 폴더 선택)
- [ ] VS Code/Cursor 설정 임포트 (선택)

### Phase 2: 디렉토리 구조
- [ ] `.agent/skills/` 디렉토리 생성 (심링크 제거)
- [ ] `.agent/rules/` 디렉토리 생성
- [ ] `~/.gemini/antigravity/` 전역 설정 확인

### Phase 3: Skills 마이그레이션 (14개)
- [ ] planner → `.agent/skills/planner/SKILL.md`
- [ ] executor → `.agent/skills/executor/SKILL.md`
- [ ] verifier → `.agent/skills/verifier/SKILL.md`
- [ ] arch-review → `.agent/skills/arch-review/SKILL.md`
- [ ] impact-analysis → `.agent/skills/impact-analysis/SKILL.md`
- [ ] codebase-mapper → `.agent/skills/codebase-mapper/SKILL.md`
- [ ] pr-review → `.agent/skills/pr-review/SKILL.md`
- [ ] debugger → `.agent/skills/debugger/SKILL.md`
- [ ] plan-checker → `.agent/skills/plan-checker/SKILL.md`
- [ ] clean → `.agent/skills/clean/SKILL.md`
- [ ] commit → `.agent/skills/commit/SKILL.md`
- [ ] create-pr → `.agent/skills/create-pr/SKILL.md`
- [ ] context-health-monitor → `.agent/skills/context-health-monitor/SKILL.md`
- [ ] bootstrap → `.agent/skills/bootstrap/SKILL.md`

### Phase 4: Rules 설정
- [ ] `.agent/rules/code-style.md` 생성
- [ ] `.agent/rules/safety.md` 생성
- [ ] `.agent/rules/workflow.md` 생성
- [ ] `~/.gemini/GEMINI.md` 전역 규칙 설정 (선택)

### Phase 5: MCP 설정
- [ ] MCP Store에서 Sequential Thinking 설치
- [ ] "View raw config"에서 커스텀 서버 추가:
  - [ ] graph-code (code-graph-rag)
  - [ ] memorygraph
  - [ ] context7

### Phase 6: Workflows 검증
- [ ] 29개 워크플로우 YAML frontmatter 확인/추가
- [ ] `/plan`, `/execute`, `/verify` 테스트
- [ ] `/commit`, `/create-pr` 테스트

### Phase 7: 설정 최적화
- [ ] Agent Mode 설정 (Planning 권장)
- [ ] Artifact Review Policy 설정
- [ ] Terminal Command Policy 설정 (Allow/Deny list)

### Phase 8: 통합 테스트
- [ ] 전체 GSD 사이클 테스트 (SPEC → PLAN → EXECUTE → VERIFY)
- [ ] MCP 도구 연결 확인 (graph-code, memorygraph)
- [ ] Browser Subagent 테스트 (선택)
