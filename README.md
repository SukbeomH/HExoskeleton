# Developer Boilerplate

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. code-graph-rag(AST 인덱싱) + memory-graph(에이전트 기억)와 GSD(Get Shit Done) 문서 기반 방법론을 결합하여 구조화된 개발 워크플로우를 제공합니다.

## 디렉토리 구조

```
.
├── .agent/            — 에이전트 설정 (symlinks, GSD 워크플로우)
├── .claude/           — Claude Code 스킬 및 설정
├── .gemini/           — Gemini 설정
├── .github/           — GitHub 에이전트 스펙 & 이슈 템플릿
├── .gsd/              — GSD 문서, 템플릿, 예제
├── .specs/            — 명세 템플릿 (실제 문서는 .gsd/에 생성)
├── .vscode/           — VS Code 워크스페이스 설정 & 권장 확장
├── .mcp.json          — MCP 서버 연결 설정 (Claude Code)
├── scripts/           — 유틸리티 스크립트
├── .env.example       — 환경변수 템플릿
├── Makefile           — 개발 명령어 (make help)
├── pyproject.toml     — Python 프로젝트 설정 (uv)
└── CLAUDE.md          — Claude Code 지침
```

---

## Prerequisites

다음 도구가 시스템에 설치되어 있어야 합니다.

