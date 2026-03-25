# RESEARCH: Claude Code를 MCP 서버로 제공하는 아이디어 평가

**작성일**: 2026-01-29
**상태**: COMPLETED
**참조**:
- https://code.claude.com/docs/en/mcp#use-claude-code-as-an-mcp-server
- https://code.claude.com/docs/ko/headless
- https://platform.claude.com/docs/ko/agent-sdk/python

**요약**: `claude mcp serve`는 내장 도구만 노출하여 비추천. **Agent SDK 기반 API화**가 권장 대안 (섹션 5).

---

## 1. 개요

### 1.1 배경

Claude Code는 `claude mcp serve` 명령을 통해 자기 자신을 MCP(Model Context Protocol) 서버로 기동할 수 있다. 이를 통해 다른 MCP 클라이언트(Claude Desktop, 커스텀 에이전트 등)가 Claude Code의 도구를 사용할 수 있다.

### 1.2 평가 대상

현재 보일러플레이트가 구성한 Claude Code 환경을 MCP 서버로 외부에 제공하는 아이디어의 타당성 및 실용성 평가.

### 1.3 현재 보일러플레이트 MCP 구성

| 서버 | 전송방식 | 도구 수 | 용도 |
|------|----------|---------|------|
| graph-code | stdio | 19개 | AST 기반 코드 분석 (Tree-sitter + SQLite) |
| memorygraph | stdio | 12개 | 에이전트 영속 메모리 |
| context7 | HTTP | 2개 | 라이브러리 문서 조회 |

**총 33개 MCP 도구** 사용 가능.

---

## 2. `claude mcp serve` 기능 분석

### 2.1 사용법

```bash
# Claude Code를 stdio MCP 서버로 기동
claude mcp serve
```

### 2.2 Claude Desktop 연동 설정 예시

```json
{
  "mcpServers": {
    "claude-code": {
      "type": "stdio",
      "command": "claude",
      "args": ["mcp", "serve"],
      "env": {}
    }
  }
}
```

### 2.3 노출되는 도구

`claude mcp serve`는 **Claude Code의 내장 도구만** 노출한다:

- View (파일 읽기)
- Edit (파일 편집)
- LS (디렉터리 목록)
- Bash (명령 실행)
- Write (파일 쓰기)
- 기타 내장 도구

**중요**: 프로젝트에 구성된 MCP 서버들(graph-code, memorygraph, context7)의 도구는 **노출되지 않는다**.

### 2.4 공식 문서 검증 결과

> **검증일**: 2026-01-29
> **출처**: https://code.claude.com/docs/en/mcp, GitHub Issue #631

#### 2.4.1 MCP Passthrough 부재 (확인됨)

공식 문서에서 명시적으로 다음을 확인:

> "**There is no MCP passthrough.** If Claude Code connects to a GitHub MCP server, clients connecting to Claude Code can't use those GitHub tools directly."

즉, `claude mcp serve`는 **Claude Code 자체의 도구만 노출**하며, 프로젝트에 구성된 MCP 서버(graph-code, memorygraph, context7)는 외부 클라이언트에서 접근할 수 없다.

#### 2.4.2 보안 책임 전가 (확인됨)

공식 문서:

> "Note that this MCP server is only exposing Claude Code's tools to your MCP client, so **your own client is responsible for implementing user confirmation** for individual tool calls."

#### 2.4.3 관련 보안 이슈 (2026-01-20)

- **Git MCP 경로 검증 우회 취약점** 발견 (The Register 보도)
- Filesystem MCP와 체이닝하여 코드 실행 가능한 취약점
- Anthropic이 조용히 수정했으나, MCP 서버 거버넌스 우려 부각

---

## 3. 평가

### 3.1 긍정적 측면

#### 3.1.1 멀티 에이전트 오케스트레이션 가능성

