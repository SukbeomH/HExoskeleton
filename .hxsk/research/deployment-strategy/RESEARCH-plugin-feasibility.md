# 플러그인 전환 가능성 리서치 보고서

> Generated: 2026-01-28
> Source: https://code.claude.com/docs/en/plugins
> Status: Research Complete

---

## 1. Executive Summary

현재 보일러플레이트를 **독립실행형(Standalone)** 구성과 **플러그인(Plugin)** 형태 두 가지로 제작하는 것은 **기술적으로 가능**하며, Claude Code의 공식 플러그인 시스템이 보일러플레이트의 핵심 구성요소(Skills, Agents, Hooks, MCP Servers)를 모두 지원한다.

다만, 플러그인 시스템이 지원하지 않는 요소들(.gsd/ 문서 체계, Makefile, CLAUDE.md, pyproject.toml, .vscode/, scripts/)이 있어 **완전한 1:1 변환은 불가능**하고, 플러그인이 담당할 범위와 프로젝트 측에 남겨둘 범위를 명확히 분리해야 한다.

### 핵심 결론

| 판정 | 내용 |
|------|------|
| **가능** | Skills(14), Agents(13), Hooks(4+), MCP Servers(3)의 플러그인 패키징 |
| **가능** | Standalone과 Plugin의 병행 유지 (dual-mode) |
| **불가** | .gsd/ 문서체계, Makefile, pyproject.toml의 플러그인 내 포함 |
| **부분적** | .agent/ workflows(29)는 commands/로 마이그레이션 가능하나 별도 검증 필요 |

---

## 2. Claude Code 플러그인 시스템 분석

### 2.1 플러그인 아키텍처

```
plugin-root/
├── .claude-plugin/
│   └── plugin.json          # 필수: 플러그인 매니페스트
├── commands/                 # 사용자 호출 커맨드 (Markdown)
├── agents/                   # 서브에이전트 정의 (Markdown + YAML frontmatter)
├── skills/                   # 모델 호출 스킬 (SKILL.md + 지원 파일)
├── hooks/
│   └── hooks.json            # 이벤트 핸들러
├── .mcp.json                 # MCP 서버 설정
├── .lsp.json                 # LSP 서버 설정 (선택)
├── scripts/                  # 훅/유틸 스크립트
└── README.md
```

### 2.2 플러그인 vs 독립실행형 비교

| 특성 | 독립실행형 (.claude/) | 플러그인 (.claude-plugin/) |
|------|----------------------|--------------------------|
| **스킬 이름** | `/hello` | `/plugin-name:hello` |
| **공유** | 수동 복사 | marketplace 설치 |
| **버전 관리** | git만 | semantic versioning |
| **적용 범위** | 현재 프로젝트만 | 여러 프로젝트 |
| **네임스페이스** | 없음 (충돌 가능) | 있음 (충돌 방지) |
| **설치** | 파일 복사 | `claude plugin install` |
| **업데이트** | git pull | `/plugin update` |

### 2.3 플러그인 지원 컴포넌트

| 컴포넌트 | 지원 여부 | 위치 | 비고 |
|----------|----------|------|------|
| Skills | **지원** | `skills/<name>/SKILL.md` | frontmatter 포함 |
| Agents | **지원** | `agents/<name>.md` | YAML frontmatter + body |
| Hooks | **지원** | `hooks/hooks.json` | `${CLAUDE_PLUGIN_ROOT}` 변수 사용 |
| MCP Servers | **지원** | `.mcp.json` | `${CLAUDE_PLUGIN_ROOT}` 변수 사용 |
| LSP Servers | **지원** | `.lsp.json` | 바이너리는 사용자 설치 |
| Commands | **지원** | `commands/<name>.md` | 레거시, skills/ 권장 |
| CLAUDE.md | **미지원** | - | 프로젝트에 남겨야 함 |
| Makefile | **미지원** | - | 프로젝트에 남겨야 함 |
| .gsd/ 문서 | **미지원** | - | 프로젝트에 남겨야 함 |
| pyproject.toml | **미지원** | - | 프로젝트에 남겨야 함 |

### 2.4 핵심 제약사항

