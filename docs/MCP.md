# MCP (Model Context Protocol) 상세 문서

> **참고**: v1.8.1부터 이 프로젝트는 **순수 bash 기반 메모리 시스템**을 사용합니다.
> MCP 서버는 **선택적**이며, 추가 기능이 필요한 경우에만 설정합니다.
> 기본 메모리 기능은 `.claude/hooks/md-store-memory.sh`와 `md-recall-memory.sh`로 제공됩니다.

**MCP (Model Context Protocol)**는 Claude Code와 외부 도구/서비스를 연결하는 프로토콜입니다.

---

## 개요

| 항목 | 설명 |
|------|------|
| **설정 파일** | `.mcp.json` (선택적) |
| **기본 모드** | 순수 bash (외부 종속성 없음) |
| **확장 모드** | MCP 서버 연동 (추가 설치 필요) |

### 순수 Bash 모드 vs MCP 모드

| 기능 | 순수 Bash 모드 | MCP 모드 |
|------|---------------|----------|
| **메모리 저장** | `md-store-memory.sh` | `mcp-memory-service` |
| **메모리 검색** | `md-recall-memory.sh` + Grep/Glob | `memory_search` (semantic) |
| **코드 분석** | 네이티브 Grep/Glob/Read | `code-graph-rag` (AST) |
| **외부 종속성** | 없음 | Node.js, pipx |
| **설치 복잡도** | 즉시 사용 | 추가 설치 필요 |

---

## 설정 파일

### .mcp.json

```json
{
  "mcpServers": {
    "graph-code": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@er77/code-graph-rag-mcp", "."],
      "env": {
        "MCP_TIMEOUT": "80000",
        "NODE_OPTIONS": "--max-old-space-size=4096"
      }
    },
    "memory": {
      "type": "stdio",
      "command": "memory",
      "args": ["server"],
      "env": {
        "MCP_MEMORY_SQLITE_PATH": ".agent/data/memory-service/memories.db"
      }
    },
    "context7": {
      "type": "http",
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    }
  },
  "enable_tool_search": true
}
```

---

## MCP 서버 상세

### 1. graph-code (code-graph-rag)

**역할**: Tree-sitter + SQLite 기반 AST 코드 분석

**설치**:
```bash
npm install -g @er77/code-graph-rag-mcp
```

**설정**:
```json
{
  "graph-code": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@er77/code-graph-rag-mcp", "."],
    "env": {
      "MCP_TIMEOUT": "80000",
      "NODE_OPTIONS": "--max-old-space-size=4096"
    }
  }
}
```

**환경변수**:
| 변수 | 기본값 | 설명 |
|------|--------|------|
| `MCP_TIMEOUT` | 80000 | 타임아웃 (ms) |
| `NODE_OPTIONS` | `--max-old-space-size=4096` | Node.js 메모리 설정 |

#### 도구 목록 (19개)

**코드 분석**:
| 도구 | 설명 |
|------|------|
| `query` | 자연어 코드 그래프 쿼리 |
| `semantic_search` | 의미 기반 코드 검색 |
| `analyze_code_impact` | 변경 영향 분석 |
| `analyze_hotspots` | 복잡도/커플링 핫스팟 |
| `detect_code_clones` | 중복 코드 탐지 |
| `find_similar_code` | 유사 코드 검색 |
| `suggest_refactoring` | 리팩토링 제안 |
| `cross_language_search` | 다국어 코드 검색 |
| `find_related_concepts` | 관련 개념 검색 |

**엔티티 관리**:
| 도구 | 설명 |
|------|------|
| `list_file_entities` | 파일 내 엔티티 목록 |
| `list_entity_relationships` | 엔티티 간 관계 |

**인덱스 관리**:
| 도구 | 설명 |
|------|------|
| `index` | 코드베이스 인덱싱 |
| `clean_index` | 인덱스 정리 |
| `reset_graph` | 그래프 초기화 |

**상태 조회**:
| 도구 | 설명 |
|------|------|
| `get_graph` | 그래프 조회 |
| `get_graph_stats` | 그래프 통계 |
| `get_graph_health` | 그래프 상태 |
| `get_metrics` | 메트릭 조회 |
| `get_version` | 버전 조회 |

#### 사용 예시

**영향 분석**:
```
analyze_code_impact(
  file_path: "src/auth/login.py",
  change_type: "modify"
)
```

**시맨틱 검색**:
```
semantic_search(
  query: "user authentication logic",
  limit: 10
)
```

**핫스팟 분석**:
```
analyze_hotspots(
  metric: "complexity",
  threshold: 10
)
```

---

### 2. mcp-memory-service

**역할**: 에이전트 영구 기억 저장 (doobidoo/mcp-memory-service)

**설치**:
```bash
pipx install mcp-memory-service
```

**설정**:
```json
{
  "memory": {
    "type": "stdio",
    "command": "memory",
    "args": ["server"],
    "env": {
      "MCP_MEMORY_SQLITE_PATH": ".agent/data/memory-service/memories.db"
    }
  }
}
```

**환경변수**:
| 변수 | 기본값 | 설명 |
|------|--------|------|
| `MCP_MEMORY_SQLITE_PATH` | `memories.db` | SQLite DB 파일 경로 |

#### 도구 목록