- Claude Desktop이나 다른 에이전트가 이 보일러플레이트 환경의 Claude Code를 도구로 사용 가능
- "에이전트가 에이전트를 호출하는" 계층 구조를 MCP 표준으로 구현 가능
- 에이전트 간 역할 분담 아키텍처의 기반이 될 수 있음

#### 3.1.2 팀 환경에서의 활용 잠재력

- 보일러플레이트가 구성된 환경(skills, workflows, GSD 문서)을 다른 도구에서 간접적으로 활용 가능
- Claude Desktop 사용자가 코드 편집 작업을 Claude Code에 위임하는 시나리오 가능

#### 3.1.3 MCP 생태계 철학과의 일치

- 합성 가능성(composability) 원칙에 부합
- 표준 프로토콜 기반으로 도구 연결

### 3.2 제약 및 우려사항

#### 3.2.1 노출되는 도구 범위의 제한 (Critical)

| 구분 | 노출 여부 | 비고 |
|------|----------|------|
| Claude Code 내장 도구 | O | View, Edit, LS, Bash 등 |
| graph-code (19개) | X | AST 분석, 코드 임팩트 분석 |
| memorygraph (12개) | X | 에이전트 메모리 |
| context7 (2개) | X | 라이브러리 문서 |

**결론**: 이 보일러플레이트의 핵심 가치인 33개 MCP 도구가 외부에 노출되지 않아, 연결하는 클라이언트는 보일러플레이트의 차별점을 활용할 수 없다.

#### 3.2.2 비용 및 레이턴시 증폭

```
외부 에이전트 → Claude Code MCP → (내부 LLM 추론) → 결과 반환
     ↓                                    ↓
  토큰 소모 1                          토큰 소모 2
```

- MCP를 통한 각 호출이 Claude Code 세션을 경유하므로 **LLM API 호출이 이중으로 발생**
- 단순한 파일 읽기도 LLM 토큰을 소모하게 되어 비용 대비 효율이 낮음
- 레이턴시도 Claude Code의 추론 시간만큼 추가됨

#### 3.2.3 보안 표면 확대

- Bash, Edit, Write 등의 도구가 외부 클라이언트에 노출됨
- **사용자 확인(user confirmation) 책임이 연결하는 클라이언트 측에 있음** (공식 문서 명시)
- 보일러플레이트의 보안 규칙이 외부 클라이언트에는 적용되지 않음:
  - "Never read `.env` or credential files"
  - "Never use `--dangerously-skip-permissions` outside containers"

#### 3.2.4 아키텍처 미스매치

| 현재 설계 | MCP 서버 노출 시 |
|----------|-----------------|
| 단일 개발자/에이전트가 직접 사용 | 도구 제공 플랫폼으로 성격 변화 |
| 자기완결적 환경 | 외부 의존성 발생 |
| GSD 워크플로우 중심 | 도구 호출 API 중심 |

### 3.3 대안 비교

| 목적 | `claude mcp serve` | 더 나은 대안 |
|------|-------------------|-------------|
| 멀티 에이전트 | 기본 도구만 노출 | Claude Agent SDK로 직접 구축 |
| MCP 도구 외부 노출 | 불가 (내장 도구만) | graph-code/memorygraph를 직접 노출 (이미 가능) |
| Claude Desktop 연동 | 가능하나 제한적 | `.mcp.json`의 서버들을 Desktop에서 직접 구성 |
| 원격 팀 협업 | 지원 안 됨 (stdio 전용) | 별도 API 서버 구축 |

---

## 4. 결론

### 4.1 종합 평가

**현 단계에서는 비추천.**

| 평가 항목 | 점수 | 근거 |
|----------|------|------|
| 아키텍처 적합성 | 낮음 | 보일러플레이트의 자기완결적 설계와 충돌 |
| 실용적 가치 | 낮음 | 핵심 MCP 도구(33개)가 노출되지 않음 |
| 비용 효율 | 낮음 | LLM 토큰 이중 소모 |
| 보안 | 우려 | 외부 클라이언트의 보안 책임 전가 |
| 구현 복잡도 | 낮음 | 단순히 `claude mcp serve` 실행 |