1. **플러그인 캐싱**: 설치 시 플러그인 디렉토리가 캐시에 복사됨. `../` 경로 사용 불가.
2. **네임스페이스**: 플러그인 스킬은 항상 `plugin-name:skill-name` 형태로 호출됨.
3. **환경 변수**: `${CLAUDE_PLUGIN_ROOT}` — 플러그인 디렉토리의 절대 경로.
4. **상대 경로만**: 모든 경로는 `./`로 시작하는 상대 경로여야 함.
5. **서브에이전트 제한**: 서브에이전트는 다른 서브에이전트를 생성할 수 없음.

---

## 3. 현재 보일러플레이트 컴포넌트 매핑

### 3.1 완전 호환 (그대로 이식 가능)

| 현재 위치 | 플러그인 위치 | 수량 | 변환 난이도 |
|-----------|-------------|------|------------|
| `.claude/skills/*` | `skills/*` | 14 | 낮음 |
| `.claude/agents/*` | `agents/*` | 13 | 낮음 |
| `.claude/hooks/*` | `hooks/hooks.json` + `scripts/` | 4 | 중간 |
| `.mcp.json` | `.mcp.json` | 3 | 중간 (경로 변환 필요) |

### 3.2 조건부 호환 (변환 필요)

| 현재 위치 | 플러그인 대응 | 변환 작업 |
|-----------|-------------|----------|
| `.agent/workflows/*` (29개) | `commands/*.md` | frontmatter 추가, 경로 참조 수정 |
| `.claude/settings.json` (hooks) | `hooks/hooks.json` | `$CLAUDE_PROJECT_DIR` → `${CLAUDE_PLUGIN_ROOT}` |
| `.claude/settings.local.json` (permissions) | 불가 | 사용자가 별도 설정 필요 |

### 3.3 비호환 (플러그인 외부에 유지)

| 컴포넌트 | 사유 | 대안 |
|----------|------|------|
| `.gsd/` 전체 | 플러그인은 런타임 문서를 생성/관리할 수 없음 | 프로젝트 초기화 스킬로 scaffolding |
| `CLAUDE.md` | 프로젝트별 설정 파일, 플러그인 매니페스트에 없음 | 템플릿으로 제공, 초기화 시 복사 |
| `Makefile` | 플러그인 시스템 밖 | 프로젝트 scaffolding에 포함 |
| `pyproject.toml` | Python 프로젝트 설정 | 프로젝트 scaffolding에 포함 |
| `.vscode/` | IDE 설정 | 프로젝트 scaffolding에 포함 |
| `.github/` | CI/CD, Agent spec | 프로젝트 scaffolding에 포함 |
| `tests/` | 테스트 코드 | 프로젝트 scaffolding에 포함 |
| `scripts/bootstrap.sh` | 시스템 전제조건 검사 | Setup hook으로 일부 가능 |

---

## 4. 제안 아키텍처: Dual-Mode

### 4.1 개요

```
boilerplate/                          # Standalone (현재 구조 유지)
├── .claude/
│   ├── skills/                       # 14 Skills
│   ├── agents/                       # 13 Agents
│   ├── hooks/                        # Hook scripts
│   └── settings.json                 # Hook config
├── .agent/workflows/                 # 29 GSD commands
├── .gsd/                             # GSD 문서체계
├── .mcp.json                         # MCP servers
├── Makefile
├── CLAUDE.md
└── ...

boilerplate-plugin/                   # Plugin (새로 생성)
├── .claude-plugin/
│   └── plugin.json                   # 매니페스트
├── skills/                           # 14 Skills (복사 + 조정)
├── agents/                           # 13 Agents (복사 + 조정)
├── commands/                         # 29 GSD commands (workflows → commands)
├── hooks/
│   └── hooks.json                    # Hook config (변환)
├── scripts/                          # Hook scripts (경로 변환)
│   ├── session-start.sh
│   ├── bash-guard.py
│   ├── file-protect.py
│   ├── auto-format-py.sh
│   └── pre-compact-save.sh
├── .mcp.json                         # MCP servers (경로 변환)
├── templates/                        # 프로젝트 초기화용 템플릿
│   ├── CLAUDE.md.template
│   ├── Makefile.template
│   ├── pyproject.toml.template
│   └── gsd/                          # .gsd/ 템플릿들
└── README.md
```