| 도구 | 용도 | 설치 |
|------|------|------|
| **Node.js** | code-graph-rag MCP 서버 실행 | [nodejs.org](https://nodejs.org/) |
| **uv** | Python 패키지 관리 | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| **pipx** | CLI 도구 격리 설치 | `brew install pipx && pipx ensurepath` |
| gh CLI | GitHub PR/Issue (선택) | `brew install gh` |

설치 여부 확인:

```bash
make check-deps
```

---

## Quick Start

### 원클릭 셋업

```bash
make setup
```

이 명령은 다음을 순서대로 수행합니다:

1. **memorygraph** 설치 (pipx)
2. `.env` 파일 생성 (`.env.example` 복사)
3. 코드베이스 **인덱싱** (Tree-sitter → SQLite)

셋업 완료 후:

```bash
# 1. .env 파일에서 API 키 설정 (선택)
#    - CONTEXT7_API_KEY

# 2. Claude Code 재시작하여 MCP 서버 로드
```

---

## 수동 설치 (단계별)

### Step 1: 외부 도구 설치

```bash
# memorygraph: 에이전트 영구 기억 MCP 서버
make install-memorygraph

# code-graph-rag: npm 패키지로 자동 설치 (npx로 on-demand 실행)
# 별도 설치 불필요 — npx -y @er77/code-graph-rag-mcp 으로 자동 다운로드
```

### Step 2: 환경 변수 설정

```bash
make init-env       # .env.example → .env 복사
```

`.env` 파일을 열고 필요 시 설정합니다:

```bash
# 선택
CONTEXT7_API_KEY=your-key             # Context7 MCP 사용 시
```

### Step 3: 코드베이스 인덱싱

```bash
make index          # Tree-sitter 파싱 → SQLite 저장
```

### Step 4: MCP 서버 확인

`.mcp.json`이 `npx`를 통해 `@er77/code-graph-rag-mcp`를 직접 실행합니다.
Claude Code를 재시작하면 자동으로 MCP 서버에 연결됩니다.

```bash
make status         # MCP 도구 + 환경 상태 확인
```

---

## Make 명령어

```bash
make help                   # 전체 명령어 목록
```

### 설치/설정

| 명령어 | 설명 |
|--------|------|
| `make setup` | 전체 초기 설정 (설치 → 환경 → 인덱싱) |
| `make check-deps` | 필수 도구 설치 여부 확인 |
| `make install-deps` | 모든 외부 의존성 설치 |
| `make install-memorygraph` | memorygraph 설치 (pipx) |
| `make init-env` | `.env.example` → `.env` 생성 |

### 인프라

| 명령어 | 설명 |
|--------|------|
| `make status` | MCP 도구 + 환경 상태 확인 |
| `make index` | 코드베이스 인덱싱 (code-graph-rag) |
| `make clean` | 인덱스 데이터 + 패치 워크스페이스 삭제 |

### 코드 품질

| 명령어 | 설명 |
|--------|------|
| `make lint` | Ruff 린트 |
| `make lint-fix` | Ruff 자동 수정 |
| `make test` | pytest 실행 |
| `make typecheck` | mypy 타입 체크 |
| `make validate` | SPEC.md 구조 검증 |

---

## GSD 워크플로우

```
/new-project    → SPEC.md 작성
/plan           → 페이즈별 실행 계획 생성
/execute        → 웨이브 단위 구현 (atomic commits)
/verify         → 필수 요구사항 검증
```

전체 29개 워크플로우: `/help` 참조

---

## 핵심 도구

### code-graph-rag (코드 분석)

Tree-sitter + SQLite 기반 AST 코드 분석. `@er77/code-graph-rag-mcp` npm 패키지를 npx로 실행합니다.

주요 MCP 도구 (19개):

| MCP Tool | 용도 |
|----------|------|
| `query` | 자연어 코드 그래프 쿼리 |
| `semantic_search` | 의미 기반 코드 검색 |
| `analyze_code_impact` | 변경 영향 분석 |
| `analyze_hotspots` | 복잡도/커플링 핫스팟 탐지 |
| `detect_code_clones` | 중복 코드 탐지 |
| `find_similar_code` | 유사 코드 검색 |
| `list_file_entities` | 파일 내 엔티티 목록 |
| `list_entity_relationships` | 엔티티 의존성 조회 |
| `suggest_refactoring` | 리팩토링 제안 |
| `cross_language_search` | 다국어 코드 검색 |
| `find_related_concepts` | 관련 개념 탐색 |
| `index` | 코드베이스 인덱싱 |
| `clean_index` | 그래프 초기화 후 재인덱싱 |
| `get_graph` | 코드 그래프 조회 |
| `get_graph_stats` | 그래프 통계 |
| `get_graph_health` | 그래프 헬스 체크 |
| `reset_graph` | 그래프 데이터 초기화 |
| `get_metrics` | 시스템 메트릭 |
| `get_version` | 서버 버전 확인 |

### memory-graph (에이전트 기억)

에이전트가 세션 간 학습한 패턴, 결정, 컨벤션을 영구 저장합니다.

| MCP Tool | 용도 |
|----------|------|
| `store_memory` | 패턴, 결정, 학습 내용 저장 |
| `recall_memories` | 자연어 기반 기억 검색 |
| `search_memories` | 필터 기반 고급 검색 |
| `get_memory` / `update_memory` / `delete_memory` | 개별 기억 CRUD |
| `create_relationship` / `get_related_memories` | 기억 간 관계 관리 |
| `get_memory_statistics` / `get_recent_activity` | 통계 및 최근 활동 |
| `search_relationships_by_context` / `contextual_search` | 컨텍스트 기반 검색 |

---

## 개발 환경 (IDE)

### VS Code 확장프로그램

프로젝트를 열면 `.vscode/extensions.json`에 정의된 권장 확장을 자동으로 안내합니다.

| 확장프로그램 | ID | 역할 |
|---|---|---|
| Ruff | `charliermarsh.ruff` | 린터 + 포매터 (네이티브 서버) |
| Python | `ms-python.python` | 인터프리터, 디버깅, 환경 관리 |
| Mypy Type Checker | `ms-python.mypy-type-checker` | 타입 체크 (Protocol/ABC 계약 검증) |
| Ruff Ignore Explainer | `jannchie.ruff-ignore-explainer` | `pyproject.toml`의 `select`/`ignore` 규칙 설명 인라인 표시 |

### Ruff 규칙

`pyproject.toml`에 다음 규칙이 활성화되어 있습니다:

| 규칙 | 설명 |
|------|------|
| `E` | pycodestyle errors |
| `F` | pyflakes |
| `I` | isort (import 정렬) |
| `N` | pep8-naming (네이밍 컨벤션) |
| `W` | pycodestyle warnings |
| `B` | flake8-bugbear (ABC 검증, 버그 패턴) |
| `C90` | McCabe complexity (순환 복잡도 ≤ 10) |
| `PL` | Pylint (인자 ≤ 6, 리턴 ≤ 6) |
| `TC` | flake8-type-checking (타입 전용 import 분리) |

---

## 에이전트 설정

| 에이전트 | 설정 파일 |
|----------|-----------|
| **GitHub Agents** | `.github/agents/agent.md` |
| **Claude Code** | `.claude/skills/`, `CLAUDE.md` |
| **Gemini** | `.gemini/GEMINI.md` |

---

## Troubleshooting

### code-graph-rag MCP 서버 연결 실패

```bash
# Node.js / npm 설치 확인
node --version
npm --version

# 수동 테스트
npx -y @er77/code-graph-rag-mcp --version

# 타임아웃 발생 시 MCP_TIMEOUT 환경변수 조정
# .mcp.json의 env.MCP_TIMEOUT 값을 늘려 보세요 (기본: 80000ms)
```

### memorygraph 연결 실패

```bash
# 설치 확인
which memorygraph
memorygraph --version

# 재설치
pipx reinstall memorygraphMCP
```

### 인덱싱 실패

```bash
# Node.js가 설치되어 있는지 확인
node --version

# 메모리 부족 시 NODE_OPTIONS 조정
NODE_OPTIONS="--max-old-space-size=4096" npx -y @er77/code-graph-rag-mcp index .
```

---

## 사용자 정의

이 보일러플레이트를 프로젝트에 맞게 수정하세요:

1. `.env` — `PROJECT_ID` 설정
2. `.gsd/SPEC.md` — 프로젝트 요구사항 정의 (`/new-project`로 생성)
3. `.mcp.json` — MCP 서버 연결 설정 (추가 서버 등록 시)