### 4.2 주요 이유

1. **가치 미전달**: 이 보일러플레이트의 차별점인 graph-code, memorygraph, context7 도구가 `claude mcp serve`를 통해서는 노출되지 않아, 외부에서 접근해도 보일러플레이트 고유의 가치를 활용할 수 없다.

2. **불필요한 중복**: Claude Code의 내장 도구(View, Edit 등)만 필요하다면, 외부 클라이언트가 직접 `claude mcp serve`를 실행하면 되므로 보일러플레이트에 이를 구성할 이유가 없다.

3. **비용 비효율**: 비용(LLM 토큰 이중 소모)과 레이턴시가 증가하는 반면, 추가 가치가 불명확하다.

### 4.3 대안 제안

보다 가치 있는 방향:

1. **MCP 서버 직접 노출 가이드**: graph-code, memorygraph 등 MCP 서버들을 외부(Claude Desktop 등)에서 직접 연결하는 방법을 보일러플레이트에 문서화

2. **Claude Agent SDK 기반 API화** ⭐ **권장**: 이 보일러플레이트의 skills/workflows를 Claude Agent SDK로 래핑하여 API 서비스로 제공하는 별도 프로젝트 → **섹션 5에서 상세 분석**

3. **커스텀 MCP 서버 구축**: 보일러플레이트의 특화 기능(GSD 워크플로우, skills 등)을 노출하는 전용 MCP 서버 개발

---

## 5. 대안 심층 분석: Claude Agent SDK 기반 API화

> **추가 조사일**: 2026-01-29
> **참조**: https://code.claude.com/docs/ko/headless, https://platform.claude.com/docs/ko/agent-sdk/python

### 5.1 Agent SDK 개요

Claude Agent SDK는 Claude Code를 프로그래밍 방식으로 제어할 수 있는 Python/TypeScript 패키지다. `claude mcp serve`와 달리, **MCP 서버를 직접 통합**하여 사용할 수 있다.

#### 설치

```bash
# Python
pip install claude-agent-sdk

# TypeScript
npm install @anthropic-ai/claude-agent-sdk
```

#### 주요 인터페이스

| 인터페이스 | 용도 | 세션 관리 |
|------------|------|----------|
| `query()` | 일회성 작업 | 매번 새 세션 |
| `ClaudeSDKClient` | 지속적 대화 | 세션 유지 |

#### CLI 헤드리스 모드 (`claude -p`)

SDK 외에도 CLI에서 직접 프로그래밍 방식으로 실행 가능:

```bash
# 기본 사용
claude -p "Find and fix the bug in auth.py" --allowedTools "Read,Edit,Bash"

# JSON 출력
claude -p "Summarize this project" --output-format json

# 세션 계속
claude -p "Now focus on database queries" --continue
```

### 5.2 핵심 발견: MCP 서버 직접 통합 가능

`ClaudeAgentOptions`의 `mcp_servers` 옵션을 통해 **기존 `.mcp.json` 설정을 그대로 사용**할 수 있다:

```python
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions

options = ClaudeAgentOptions(
    # 방법 1: 기존 .mcp.json 파일 경로 전달
    mcp_servers="/path/to/boilerplate/.mcp.json",

    # 방법 2: 직접 구성
    # mcp_servers={
    #     "graph-code": {"command": "npx", "args": ["-y", "@er77/code-graph-rag-mcp"]},
    #     "memorygraph": {"command": "npx", "args": ["-y", "memorygraph-server"]}
    # },

    allowed_tools=[
        "mcp__graph-code__query",
        "mcp__graph-code__analyze_code_impact",
        "mcp__graph-code__semantic_search",
        "mcp__memorygraph__store_memory",
        "mcp__memorygraph__recall_memories",
        # ... 33개 MCP 도구 모두 지정 가능
    ],
    permission_mode="bypassPermissions"
)
```