### 4.2 플러그인 매니페스트 (plugin.json)

```json
{
  "name": "gsd-agent-boilerplate",
  "description": "AI agent development framework with GSD methodology, code-graph-rag, memory-graph, and 14 skills + 13 sub-agents",
  "version": "1.0.0",
  "author": {
    "name": "sukbeom"
  },
  "homepage": "https://github.com/sukbeom/boilerplate",
  "repository": "https://github.com/sukbeom/boilerplate",
  "license": "MIT",
  "keywords": [
    "gsd", "agent", "code-graph-rag", "memory-graph",
    "code-analysis", "development-workflow", "ai-agent"
  ]
}
```

### 4.3 네임스페이스 변경 영향

**현재 (Standalone):**
- `/commit`, `/clean`, `/planner`, `/executor`, `/verifier`
- `/new-project`, `/plan`, `/execute`, `/verify`, `/debug`

**플러그인 전환 시:**
- `/gsd-agent-boilerplate:commit`, `/gsd-agent-boilerplate:clean`
- `/gsd-agent-boilerplate:new-project`, `/gsd-agent-boilerplate:plan`

이름이 길어지므로 플러그인 name을 **짧게** 정하는 것이 중요:
- 권장: `gsd` → `/gsd:commit`, `/gsd:plan`, `/gsd:verify`
- 대안: `agent-kit` → `/agent-kit:commit`

---

## 5. 변환 작업 상세 분석

### 5.1 Skills 변환 (14개) — 난이도: 낮음

현재 `.claude/skills/*/SKILL.md` 파일들은 이미 Claude Code 스킬 표준 형식을 따르고 있어 그대로 복사 가능.

**필요한 수정:**
- 일부 스킬에서 `$CLAUDE_PROJECT_DIR` 참조 → `${CLAUDE_PLUGIN_ROOT}` 변경
- scripts/ 하위 스크립트의 경로 수정
- frontmatter `name` 필드 확인 (kebab-case, max 64자)

**스킬 목록과 변환 상태:**

| 스킬 | 외부 스크립트 | 경로 수정 필요 |
|------|-------------|--------------|
| bootstrap | 없음 | 아니오 |
| planner | 없음 | 아니오 |
| executor | 없음 | 아니오 |
| verifier | scripts/check_artifacts.sh | 예 |
| commit | 없음 | 아니오 |
| create-pr | 없음 | 아니오 |
| pr-review | scripts/extract_pr_diff.sh | 예 |
| clean | scripts/run_quality_checks.sh | 예 |
| codebase-mapper | scripts/scan_structure.sh | 예 |
| debugger | scripts/collect_diagnostics.sh | 예 |
| impact-analysis | 없음 | 아니오 |
| plan-checker | 없음 | 아니오 |
| empirical-validation | 없음 | 아니오 |
| context-health-monitor | scripts/dump_state.sh | 예 |

### 5.2 Agents 변환 (13개) — 난이도: 낮음

현재 `.claude/agents/*.md`는 이미 YAML frontmatter + Markdown body 형식.

**필요한 수정:**
- 플러그인 `agents/` 디렉토리로 복사
- `skills` 필드에서 스킬 이름 참조가 네임스페이스 변경에 영향 받는지 확인
- `hooks` 필드 내 스크립트 경로 → `${CLAUDE_PLUGIN_ROOT}` 변환

### 5.3 Hooks 변환 — 난이도: 중간

**현재 구조:**
```
.claude/settings.json → hooks 설정
.claude/hooks/ → 4개 스크립트
```

**플러그인 구조:**
```
hooks/hooks.json → 훅 설정
scripts/ → 스크립트 (경로 변환)
```

**변환 작업:**
1. `.claude/settings.json`의 `hooks` 객체를 `hooks/hooks.json`으로 추출
2. `"$CLAUDE_PROJECT_DIR"/.claude/hooks/` → `${CLAUDE_PLUGIN_ROOT}/scripts/`
3. 스크립트 내부의 프로젝트 경로 참조 검토

**주의사항:**
- `settings.local.json`의 `permissions`는 플러그인에서 설정 불가. 사용자가 별도 구성해야 함.
- SessionStart 훅의 `CLAUDE_ENV_FILE` 활용은 플러그인에서도 동작.

