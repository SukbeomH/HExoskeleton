---
title: 멀티홉 워크플로우 토큰 최적화 리서치
date: 2026-04-15
status: active
category: workflow
related: RESEARCH-github-task-management-workflow.md
---

# 멀티홉 워크플로우 토큰 최적화

> 목적: GATES→Dispatcher→Sub-agent 3-레이어 멀티홉에서 토큰 소모 최소화 전략 (2026-04-15)

---

## 1. 핵심 문제: 컨텍스트 폭발

멀티에이전트 구현은 단일 에이전트 대비 **3-10x 토큰 소모**:
- 에이전트 간 컨텍스트 복제
- 조율 메시지 오버헤드
- 결과 요약 핸드오프

**Context Rot**: 컨텍스트 창이 커질수록 모델의 정보 회상 정확도 저하.

출처: [Stop Wasting Your Tokens: Runtime Multi-Agent Systems](https://arxiv.org/html/2510.26585v1)

---

## 2. 핵심 최적화 기법

### 2-1. Minimal Context Handoff (가장 중요)

> "include_contents: none 모드에서 서브에이전트는 이전 대화 내역을 전혀 받지 않는다. 새 프롬프트만 받는다."

**HXSK 적용**:
- HOP 1→2: GATES가 Dispatcher에 전달하는 것 = PLAN.md 경로 + 파일 소유권 맵만
- HOP 2→3: Dispatcher가 Sub-agent에 전달하는 것 = WORK 문서 경로만
- 전체 대화 내역 절대 전달 금지

출처:
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Anthropic multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)

### 2-2. CodeAgents 구조화 프롬프트

입력 토큰 55-87%, 출력 토큰 41-70% 감소:
- 에이전트 프롬프트를 코드형(구조화) 포맷으로 작성
- 자연어 설명 대신 필드 기반 명세

**HXSK 적용**: WORK 문서를 YAML frontmatter + 최소 본문으로 구조화

출처: [CodeAgents: Token-Efficient Multi-Agent Reasoning](https://arxiv.org/html/2507.03254v1)

### 2-3. Chain-of-Agents (요약 전달)

- 각 홉에서 이전 홉의 전체 출력 대신 **요약만** 전달
- 서브에이전트 완료 보고 = 커밋 해시 + Self-review 테이블 (전체 출력 금지)

출처: [Chain of Agents - Google Research](https://research.google/blog/chain-of-agents-large-language-models-collaborating-on-long-context-tasks/)

### 2-4. 로컬 데이터, 메타데이터만 전달

> "데이터를 로컬에 두고 LLM에는 스키마와 메타데이터만 전달"

**HXSK 적용**:
- 파일 내용을 프롬프트에 포함하지 말고 경로만 전달 → 에이전트가 Read 도구로 직접 읽기
- WORK 문서에 파일 내용 포함 금지, 파일 경로만 포함

출처: [Solace Agent Mesh Context Engineering](https://solace.com/blog/context-engineering-solace-agent-mesh/)

### 2-5. 컨텍스트 격리 (워크트리 기반)

- 각 Sub-agent는 독립 컨텍스트 창 사용
- 워크트리가 물리적 격리 제공 → 컨텍스트 오염 방지
- Claude Code: 최대 10개 병렬 서브에이전트 지원

출처: [Claude Code Sub-Agents Best Practices](https://claudefa.st/blog/guide/agents/sub-agent-best-practices)

---

## 3. HXSK 멀티홉 토큰 최적화 전략

### HOP 1 (GATES): 컨텍스트 최소 유지

| 전략 | 방법 |
|------|------|
| 게이트 상태를 STATE.md에 저장 | 세션 재시작 시 재로드 (대화 내역 불필요) |
| 이슈 번호만 STATE.md에 기록 | 이슈 내용은 `gh issue view N`으로 필요 시 로드 |
| PLAN.md 경로만 Dispatcher에 전달 | PLAN.md 내용 포함 금지 |

### HOP 2 (Dispatcher): WORK 문서 최소화

```yaml
# WORK 문서 최적 포맷 (토큰 최소화)
---
id: WORK-001
master: MASTER-001
wave: 1
status: pending
branch: task/xxx-1
sub_issue: 43
files:
  - src/auth/login.ts
  - src/auth/types.ts
side_effect_files:
  - src/index.ts
---
## Tasks
- [ ] POST /api/login 엔드포인트 구현
- [ ] JWT 토큰 생성 로직 추가
```

Sub-agent 프롬프트에 포함 금지:
- ❌ 파일 내용
- ❌ 이전 WORK 결과
- ❌ MASTER 전체 내용
- ✅ WORK 문서 경로만

### HOP 3 (Sub-agent): 완료 보고 최소화

```
# 완료 보고 포맷 (최소)
WORK: WORK-001
STATUS: done
COMMITS: abc1234, def5678
SELF_REVIEW:
  A: PASS  B: PASS  C: PASS  D: N/A  E: PASS
DECISIONS: none
```

전체 구현 설명, 코드 설명 불필요.

---

## 4. 절감 추정

| 구간 | 현재 (추정) | 최적화 후 | 절감 |
|------|------------|-----------|------|
| HOP 1→2 핸드오프 | 전체 대화 | 경로+맵만 | ~70% |
| HOP 2→3 프롬프트 | 자연어 설명 | 구조화 WORK 문서 | ~55-87% |
| HOP 3 완료 보고 | 전체 출력 | 요약 테이블 | ~80% |
| 전체 세션 | 기준 | 최적화 | ~60-75% |

---

## 출처

- [Effective context engineering for AI agents - Anthropic](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [CodeAgents: Token-Efficient Multi-Agent Reasoning](https://arxiv.org/html/2507.03254v1)
- [Stop Wasting Your Tokens: Runtime Multi-Agent Systems](https://arxiv.org/html/2510.26585v1)
- [Chain of Agents - Google Research](https://research.google/blog/chain-of-agents-large-language-models-collaborating-on-long-context-tasks/)
- [Solace Agent Mesh Context Engineering](https://solace.com/blog/context-engineering-solace-agent-mesh/)
- [Create custom subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Anthropic multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system)
- [LLM Token Optimization 2026 - Redis](https://redis.io/blog/llm-token-optimization-speed-up-apps/)