### 5.3 `claude mcp serve` vs Agent SDK 비교

| 측면 | `claude mcp serve` | Agent SDK |
|------|-------------------|-----------|
| MCP 서버 노출 | ❌ 내장 도구만 | ✅ **모든 MCP 서버 통합 가능** |
| LLM 추론 | ❌ 도구 인터페이스만 | ✅ 완전한 에이전트 루프 |
| 프로그래밍 제어 | stdio MCP만 | Python/TypeScript API |
| 비용 구조 | 이중 LLM 호출 | **단일 LLM 호출** |
| 훅/권한 제어 | 제한적 | ✅ `can_use_tool`, hooks |
| 구조화된 출력 | 없음 | ✅ JSON Schema 지원 |

### 5.4 적용 가능한 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│  FastAPI / Flask 서버 (보일러플레이트 API화)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Claude Agent SDK (ClaudeSDKClient)                 │   │
│  │  - mcp_servers: .mcp.json 로드                      │   │
│  │  - allowed_tools: 33개 MCP 도구                     │   │
│  │  - hooks: 보안/감사 로직                            │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│  ┌────────────────────────▼────────────────────────────┐   │
│  │  MCP 서버들 (기존 .mcp.json 그대로 사용)             │   │
│  │  - graph-code (19개 도구)                           │   │
│  │  - memorygraph (12개 도구)                          │   │
│  │  - context7 (2개 도구)                              │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
              외부 클라이언트 (REST API)
```

### 5.5 최소 구현 예시

```python
# boilerplate_api.py
from fastapi import FastAPI
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions, ResultMessage
from pathlib import Path

app = FastAPI()
BOILERPLATE_ROOT = Path("/path/to/boilerplate")

@app.post("/analyze")
async def analyze_code(request: dict):
    """코드 분석 API - graph-code MCP 도구 활용"""
    options = ClaudeAgentOptions(
        mcp_servers=str(BOILERPLATE_ROOT / ".mcp.json"),
        allowed_tools=[
            "mcp__graph-code__query",
            "mcp__graph-code__analyze_code_impact",
            "mcp__graph-code__semantic_search",
            "mcp__graph-code__find_similar_code",
        ],
        permission_mode="bypassPermissions",
        cwd=request.get("project_path", str(BOILERPLATE_ROOT))
    )

    async with ClaudeSDKClient(options=options) as client:
        await client.query(request["prompt"])

        result = None
        async for message in client.receive_response():
            if isinstance(message, ResultMessage):
                result = message

        return {
            "result": result.result if result else None,
            "cost_usd": result.total_cost_usd if result else None,
            "session_id": result.session_id if result else None
        }

@app.post("/memory")
async def memory_operations(request: dict):
    """에이전트 메모리 API - memorygraph MCP 도구 활용"""
    options = ClaudeAgentOptions(
        mcp_servers=str(BOILERPLATE_ROOT / ".mcp.json"),
        allowed_tools=[
            "mcp__memorygraph__store_memory",
            "mcp__memorygraph__recall_memories",
            "mcp__memorygraph__search_memories",
            "mcp__memorygraph__contextual_search",
        ],
        permission_mode="bypassPermissions"
    )

    async with ClaudeSDKClient(options=options) as client:
        await client.query(request["prompt"])

        async for message in client.receive_response():
            if isinstance(message, ResultMessage):
                return {"result": message.result}

        return {"error": "No result received"}
```

### 5.6 보안 제어: 훅 시스템

Agent SDK는 도구 실행 전후에 커스텀 로직을 삽입할 수 있는 훅 시스템을 제공한다:

```python
from claude_agent_sdk import ClaudeAgentOptions, HookMatcher, HookContext
from typing import Any

async def audit_tool_use(
    input_data: dict[str, Any],
    tool_use_id: str | None,
    context: HookContext
) -> dict[str, Any]:
    """모든 도구 사용을 감사 로그에 기록"""
    tool_name = input_data.get('tool_name', 'unknown')
    print(f"[AUDIT] Tool: {tool_name}, Input: {input_data.get('tool_input')}")
    return {}