### 5.4 MCP Servers 변환 — 난이도: 중간

**현재 `.mcp.json`:**
```json
{
  "mcpServers": {
    "graph-code": { "command": "npx", "args": ["-y", "@er77/code-graph-rag-mcp", "."] },
    "memorygraph": { "command": "memorygraph", "args": ["--profile", "extended"] },
    "context7": { "type": "http", "url": "https://mcp.context7.com/mcp" }
  }
}
```

**변환 시 고려사항:**
- `graph-code`의 `"."` 인자 → 프로젝트 루트를 가리키지만, 플러그인 캐시에서 실행되면 경로가 달라짐
- `memorygraph`의 데이터 파일(`vectors.db`)은 프로젝트에 위치해야 하는데, 플러그인 캐시에서는 접근 불가
- `context7`은 HTTP 타입이라 경로 무관, 변환 용이

**해결 방안:**
- `graph-code`: `"args": ["-y", "@er77/code-graph-rag-mcp", "${CLAUDE_PROJECT_DIR:-.}"]` — 환경 변수 활용
- `memorygraph`: 사용자가 별도로 설치하고, 플러그인은 설정만 제공 (또는 Setup 훅에서 초기화)
- context7: 그대로 이식

### 5.5 GSD Workflows 변환 (29개) — 난이도: 높음

`.agent/workflows/*.md` → `commands/*.md`로 변환해야 함.

**문제점:**
1. 워크플로우 파일들이 `.gsd/` 디렉토리의 파일을 직접 참조 (SPEC.md, PLAN.md, STATE.md 등)
2. 워크플로우 간 상호 참조 (`/plan`이 `/execute`를 언급 등)
3. 프로젝트별 컨텍스트에 강하게 의존

**해결 방안:**
- 워크플로우 내 `.gsd/` 참조는 유지 (프로젝트에 .gsd/가 있어야 동작)
- `/new-project` 커맨드를 프로젝트 scaffolding 역할로 강화
- 플러그인 설치 후 `/gsd:new-project` 실행 시 .gsd/ 디렉토리 생성

---

## 6. Marketplace 배포 전략

### 6.1 배포 옵션

| 방법 | 적합도 | 이유 |
|------|-------|------|
| **GitHub Repository Marketplace** | 최적 | Git 기반, 상대 경로 지원, 버전 관리 용이 |
| Local Path | 개발/테스트용 | 빠른 반복 |
| npm | 부적합 | 플러그인 시스템과 직접 연계 안 됨 |

### 6.2 Marketplace 구조

```
gsd-marketplace/
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── gsd/                          # 메인 플러그인
│       ├── .claude-plugin/
│       │   └── plugin.json
│       ├── skills/
│       ├── agents/
│       ├── commands/
│       ├── hooks/
│       ├── scripts/
│       ├── .mcp.json
│       └── README.md
└── README.md
```

### 6.3 프로젝트 측 설정 (extraKnownMarketplaces)

팀 프로젝트에서 자동 설치 유도:
```json
{
  "extraKnownMarketplaces": {
    "gsd-marketplace": {
      "source": {
        "source": "github",
        "repo": "sukbeom/gsd-marketplace"
      }
    }
  },
  "enabledPlugins": {
    "gsd@gsd-marketplace": true
  }
}
```

---

## 7. 리스크 분석

### 7.1 높은 리스크

| 리스크 | 영향 | 완화 |
|--------|------|------|
| MCP 서버의 프로젝트 경로 참조 | graph-code가 캐시 디렉토리에서 실행되면 현재 프로젝트를 인덱싱하지 못함 | `${CLAUDE_PROJECT_DIR}` 활용 또는 프로젝트 측 .mcp.json 유지 |
| .gsd/ 문서 의존성 | 29개 워크플로우가 .gsd/ 없이 동작 불가 | 프로젝트 초기화 커맨드에서 scaffolding |
| 네임스페이스 길이 | `/gsd-agent-boilerplate:new-project`는 사용성 저하 | 플러그인 이름을 `gsd`로 축약 |

