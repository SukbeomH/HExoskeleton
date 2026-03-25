# AGENTS.md & Agentic Engineering 최신 연구 트렌드 (2026-03)

> **조사일**: 2026-03-04
> **출처**: Addy Osmani, Andrej Karpathy, flowkater, ETH Zurich, ICLR 2026 ACE 논문, agents.md 공식 사양

---

## 목차

1. [AGENTS.md 자동 생성의 함정](#1-agentsmd-자동-생성의-함정)
2. [AGENTS.md 공식 사양 현황](#2-agentsmd-공식-사양-현황)
3. [ACE 프레임워크 — 동적 컨텍스트 진화](#3-ace-프레임워크--동적-컨텍스트-진화)
4. [Karpathy의 Agentic Engineering 선언](#4-karpathy의-agentic-engineering-선언)
5. [에이전틱 엔지니어링 9대 생존 스킬](#5-에이전틱-엔지니어링-9대-생존-스킬)
6. [HXSK 보일러플레이트 시사점](#6-hxsk-보일러플레이트-시사점)
7. [출처](#7-출처)

---

## 1. AGENTS.md 자동 생성의 함정

### Addy Osmani의 핵심 주장

> "Stop Using /init for AGENTS.md — 오히려 비용만 20% 늘어남"

**실험 데이터 (ETH Zurich, SWE-bench)**:

| 생성 방식 | 성공률 변화 | 비용 변화 |
|-----------|-----------|----------|
| LLM 자동 생성 (`/init`) | -2~3% 하락 | +20% 이상 증가 |
| 개발자 직접 작성 | +4% 향상 | +19% 증가 |
| 기존 문서 없는 환경에서 LLM 생성 | +2.7% 향상 | 측정 미기재 |

**Lulla et al. (ICSE JAWs 2026)** — 124개 GitHub PR 분석:
- 개발자 유지보수 AGENTS.md: **실행 시간 28.64% 감소**, **토큰 16.58% 감소**

### 문제의 근본 원인

1. **Anchoring Effect**: 불필요한 정보가 모델의 주의를 분산
2. **중복 정보 노이즈**: 에이전트가 코드에서 스스로 발견 가능한 정보를 반복 제공
3. **Lost in the Middle** (Liu et al.): 긴 컨텍스트가 오히려 성능 저하 유발
4. **정적 파일의 한계**: 단일 파일은 작업 유형별 조건 분기가 불가능

### 포함 vs 제외 기준

**포함해야 할 것** (에이전트가 발견 불가능):
- 비직관적 도구 지정 및 사용 규칙 (예: `uv` 사용 필수)
- 시스템 제약사항, 함정(landmines)
- 폐기된 패턴 경고 ("이 방식은 쓰지 마라")
- 비표준 패턴

**제외해야 할 것** (에이전트가 스스로 발견 가능):
- 디렉토리 구조
- 기술 스택
- 표준 아키텍처 패턴

### 권장 3계층 아키텍처

```
Layer 1: 프로토콜 파일 — 라우팅, 페르소나, 핵심 사실만
Layer 2: 집중 파일 — 작업 타입별 선택적 로드 (스킬/페르소나)
Layer 3: 유지관리 서브에이전트 — 문서 정확성 자동 관리
```

### 핵심 인사이트

> "사람이 유용하다고 생각하는 정보와 모델이 실제로 필요한 정보는 다르다"

AGENTS.md는 영구 설정이 아닌 **진단 도구**. 추가된 각 줄은 코드베이스의 불명확한 부분을 지적하며, 근본 원인 수정이 우선.

**Arize AI 사례**: 실패 분석 기반 자동 최적화로 cross-repo +5.19%, in-repo +10.87% 개선.

---

## 2. AGENTS.md 공식 사양 현황

### 개요

- **관리**: Linux Foundation의 Agentic AI Foundation
- **채택**: 60,000+ 오픈소스 프로젝트
- **형식**: 표준 마크다운, 필수 필드 없음

### 권장 섹션

- 프로젝트 개요
- 빌드 및 테스트 명령어 (정확한 커맨드)
- 코드 스타일 가이드라인
- 테스트 지침
- 보안 고려사항
- 커밋 메시지/PR 가이드라인

### 파일 구조

- 저장소 루트에 `AGENTS.md` 생성
- 모노레포: 서브프로젝트마다 중첩 배치 가능 (가장 가까운 파일 우선)

### 지원 도구 (20개 이상)

OpenAI Codex, Google Jules, Cursor, Aider, VS Code, Devin, GitHub Copilot, Zed, Warp, Gemini CLI, Kilo Code, Phoenix 등

### Claude Code와의 관계

Claude Code는 `CLAUDE.md`를 사용하며, 이는 AGENTS.md와 동일한 역할을 수행. HXSK 보일러플레이트에서는 `CLAUDE.md`가 이 역할을 담당.

---

## 3. ACE 프레임워크 — 동적 컨텍스트 진화

### 논문 정보

- **제목**: Agentic Context Engineering: Evolving Contexts for Self-Improving Language Models
- **출처**: arXiv:2510.04618, **ICLR 2026** 채택
- **핵심**: 정적 AGENTS.md의 한계를 넘어, 컨텍스트를 동적으로 진화시키는 프레임워크

### 기존 접근의 문제점

1. **Brevity Bias**: 반복 요약 시 도메인 인사이트가 누락됨
2. **Context Collapse**: 반복적 재작성으로 세부 정보가 점차 소실됨

### ACE 3역할 구조

| 역할 | 기능 |
|------|------|
| **Generator** | 추론 궤적(reasoning trajectories) 생성 |
| **Reflector** | 성공/실패에서 구체적 인사이트 증류 |
| **Curator** | 인사이트를 구조화된 컨텍스트 업데이트로 통합 |

컨텍스트를 "evolving playbooks"로 취급 — 전략을 축적·정제·조직화하는 모듈식 프로세스.

### 실험 결과

| 벤치마크 | 성능 향상 |
|----------|----------|
| Agent 벤치마크 | **+10.6%** |
| Finance 벤치마크 | **+8.6%** |
| 정적 방법 대비 | **+12.3%** |

- AppWorld 리더보드에서 상위 에이전트와 동등 성능 (더 작은 오픈소스 모델 사용에도)
- 레이블 없는 자연 실행 피드백만으로 효과적 적응 가능

### 시사점

정적 AGENTS.md/CLAUDE.md → **동적 컨텍스트 진화 시스템**이 미래 방향. HXSK의 메모리 시스템(md-store/recall)이 이 패러다임에 부분적으로 부합.

---

## 4. Karpathy의 Agentic Engineering 선언

### Vibe Coding → Agentic Engineering 전환

**Vibe Coding** (2025-02): LLM에 코드 생성을 맡기고 결과만 수용하는 실험적 방식. 일회용 프로젝트에 적합.

**Agentic Engineering** (2026): 코드 작성의 99%를 에이전트에 위임하고, 인간은 오케스트레이션과 감독을 수행.

> "끝난 건 타이핑이지, 엔지니어링이 아니다"

### Karpathy의 작업 방식

- 로컬: 5개 Claude Code 병렬 실행
- claude.ai: 5-10개 추가 동시 실행
- 총 10-15개 병렬 세션
- 핵심: 철저한 컨텍스트 분리 (git worktree)

### 핵심 통찰

> "'agentic' because the new default is that you are not writing the code directly 99% of the time, you are orchestrating agents who do and acting as oversight."

이것이 엔지니어링을 더 쉽게 만드는 것이 아니라, "예술과 과학, 전문성"이 필요한 영역으로 만든다.

---

## 5. 에이전틱 엔지니어링 9대 생존 스킬

### 스킬 요약 (flowkater)

| # | 스킬 | 핵심 | HXSK 대응 |
|---|------|------|-----------|
| 1 | **분해 능력** | 모호한 요구를 명확한 작업 단위로 변환 | `planner` skill, SPEC.md |
| 2 | **컨텍스트 설계** | 에이전트 작동 조건을 구조화 | CLAUDE.md, Agent-Skill 래핑 |
| 3 | **완료 정의** | "완료" 기준을 에이전트에게 명확히 전달 | `verifier` skill, DoD 체크리스트 |
| 4 | **실패 복구** | 실패 유형 분류 → 맞춤형 처방 | `debugger` skill, 3-strike 규칙 |
| 5 | **관찰 가능성** | 이탈을 빠르게 감지하는 구조 | `context-health-monitor`, 예광탄 전략 |
| 6 | **메모리 설계** | 세션 간 컨텍스트 손실 방지 | `memory-protocol`, A-Mem 확장 |
| 7 | **병렬 관리** | 다중 에이전트 오케스트레이션 | git worktree, Agent 도구 |
| 8 | **추상화 계층** | 반복 작업을 스킬화해 복리 효과 | Agent-Skill 래핑 구조 |
| 9 | **감각** | AI 80% 결과를 넘어서는 판단력 | 인간 영역 (자동화 불가) |

### 핵심 사례

**분해 실패**: PRD만 제시 → 수십 턴 핑퐁 반나절 낭비 → 소크라틱 대화로 2-3턴 단축

**실패 복구 3유형**:
1. 컨텍스트 부족 → 정보 추가
2. 방향 오류 → 요구사항 재정의
3. 구조적 충돌 → 파일 격리 + 가드레일 ("이 파일은 수정하지 마", "기존 테스트 수정 금지")

**관찰 가능성**: 20개 파일 한 번에 수정 → 전체 UI 깨짐, 롤백 불가 → 예광탄 전략(1개 파일 먼저) + 단계별 커밋

**메모리 설계**: 자동 hooks로 세션 컨텍스트 추출 → CLAUDE.md 저장 → 다음 세션 5초 만에 복원 (15분 → 5초)

**추상화 4단계**:
```
Level 0: 직접 코딩
Level 1: 에이전트 지시 (Claude Code)
Level 2: 오케스트레이터 (여러 에이전트 관리)
Level 3: 메타 설계 (오케스트레이터 자동화)
```

**감각** (Chris Lattner):
> "구현 자동화가 진행될수록, 설계·판단·감각이 더 중요해진다"

### 횡단 원칙

- **반복이 신호**: 같은 일 3회 = 자동화 신호, 같은 실패 3회 = 시스템 변경 신호
- **블루프린트**: 예상 구조 명시 → 에이전트 이탈 빠르게 감지
- **점진적 확대**: 2개 에이전트부터 시작, 안정화 후 확장
- **구조가 컨텍스트다**: 문서보다 디렉토리 구조, 지침보다 코드 자체

---

## 6. HXSK 보일러플레이트 시사점

### 이미 잘 부합하는 영역

| 트렌드 | HXSK 현황 | 평가 |
|--------|----------|------|
| 3계층 아키텍처 | CLAUDE.md(L1) + Skills(L2) + Hooks(L3) | **일치** |
| 메모리 설계 | A-Mem 확장, 2-hop 검색, 자동 세션 저장 | **선도** |
| 실패 복구 | debugger skill, 3-strike 규칙 | **일치** |
| 완료 정의 | verifier skill, empirical-validation | **일치** |
| 분해 능력 | planner skill, SPEC.md → PLAN.md | **일치** |
| 추상화 계층 | Agent-Skill 래핑, 복리 효과 구조 | **일치** |

### 개선 기회

| 트렌드 | 현재 갭 | 권장 조치 |
|--------|---------|----------|
| ACE 동적 컨텍스트 | CLAUDE.md는 정적 | Generator-Reflector-Curator 패턴 도입 검토 |
| 컨텍스트 최적화 | CLAUDE.md 크기 미측정 | 토큰 비용 모니터링 + 불필요한 정보 정기 정리 |
| 관찰 가능성 강화 | diff 요약 자동 보고 미구현 | PostToolUse hook에 diff 요약 기능 추가 검토 |
| AGENTS.md 표준 호환 | CLAUDE.md 전용 | `AGENTS.md` 자동 생성 빌드 스크립트 검토 (비-Claude 도구 지원) |

### CLAUDE.md 점검 포인트 (Osmani 기준)

현재 CLAUDE.md를 아래 기준으로 점검:
- [ ] 에이전트가 코드에서 발견 가능한 정보가 포함되어 있는가? → 제거 대상
- [ ] 150-200줄 이하인가? → 초과 시 정리 필요
- [ ] 작업 유형별 분기가 스킬로 분리되어 있는가? → 현재 잘 분리됨

---

## 7. 출처

### 블로그 & 아티클
- [Addy Osmani — Stop Using /init for AGENTS.md](https://addyosmani.com/blog/agents-md/)
- [GeekNews — /init으로 AGENTS.md 자동 생성하지 마라](https://news.hada.io/topic?id=26972)
- [flowkater — 에이전틱 엔지니어링 시대의 생존 스킬 9가지](https://flowkater.io/posts/2026-03-01-agentic-engineering-9-skills/)
- [GeekNews — 에이전틱 엔지니어링 9가지 스킬](https://news.hada.io/topic?id=27104)
- [AGENTS.md 공식 사양](https://agents.md/)
- [Karpathy — Agentic Engineering 트윗](https://x.com/karpathy/status/2019137879310836075)
- [Karpathy Says Vibe Coding Is Fading](https://www.thehansindia.com/technology/tech-news/karpathy-says-vibe-coding-is-fading-as-agentic-engineering-becomes-the-new-ai-coding-era-1045758)

### 학술 논문
- [ACE: Agentic Context Engineering (ICLR 2026)](https://arxiv.org/abs/2510.04618)
- Lulla et al. — ICSE JAWs 2026: 개발자 유지보수 AGENTS.md의 성능 영향 (124 PR 분석)
- ETH Zurich — SWE-bench 기반 AGENTS.md 자동 생성 vs 수동 작성 비교 연구
- Liu et al. — "Lost in the Middle": 긴 컨텍스트의 성능 영향

### 참고 프로젝트 & 도구
- [humanlayer/advanced-context-engineering-for-coding-agents](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)
- [Good practices creating AGENTS.md (AI Native Compass)](https://ainativecompass.substack.com/p/good-practices-creating-agentsmd)
- [A Complete Guide To AGENTS.md (AI Hero)](https://www.aihero.dev/a-complete-guide-to-agents-md)

### 핵심 인물
- **Andrej Karpathy**: Vibe Coding → Agentic Engineering 개념화
- **Addy Osmani** (Google): AGENTS.md 자동 생성 안티패턴 연구
- **Armin Ronacher** (Flask 창시자): 언어 선택과 에이전트 친화적 구조
- **Chris Lattner** (LLVM/Swift 창시자): 감각(taste)의 중요성

---

*Last updated: 2026-03-04*