**CRUD**:
| 도구 | 설명 |
|------|------|
| `memory_store` | 기억 저장 (content + metadata) |
| `memory_update` | 기억 업데이트 |
| `memory_delete` | 기억 삭제 |

**검색**:
| 도구 | 설명 |
|------|------|
| `memory_search` | semantic/tag 기반 검색 |
| `memory_list` | 페이지네이션 기반 목록 |

**그래프/통계**:
| 도구 | 설명 |
|------|------|
| `memory_graph` | 자동 연관 관계 |
| `memory_stats` | 기억 통계 |
| `memory_quality` | AI 품질 점수 |

#### 사용 예시

**세션 요약 저장**:
```
memory_store(
  content: "## Session: Implemented auth system\n\nBuilt JWT-based authentication with refresh tokens...",
  metadata: {
    tags: "session-learnings,auth,auto",
    type: "session-summary"
  }
)
```

**기억 검색 (semantic)**:
```
memory_search(
  query: "authentication implementation",
  mode: "semantic",
  limit: 5
)
```

**기억 검색 (tag)**:
```
memory_search(
  query: "pattern",
  tags: ["pattern", "convention"]
)
```

---

### 3. context7

**역할**: 라이브러리 문서 조회

**설정**:
```json
{
  "context7": {
    "type": "http",
    "url": "https://mcp.context7.com/mcp",
    "headers": {
      "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
    }
  }
}
```

**환경변수**:
| 변수 | 필수 | 설명 |
|------|------|------|
| `CONTEXT7_API_KEY` | Yes | Context7 API 키 |

**API 키 발급**: https://context7.com

#### 도구 목록

| 도구 | 설명 |
|------|------|
| `resolve-library-id` | 라이브러리 ID 조회 |
| `query-docs` | 라이브러리 문서 검색 |

#### 주의사항

- API 키가 없으면 MCP 서버 로드 실패
- 플러그인 빌드 시 기본적으로 제외됨
- 사용하려면 프로젝트 `.mcp.json`에 직접 추가 필요

---

## 환경변수 설정

### 방법 1: 셸 프로파일

```bash
# ~/.zshrc 또는 ~/.bashrc
export CONTEXT7_API_KEY="your-api-key-here"
```

### 방법 2: direnv (권장)

```bash
# .envrc
export CONTEXT7_API_KEY="your-api-key-here"
```

```bash
direnv allow
```

### 방법 3: .env 파일

```bash
# .env (gitignore에 포함)
CONTEXT7_API_KEY=your-api-key-here
```

---

## MCP 서버 상태 확인

### Make 명령어

```bash
make status
```

**출력 예시**:
```
=== MCP Server Status ===

graph-code:
  Status: Running
  Version: 1.2.3
  Indexed: 1234 files

memory:
  Status: Running
  Memories: 56

context7:
  Status: Not configured (CONTEXT7_API_KEY missing)
```

### 수동 확인

```bash
# graph-code
npx -y @er77/code-graph-rag-mcp --version

# mcp-memory-service
memory --version
```

---

## 인덱싱

### 초기 인덱싱

```bash
make index
```

### 수동 인덱싱

```bash
npx -y @er77/code-graph-rag-mcp index .
```

### 인덱스 정리

```bash
make clean
```

---

## 플러그인에서의 MCP

플러그인에서 MCP를 사용할 때 경로 조정이 필요합니다.

### 경로 변환

| 프로젝트 | 플러그인 |
|----------|----------|
| `"."` | `"${CLAUDE_PROJECT_DIR:-.}"` |

### 플러그인 .mcp.json

```json
{
  "mcpServers": {
    "graph-code": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "-y",
        "@er77/code-graph-rag-mcp",
        "${CLAUDE_PROJECT_DIR:-.}"
      ],
      "env": {
        "MCP_TIMEOUT": "80000",
        "NODE_OPTIONS": "--max-old-space-size=4096"
      }
    },
    "memory": {
      "type": "stdio",
      "command": "memory",
      "args": ["server"],
      "env": {
        "MCP_MEMORY_SQLITE_PATH": "${CLAUDE_PROJECT_DIR:-.}/.agent/data/memory-service/memories.db"
      }
    }
  }
}
```

### context7 수동 추가

플러그인 빌드에서 context7은 제외됩니다. 사용하려면 프로젝트 `.mcp.json`에 직접 추가:

```json
{
  "mcpServers": {
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

---

## Troubleshooting

### graph-code 연결 실패

```bash
# 버전 확인
npx -y @er77/code-graph-rag-mcp --version

# 메모리 부족 시
NODE_OPTIONS="--max-old-space-size=4096" npx -y @er77/code-graph-rag-mcp index .
```

### mcp-memory-service 연결 실패

```bash
# 설치 확인
which memory
memory --version

# 재설치
pipx reinstall mcp-memory-service
```

### context7 API 키 오류

```bash
# 환경변수 확인
echo $CONTEXT7_API_KEY

# direnv 활성화
direnv allow
```

---

## 관련 문서

- [Hooks 상세](./HOOKS.md) — MCP 도구를 사용하는 훅
- [Skills 상세](./SKILLS.md) — MCP 도구를 사용하는 스킬
- [환경변수 설정](../README.md#환경변수) — 환경변수 설정 방법