### 7.2 중간 리스크

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 훅 스크립트 경로 변환 | 잘못된 경로로 훅 실행 실패 | `${CLAUDE_PLUGIN_ROOT}` 일관 사용, 테스트 |
| Permission 설정 미포함 | 사용자가 매번 권한 승인 필요 | README에 권장 설정 문서화 |
| Claude Code 버전 요구 | 1.0.33+ 필요 | 문서에 명시 |

### 7.3 낮은 리스크

| 리스크 | 영향 | 완화 |
|--------|------|------|
| 스킬 콘텐츠 크기 | 14개 스킬 description이 15,000자 초과 가능 | `disable-model-invocation: true` 활용으로 컨텍스트 절약 |
| 에이전트 모델 지정 | 모델 가용성은 사용자 구독에 의존 | `inherit` 폴백 |

---

## 8. 제작 계획

### Phase 1: 기반 구조 (플러그인 디렉토리 생성)

**목표:** 플러그인 기본 구조 생성 및 매니페스트 작성

**작업:**
1. `boilerplate-plugin/` 디렉토리 생성
2. `.claude-plugin/plugin.json` 매니페스트 작성
3. 디렉토리 구조 생성 (skills/, agents/, commands/, hooks/, scripts/)
4. README.md 작성

**산출물:** 빈 플러그인 구조

### Phase 2: Skills + Agents 이식

**목표:** 14 Skills + 13 Agents 복사 및 경로 수정

**작업:**
1. `.claude/skills/*` → `skills/` 복사
2. 스크립트 참조 경로를 `${CLAUDE_PLUGIN_ROOT}` 기반으로 수정
3. `.claude/agents/*` → `agents/` 복사
4. agent frontmatter의 skills 참조 검증
5. 각 스킬/에이전트의 스크립트 파일 복사 및 경로 수정

**산출물:** 27개 컴포넌트 이식 완료

### Phase 3: Hooks 이식

**목표:** 4개 훅 설정 및 5개 스크립트 변환

**작업:**
1. `.claude/settings.json`의 hooks → `hooks/hooks.json` 변환
2. 훅 스크립트 → `scripts/` 복사 및 경로 수정
3. `$CLAUDE_PROJECT_DIR` → `${CLAUDE_PLUGIN_ROOT}` 변환
4. 스크립트 실행 권한(chmod +x) 확인

**산출물:** hooks.json + 5개 스크립트

### Phase 4: GSD Workflows 변환

**목표:** 29개 워크플로우를 commands/로 마이그레이션

**작업:**
1. `.agent/workflows/*.md` → `commands/*.md` 복사
2. 각 파일에 YAML frontmatter 추가 (description, disable-model-invocation 등)
3. .gsd/ 경로 참조 검토 (프로젝트 측 존재 가정)
4. 워크플로우 간 상호 참조를 네임스페이스 형태로 업데이트
5. `/new-project` 커맨드에 .gsd/ scaffolding 로직 추가

**산출물:** 29개 커맨드 파일

### Phase 5: MCP 서버 설정

**목표:** MCP 서버 설정 이식 및 경로 문제 해결

**작업:**
1. `.mcp.json` → 플러그인용 `.mcp.json` 작성
2. graph-code의 프로젝트 경로 참조 해결 (환경 변수 또는 문서화)
3. memorygraph 설정 검증
4. context7 HTTP 서버 설정 복사

**산출물:** .mcp.json

### Phase 6: 프로젝트 템플릿 패키징

**목표:** 플러그인 외부 컴포넌트의 scaffolding 템플릿 제작

**작업:**
1. `templates/` 디렉토리에 프로젝트 초기화 파일 준비
   - CLAUDE.md.template
   - Makefile.template
   - pyproject.toml.template
   - .gsd/ 전체 템플릿
   - .vscode/ 설정
   - .github/ CI/CD + Agent spec
   - .env.example
2. `/gsd:init` (또는 `/gsd:new-project`) 커맨드에서 템플릿 복사 로직 구현
3. conftest.py, test_sample.py 등 테스트 보일러플레이트 포함

**산출물:** templates/ 디렉토리 + 초기화 커맨드

### Phase 7: 테스트 및 검증

**목표:** 플러그인 로딩 및 전체 기능 검증

