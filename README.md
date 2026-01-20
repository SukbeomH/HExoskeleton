# 🧠 OmniGraph Framework

**Hierarchical Hybrid RAG Framework with Local + Global Knowledge Graphs**

> **Version**: 1.2.0
> **Principle**: "Don't Reinvent the Wheel" — 검증된 표준과 최신 라이브러리 활용
> **Stack**: LangChain v1.2+ / LangGraph / MCP Protocol / langchain-mcp-adapters

---

## 📋 Overview

OmniGraph는 **로컬(CodeGraph)** 과 **글로벌(Neo4j)** 지식 그래프를 연결하는 **계층형 하이브리드 RAG 프레임워크**입니다.

### 핵심 가치
- 🎯 **Fast/Slow Thinking**: 로컬(즉시) + 글로벌(심층) 하이브리드 추론
- 🔗 **URN 기반 식별**: 로컬/글로벌 엔티티의 체계적 관리
- 📝 **GSD 문서 주도**: SPEC → PLAN → Execution의 명확한 흐름
- 🛡️ **Human-in-the-Loop**: 민감한 작업 전 승인 게이트

---

## 🏗️ 프로젝트 구조

```
OmniGraph/
├── 📂 project-template/         # [Local Spoke] 개발자 IDE 템플릿
│   ├── .github/agents/          # GitHub 표준 에이전트 정의
│   │   └── agent.md             # 6-Core 영역 (Role, Cmds, Boundaries 등)
│   ├── .claude/skills/          # Anthropic 표준 스킬 정의
│   │   ├── impact-analysis/     # 영향도 분석 스킬
│   │   └── arch-review/         # 아키텍처 검토 스킬
│   ├── .agent/                   # Context Layer (레거시 호환)
│   └── mcp/                      # 로컬 MCP 서버 구성
│
├── 📂 platform-core/            # [Global Hub] 중앙 통합 엔진
│   ├── orchestration/           # LangGraph 에이전트
│   │   ├── graph_v2.py          # Command 패턴 워크플로우
│   │   ├── mcp_client.py        # langchain-mcp-adapters 클라이언트
│   │   └── state.py             # TypedDict 상태 정의
│   ├── graph-db/                # Neo4j 스키마
│   └── docker-compose.yml       # Neo4j + NeoDash
│
├── 📂 mcp/                      # MCP 서버 Docker 구성
│   └── docker-compose.mcp.yml   # Serena, Codanna, Shrimp, Context7
│
├── 📂 shared-libs/              # 공유 유틸리티
│   └── urn_manager.py           # URN 생성 및 파싱
│
├── .gsd/                         # GSD 상태 관리
└── OMNIGRAPH_SPEC.md            # ✨ 완전한 명세서
```

---

## 🚀 빠른 시작

### 1. 의존성 설치
```bash
cd platform-core
pip install -r requirements.txt
```

### 2. MCP 서버 실행
```bash
cd mcp && docker-compose -f docker-compose.mcp.yml up -d
```

### 3. 에이전트 테스트
```bash
python -m orchestration.graph_v2
```

---

## 📚 Documentation

| 문서 | 설명 |
|------|------|
| [OMNIGRAPH_SPEC.md](./OMNIGRAPH_SPEC.md) | 완전한 프레임워크 명세서 |
| [.github/agents/agent.md](./project-template/.github/agents/agent.md) | 에이전트 6-Core 스펙 |
| [.gsd/STATE.md](./.gsd/STATE.md) | 현재 프로젝트 상태 |

---

## 🔧 v1.2 개선 사항

| 영역 | Before | After |
|------|--------|-------|
| **MCP 연결** | Custom wrapping | `langchain-mcp-adapters` |
| **워크플로우** | 조건부 엣지 | LangGraph `Command` 패턴 |
| **스킬 정의** | 단순 마크다운 | YAML Frontmatter `SKILL.md` |
| **컨텍스트** | 임의 포맷 | 6-Core `agent.md` |

---

## 📝 License

MIT License
