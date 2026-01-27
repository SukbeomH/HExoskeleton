# Developer Boilerplate

AI 에이전트 기반 개발을 위한 경량 프로젝트 보일러플레이트. CodeGraph AST 인덱싱과 GSD(Get Shit Done) 문서 기반 방법론을 결합하여 구조화된 개발 워크플로우를 제공합니다.

## 디렉토리 구조

```
.
├── .agent/            — 에이전트 설정 (symlinks, GSD 워크플로우)
├── .claude/           — Claude Code 스킬 및 설정
├── .gemini/           — Gemini 설정
├── .github/           — GitHub 에이전트 스펙 & 이슈 템플릿
├── .gsd/              — GSD 문서, 템플릿, 예제
├── .specs/            — 프로젝트 명세 (SPEC, PLAN, DECISIONS)
├── mcp/               — 로컬 MCP 서버 설정
├── scripts/           — 유틸리티 스크립트
├── .env.example       — 환경변수 템플릿
├── codegraph.toml     — CodeGraph 설정
├── Vagrantfile        — Vagrant VM 설정
└── CLAUDE.md          — Claude Code 지침
```

## Quick Start

### 1. 환경 설정

```bash
cp .env.example .env
# .env 파일에서 PROJECT_ID 수정
```

### 2. CodeGraph 설치 및 인덱싱

[codegraph-rust](https://github.com/Jakedismo/codegraph-rust) 설치 후:

```bash
# 코드베이스 인덱싱
codegraph index . -r -l python,typescript,rust

# MCP 서버 시작 (stdio, auto-reload)
codegraph start stdio --watch
```

### 3. GSD 워크플로우

```
/new-project    → SPEC.md 작성
/plan           → 페이즈별 실행 계획 생성
/execute        → 웨이브 단위 구현 (atomic commits)
/verify         → 필수 요구사항 검증
```

전체 25개 명령어: `/help` 참조

### 4. 스펙 검증

```bash
python scripts/validate_spec.py
```

## 에이전트 설정

| 에이전트 | 설정 파일 |
|----------|-----------|
| **GitHub Agents** | `.github/agents/agent.md` |
| **Claude Code** | `.claude/skills/`, `CLAUDE.md` |
| **Gemini** | `.gemini/GEMINI.md` |

## 핵심 도구

- **CodeGraph**: 로컬 AST 인덱싱 (7개 agentic 도구 제공)
- **MCP Protocol**: Model Context Protocol 기반 도구 통합
- **GSD**: 문서 기반 개발 방법론 (SPEC → PLAN → DECISIONS)

## URN 체계

```
urn:local:{project_id}:{file_path}:{symbol}
```

## 사용자 정의

이 보일러플레이트를 프로젝트에 맞게 수정하세요:

1. `.env.example` — `PROJECT_ID` 설정
2. `codegraph.toml` — 인덱싱 대상 언어/경로 조정
3. `.specs/SPEC.md` — 프로젝트 요구사항 정의
4. `mcp/config.json` — MCP 서버 설정