**작업:**
1. `claude --plugin-dir ./boilerplate-plugin` 로 로컬 테스트
2. 각 스킬 호출 테스트 (`/gsd:commit`, `/gsd:clean` 등)
3. 에이전트 위임 테스트 (Task tool 동작 확인)
4. 훅 트리거 테스트 (PreToolUse, PostToolUse, SessionStart, PreCompact)
5. MCP 서버 시작 확인
6. `/gsd:new-project`로 프로젝트 scaffolding 테스트
7. `claude --debug`로 에러 확인

**산출물:** 검증 보고서

### Phase 8: Marketplace 배포

**목표:** GitHub marketplace 레포지토리 생성 및 배포

**작업:**
1. `gsd-marketplace` GitHub 레포지토리 생성
2. `.claude-plugin/marketplace.json` 작성
3. 플러그인 디렉토리 배치
4. README.md (설치 가이드, 사용법, 요구사항)
5. `claude plugin validate .` 검증
6. 팀원 설치 테스트

**산출물:** 배포된 marketplace

---

## 9. Standalone 유지보수 전략

Standalone 버전은 현재 구조를 유지하되, 플러그인과의 동기화를 위한 전략이 필요:

### 9.1 단일 소스 (Single Source of Truth)

```
boilerplate/                          # 메인 리포
├── plugin/                           # 플러그인 소스 (서브디렉토리)
│   ├── .claude-plugin/plugin.json
│   ├── skills/                       # ← 이것이 원본
│   ├── agents/                       # ← 이것이 원본
│   └── ...
├── .claude/
│   ├── skills → ../plugin/skills     # 심볼릭 링크
│   ├── agents → ../plugin/agents     # 심볼릭 링크
│   └── hooks/                        # 프로젝트용 (settings.json에서 참조)
│       └── ... → ../plugin/scripts/  # 심볼릭 링크
├── .agent/workflows/                 # Standalone 전용 (plugin에는 commands/)
├── .gsd/                             # Standalone 전용
└── ...
```

**장점:** skills/agents를 한 곳에서만 수정하면 양쪽 모두 반영
**단점:** 심볼릭 링크 관리 복잡성

### 9.2 대안: 빌드 스크립트

```bash
# scripts/sync-plugin.sh
# standalone → plugin 동기화
cp -r .claude/skills/* plugin/skills/
cp -r .claude/agents/* plugin/agents/
# ... 경로 변환 자동화
```

### 9.3 권장 방식

**초기에는 수동 동기화** (Phase 1-7), 안정화 후 **심볼릭 링크 방식**으로 전환.

---

## 10. 작업량 추정

| Phase | 컴포넌트 수 | 복잡도 |
|-------|-----------|--------|
| Phase 1: 기반 구조 | 5 files | 낮음 |
| Phase 2: Skills + Agents | 27 + scripts | 낮음 |
| Phase 3: Hooks | 6 files | 중간 |
| Phase 4: GSD Workflows | 29 files | 높음 |
| Phase 5: MCP 서버 | 1 file | 중간 |
| Phase 6: 템플릿 | 20+ files | 중간 |
| Phase 7: 테스트 | - | 중간 |
| Phase 8: Marketplace | 3 files | 낮음 |

**총 변환 대상:** ~90 파일, 6,000+ 줄

---

## 11. 결론 및 권장사항

### 권장 접근법

1. **Phase 1-3 먼저 실행** — Skills, Agents, Hooks는 거의 그대로 이식 가능하므로 빠르게 MVP 확보
2. **Phase 4는 단계적으로** — 29개 워크플로우 중 핵심 6개(`new-project`, `plan`, `execute`, `verify`, `map`, `debug`)부터 변환
3. **Phase 5-6은 MCP 경로 문제 해결 후** — graph-code의 프로젝트 디렉토리 참조가 핵심 이슈
4. **플러그인 이름은 `gsd`로** — `/gsd:plan`, `/gsd:verify` 등 간결한 네임스페이스

### 최종 판정

| 항목 | 판정 |
|------|------|
| 플러그인 전환 가능성 | **가능** (80% 호환) |
| Standalone 병행 유지 | **가능** (심볼릭 링크 또는 빌드 스크립트) |
| Marketplace 배포 | **가능** (GitHub 기반) |
| 완전 자동 프로젝트 초기화 | **부분적** (scaffolding 커맨드 필요) |