async def block_dangerous_commands(
    input_data: dict[str, Any],
    tool_use_id: str | None,
    context: HookContext
) -> dict[str, Any]:
    """위험한 Bash 명령 차단"""
    if input_data.get('tool_name') == 'Bash':
        command = input_data.get('tool_input', {}).get('command', '')
        dangerous_patterns = ['rm -rf', 'DROP TABLE', 'DELETE FROM']

        for pattern in dangerous_patterns:
            if pattern in command:
                return {
                    'hookSpecificOutput': {
                        'hookEventName': 'PreToolUse',
                        'permissionDecision': 'deny',
                        'permissionDecisionReason': f'Blocked: {pattern}'
                    }
                }
    return {}

options = ClaudeAgentOptions(
    hooks={
        'PreToolUse': [
            HookMatcher(hooks=[audit_tool_use]),
            HookMatcher(matcher='Bash', hooks=[block_dangerous_commands])
        ]
    }
)
```

### 5.7 Agent SDK 기반 API화 평가

| 평가 항목 | 점수 | 근거 |
|----------|------|------|
| 아키텍처 적합성 | **높음** | MCP 서버 직접 통합으로 보일러플레이트 가치 완전 노출 |
| 실용적 가치 | **높음** | 33개 MCP 도구 모두 API로 제공 가능 |
| 비용 효율 | **높음** | 단일 LLM 호출로 처리 |
| 보안 | **양호** | 훅 시스템으로 세밀한 제어 가능 |
| 구현 복잡도 | 중간 | SDK 학습 + API 서버 구축 필요 |

### 5.8 Agent SDK 접근법 결론

**`claude mcp serve`의 한계를 완전히 해결하는 권장 대안이다.**

1. **가치 전달**: 33개 MCP 도구가 모두 외부에 노출됨
2. **비용 효율**: 단일 LLM 호출 구조
3. **보안 제어**: 훅 시스템으로 감사/차단 로직 구현 가능
4. **확장성**: REST API로 래핑하여 팀/외부 서비스에 제공 가능

---

## 6. 다음 단계 (Action Items)

Agent SDK 기반 API화를 진행할 경우:

### 6.1 즉시 실행 가능

1. **PoC 구현**: `boilerplate_api.py` 예제 기반으로 FastAPI 서버 생성
2. **MCP 도구 매핑**: 33개 도구를 API 엔드포인트로 그룹화
3. **인증 추가**: API 키 또는 OAuth 기반 접근 제어

### 6.2 추가 고려사항

| 항목 | 설명 | 우선순위 |
|------|------|----------|
| 요금제 설계 | API 호출당 비용 또는 구독 모델 | 높음 |
| 레이트 리밋 | 사용자별 호출 제한 | 높음 |
| 로깅/모니터링 | 사용량 추적, 에러 모니터링 | 중간 |
| 캐싱 전략 | 반복 쿼리에 대한 응답 캐싱 | 낮음 |

### 6.3 별도 프로젝트 권장

이 API 서버는 보일러플레이트 자체가 아닌 **별도 프로젝트**로 구현 권장:
- 보일러플레이트는 개발 환경으로 유지
- API 서버는 프로덕션 서비스로 분리
- `.mcp.json`만 공유하거나 복사

---

## 7. 참고 자료

- [Claude Code MCP 문서](https://code.claude.com/docs/en/mcp)
- [Claude Code Headless Mode](https://code.claude.com/docs/ko/headless)
- [Claude Agent SDK - Python](https://platform.claude.com/docs/ko/agent-sdk/python)
- [Model Context Protocol 공식 사이트](https://modelcontextprotocol.io/introduction)
- 프로젝트 MCP 구성: `.mcp.json`
- 에이전트 명세: `.github/agents/agent.md`
