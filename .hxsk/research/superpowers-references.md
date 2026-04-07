# Superpowers 패턴 근거 논문 및 연구자료

> 조사일: 2026-04-07
> 목적: superpowers-analysis.md의 핵심 패턴 10가지에 대한 학술적 근거 수집

---

## 요약

18개 고유 출처에서 7개 핵심 패턴 전부에 대한 학술적·산업적 근거를 확인함.
가장 강력한 검증: Meincke et al.(2025, N=28,000)의 설득 기법 실험, SkillReducer(2026)의 CSO 실증, Anthropic 멀티에이전트 시스템의 90%+ 성능 향상.

| 패턴 | 출처 수 | 가장 강력한 근거 |
|------|---------|-----------------|
| TDD for AI | 4 | Mathews+ ASE 2024: TDD가 LLM 코드 생성 성공률 향상 |
| 게이트 함수 | 3 | Anthropic harness blog: 명시적 검증 도구가 허위 완료 선언 제거 |
| 합리화 테이블 | 4 | Sharma+ ICLR 2024: RLHF가 아첨 유발; Meincke+ 2025: Authority가 준수율 2배 |
| CSO | 3 | SkillReducer: 48% 압축 + 2.8% 품질 향상 = less-is-more |
| 2단계 리뷰 | 3 | Anthropic 멀티에이전트: 전문 에이전트 역할 분리로 90%+ 향상 |
| Iron Laws | 4 | Wallace+ ICLR 2025: 명령 계층 훈련; Meincke+ 2025: 33%→72% 준수율 |
| 컨텍스트 격리 | 4 | Context engineering blog: 컨텍스트 오염이 recall 저하; 멀티에이전트: 90%+ 향상 |

---

## 패턴 1: TDD for AI Agents

### 1-A. Test Driven Development: By Example (기초)

- **저자**: Kent Beck
- **연도/출판**: 2003, Addison-Wesley (ISBN: 0321146530)
- **URL**: https://www.amazon.com/Test-Driven-Development-Kent-Beck/dp/0321146530
- **핵심 발견**: Red-Green-Refactor 사이클 공식화. 실패 테스트 먼저 작성 → 최소 코드로 통과 → 리팩터. 모든 프로덕션 코드가 테스트로 정당화됨.
- **패턴 검증**: Superpowers TDD 스킬의 Iron Law "실패 테스트 없이 프로덕션 코드 없음"과 "테스트 전 작성된 코드 삭제" 규칙은 Beck 방법론의 AI 에이전트 적용.

### 1-B. Test-Driven Development for Code Generation (실증)

- **저자**: Noble Saji Mathews, Meiyappan Nagappan
- **연도/출판**: 2024, arXiv:2402.13521; ASE 2024 (39th IEEE/ACM International Conference on Automated Software Engineering)
- **URL**: https://arxiv.org/abs/2402.13521
- **핵심 발견**: GPT-4, Llama 3에 테스트 케이스를 문제 설명과 함께 제공하면 MBPP, HumanEval 벤치마크에서 코드 생성 성공률이 일관되게 향상.
- **패턴 검증**: TDD 패턴이 AI 생성 코드 품질을 개선한다는 실증적 확인.

### 1-C. LLM-Based Test-Driven Interactive Code Generation (사용자 연구)

- **저자**: Sarah Fakhoury, Aaditya Naik, Georgios Sakkas, Saikat Chakraborty, Shuvendu K. Lahiri (Microsoft Research)
- **연도/출판**: 2024, IEEE Transactions on Software Engineering (TSE); ICSE-Companion 2024
- **URL**: https://dl.acm.org/doi/abs/10.1109/TSE.2024.3428972
- **핵심 발견**: TiCoder 워크플로우 — 테스트로 모호한 사용자 의도 공식화. 15명 프로그래머 사용자 연구: 인지 부하 감소, pass@1 정확도 5회 상호작용 내 +45.73% 향상.
- **패턴 검증**: 테스트 우선 워크플로우가 인간-AI 협업에서 모호성 감소 및 결과 향상.

### 1-D. Tests as Prompt: A TDD Benchmark for LLM Code Generation (벤치마크)

- **저자**: Yi Cui (ONEKQ Lab)
- **연도/출판**: 2025년 5월, arXiv:2505.09027
- **URL**: https://arxiv.org/abs/2505.09027
- **핵심 발견**: WebApp1K 벤치마크(1000 챌린지, 20 도메인). TDD 성공에는 일반 코딩 능력보다 명령 수행(instruction following)과 인컨텍스트 러닝이 더 중요.
- **패턴 검증**: 엄격한 TDD 강제(Superpowers 방식)가 유연한 가이드보다 나은 이유 설명.

---

## 패턴 2: 게이트 함수 / 검증 체크포인트

### 2-A. Effective harnesses for long-running agents (핵심)

- **저자**: Prithvi Rajasekaran, Anthropic Labs
- **연도/출판**: 2025년 11월, Anthropic Engineering Blog
- **URL**: https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- **핵심 발견**: 계획·생성·평가 에이전트 분리. 별도 평가자 에이전트를 few-shot 예시와 채점 기준으로 보정. 명시적 검증 도구 없이는 에이전트가 허위 완료 선언.
- **패턴 검증**: 5단계 게이트 함수(IDENTIFY→RUN→READ→VERIFY→CLAIM) 패턴 직접 검증.

### 2-B. Building Reliable Multi-Agent Workflows (산업 실무)

- **저자**: Yess AI team
- **연도/출판**: 2025, yess.ai blog
- **URL**: https://www.yess.ai/post/durable-agentic-workflows
- **핵심 발견**: Validation gates = 기준 충족까지 자율 행동 중단하는 공식 중단점. 워크플로우를 이산 단계로 분리하고 각 단계 출력에 검증 기준 부여.
- **패턴 검증**: 게이트 함수가 산업 표준 패턴임을 확인.

### 2-C. Harness design for long-running application development (후속)

- **저자**: Prithvi Rajasekaran, Anthropic Labs
- **연도/출판**: 2026년 3월, Anthropic Engineering Blog
- **URL**: https://www.anthropic.com/engineering/harness-design-long-running-apps
- **핵심 발견**: 3-에이전트 아키텍처(planner, generator, evaluator). 평가자를 few-shot 채점 예시로 보정.
- **패턴 검증**: 멀티에이전트 설정에서도 별도 평가 체크포인트 필수.

---

## 패턴 3: 합리화 테이블 / 아첨(Sycophancy) 방지

### 3-A. Towards Understanding Sycophancy in Language Models (기초)

- **저자**: Mrinank Sharma, Meg Tong, Tomasz Korbak, David Duvenaud, Amanda Askell, Samuel R. Bowman, Newton Cheng, Esin Durmus, Zac Hatfield-Dodds, Scott R. Johnston, Shauna Kravec, Timothy Maxwell, Sam McCandlish, Kamal Ndousse, Oliver Rausch, Nicholas Schiefer, Da Yan, Miranda Zhang, Ethan Perez
- **연도/출판**: 2023년 10월, arXiv:2310.13548; ICLR 2024 출판
- **URL**: https://arxiv.org/abs/2310.13548
- **핵심 발견**: 5개 SOTA AI 어시스턴트가 4개 텍스트 생성 태스크에서 일관된 아첨 행동. 인간과 선호 모델이 정확한 응답보다 설득력 있는 아첨 응답을 선호. RLHF 훈련이 아첨의 근본 원인.
- **패턴 검증**: 합리화 테이블이 해결하는 근본 원인. LLM은 동의·순응하도록 훈련됨 — 합리화 테이블은 이 순응 패턴을 열거하고 현실 검증으로 차단.

### 3-B. Sycophancy in Large Language Models: Causes and Mitigations (서베이)

- **저자**: Lars Malmqvist
- **연도/출판**: 2024년 11월, arXiv:2411.15287
- **URL**: https://arxiv.org/abs/2411.15287
- **핵심 발견**: 아첨의 원인, 영향, 완화 전략 기술 서베이. 아첨, 환각, 편향의 관계 분석. 완화 접근: 훈련 데이터 개선, 미세조정, 배포 후 제어, 디코딩 전략.
- **패턴 검증**: 아첨이 명시적 대응이 필요한 체계적 문제임을 확인.

### 3-C. Sycophancy Is Not One Thing (메커니즘)

- **저자**: Daniel Vennemeyer, Phan Anh Duong, Tiffany Zhan, Tianyu Jiang
- **연도/출판**: 2025년 9월, arXiv:2509.21305
- **URL**: https://arxiv.org/abs/2509.21305
- **핵심 발견**: 아첨적 동의, 아첨적 칭찬, 진정한 동의가 잠재 공간에서 별개의 선형 방향으로 인코딩. 각각 독립적으로 증폭/억제 가능.
- **패턴 검증**: 합리화 테이블이 특정 행동에 효과적인 이유 설명 — "아첨적 동의"(암묵적 지름길에 대한 모델의 동의)가 메커니즘적으로 분리 가능.

### 3-D. Call Me A Jerk (설득 기반 준수)

- **저자**: Lennart Meincke, Dan Shapiro, Angela Duckworth, Ethan R. Mollick, Lilach Mollick, Robert Cialdini
- **연도/출판**: 2025년 7월, SSRN #5357179 / Wharton School Research Paper
- **URL**: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5357179
- **핵심 발견**: N=28,000 GPT-4o-mini 대화. 설득 기법으로 준수율 33.3%→72.0%. Authority 원칙으로 특정 태스크 준수율 4.7%→95.2%. LLM의 "준인간 심리(parahuman psychology)" 검증.
- **패턴 검증**: 설득 기법이 비바람직한 준수를 높일 수 있다면, 동일 기법을 윤리적으로 사용하여 바람직한 준수도 높일 수 있음. 합리화 테이블은 Authority("이것은 합리화지 현실이 아님")와 Social Proof("매번 X 발생")로 LLM 지름길 차단.

---

## 패턴 4: CSO (Claude Search Optimization)

### 4-A. SkillReducer: Optimizing LLM Agent Skills for Token Efficiency (핵심 실증)

- **저자**: Yudong Gao, Zongjie Li, Yuanyuan Yuan, Zimo Ji, Pingchuan Ma, Shuai Wang
- **연도/출판**: 2026년 3월, arXiv:2603.29919
- **URL**: https://arxiv.org/abs/2603.29919
- **핵심 발견**: 55,315개 공개 스킬 분석. 26.4%가 라우팅 description 부재. 60% 이상의 본문이 비실행 내용. 2단계 최적화: description 적대적 압축 + 본문 분류 기반 구조화. **48% description 압축, 39% 본문 압축, 기능 품질 2.8% 향상** — "less-is-more" 효과. 5개 모델 패밀리에서 평균 retention 0.965.
- **패턴 검증**: CSO 패턴 직접 검증. 장황한 description이 에이전트의 스킬 본문 건너뛰기 유발. 트리거 중심 압축 description이 전체 스킬 읽기를 강제. 내용 제거로 품질 향상이라는 실증적 증명.

### 4-B. SkillRouter: Retrieve-and-Rerank Skill Selection at Scale (보완)

- **저자**: YanZhao Zheng, ZhenTao Zhang, Chao Ma, YuanQiang Yu, JiHuan Zhu, Baohua Dong, Hangcheng Zhu
- **연도/출판**: 2026년 3월, arXiv:2603.22455
- **URL**: https://arxiv.org/abs/2603.22455
- **핵심 발견**: 스킬 본문(전체 구현 텍스트)이 선택의 결정적 신호. 1.2B 파라미터로 74.0% top-1 라우팅 정확도. description만으로는 본문 기반 라우팅에 미달.
- **패턴 검증**: 보완적 관점 — 외부 라우팅 시스템에서는 본문이 중요하지만, 인컨텍스트 에이전트 자기 선택(CSO 유스케이스)에서는 description이 스킬 로딩 전 유일한 판단 기준이므로 description 품질이 결정적.

### 4-C. Skill authoring best practices (공식 문서)

- **저자**: Anthropic documentation team
- **연도/출판**: 2025-2026, Anthropic Developer Docs
- **URL**: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/
- **핵심 발견**: 시작 시 모든 스킬의 메타데이터(name, description)만 프리로드. SKILL.md는 관련성 판단 후에만 읽음. 컨텍스트 윈도우는 "공공재" — 모든 토큰이 대화 히스토리와 경쟁.
- **패턴 검증**: Anthropic 공식 문서가 CSO 메커니즘 확인 — description은 라우팅 레이어, 본문은 온디맨드 로딩.

---

## 패턴 5: 2단계 리뷰

### 5-A. Building effective agents (기초)

- **저자**: Erik Schluntz, Barry Zhang (Anthropic)
- **연도/출판**: 2024년 12월, Anthropic Research Blog
- **URL**: https://www.anthropic.com/research/building-effective-agents
- **핵심 발견**: Orchestrator-worker 패턴 정의. Evaluator-optimizer는 별도 워크플로우 패턴. 명확한 성공 기준과 피드백 루프 강조.
- **패턴 검증**: 2단계 리뷰(스펙 준수→코드 품질)는 evaluator-optimizer 패턴의 인스턴스화. "요청한 걸 만들었나?"와 "잘 만들었나?"의 분리.

### 5-B. How we built our multi-agent research system (대규모 구현)

- **저자**: Anthropic Engineering team
- **연도/출판**: 2025년 6월 13일, Anthropic Engineering Blog
- **URL**: https://www.anthropic.com/engineering/multi-agent-research-system
- **핵심 발견**: LeadResearcher + 서브에이전트 아키텍처. 각 서브에이전트에 명확한 목표, 출력 형식, 도구 가이드, 태스크 경계. Opus 4 리드 + Sonnet 4 서브에이전트 시스템이 단일 에이전트 대비 **90%+ 향상**. 성능은 토큰 사용량과 독립 컨텍스트 윈도우 간 추론 분산에 비례.
- **패턴 검증**: 리뷰 관심사를 에이전트 간 분리(하나가 두 가지 다 하는 대신)하면 더 나은 결과. 전문 리뷰어가 범용 리뷰어를 능가.

---

## 패턴 6: Iron Laws / 밝은 선 규칙

### 6-A. The Instruction Hierarchy: Training LLMs to Prioritize Privileged Instructions (핵심)

- **저자**: Eric Wallace, Kai Xiao, Reimar Leike, Lilian Weng, Johannes Heidecke, Alex Beutel (OpenAI)
- **연도/출판**: 2024년 4월, arXiv:2404.13208; ICLR 2025 출판
- **URL**: https://arxiv.org/abs/2404.13208
- **핵심 발견**: LLM이 시스템 프롬프트와 사용자 텍스트를 동일 우선순위로 처리하는 것이 핵심 취약점. 명시적 명령 계층(System > Developer > User > Tool) 제안. GPT-3.5에 적용하여 미지 공격 유형에서도 강건성 대폭 향상, 표준 기능 저하 최소.
- **패턴 검증**: Iron Laws가 작동하는 이유 — 명령 계층에서 최고 우선순위 수준 점유. "NO X WITHOUT Y FIRST"는 사용자 수준 합리화를 오버라이드하는 시스템 수준 절대 제약으로 기능.

### 6-B. Influence: The Psychology of Persuasion (설득 기초)

- **저자**: Robert B. Cialdini
- **연도/출판**: 2021, Harper Business (ISBN: 0062937650)
- **URL**: https://www.amazon.com/Influence-New-Expanded-Psychology-Persuasion/dp/0062937650
- **핵심 발견**: 7가지 설득 원칙: Authority, Commitment, Social Proof, Scarcity, Unity, Reciprocity, Liking. 35년 증거 기반 연구. Authority 원칙: 전문성, 자격, 공식 출처에 대한 복종. 밝은 선 규칙은 의사결정 피로를 제거하여 합리화 감소.
- **패턴 검증**: Iron Laws는 Authority 원칙("YOU MUST", "NEVER", "NO EXCEPTIONS") 활용. Cialdini 연구는 인간에 대해, Meincke et al.(2025)은 LLM에 대해 이를 증명.

### 6-C. Call Me A Jerk (LLM 특화 검증)

- *3-D와 동일 — 위 참조*
- **패턴 검증**: Authority 언어가 LLM에 효과적이라는 실증적 증명. Iron Laws는 정확히 이것을 사용 — 명령적, 비타협적 프레이밍으로 모델의 합리화 결정 공간 제거.

### 6-D. OpenAI Model Spec (산업 표준)

- **저자**: OpenAI
- **연도/출판**: 2024-2025 (반복 업데이트)
- **URL**: https://model-spec.openai.com/2025-12-18.html
- **핵심 발견**: "Root" 수준 규칙은 근본적이며 누구도 오버라이드 불가. 대부분 금지형: 재앙적 위험, 직접적 물리적 해악, 법 위반, 지휘 체계 훼손 방지.
- **패턴 검증**: OpenAI의 "root level rules"가 Iron Laws의 프로덕션 등가물. 주요 AI 연구소가 동일한 밝은 선 규칙 패턴을 자체 시스템에 사용.

---

## 패턴 7: 서브에이전트 컨텍스트 격리

### 7-A. Building effective agents (기초)

- *5-A와 동일 — 위 참조*
- **패턴 검증**: 컨텍스트 격리의 아키텍처적 기초. 오케스트레이터가 각 워커에 필요한 것만 제공, 전체 대화 히스토리가 아님.

### 7-B. How we built our multi-agent research system (대규모 구현)

- *5-B와 동일 — 위 참조*
- **패턴 검증**: 대규모 컨텍스트 격리의 프로덕션 검증. 격리된 컨텍스트 윈도우가 컨텍스트 오염 방지 및 결과 향상. **90%+ 향상**이 효과 정량화.

### 7-C. Effective context engineering for AI agents (이론)

- **저자**: Anthropic Applied AI Team
- **연도/출판**: 2025년 9월 29일, Anthropic Engineering Blog
- **URL**: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- **핵심 발견**: 컨텍스트 = LLM 샘플링 시 포함되는 토큰 집합. **"컨텍스트 부패(Context rot)"** — 토큰 수 증가 시 recall 정확도 감소. 3가지 핵심 기법: 압축(요약 후 재시작), 구조화된 노트 테이킹(점진적 공개), 멀티에이전트 아키텍처. 지도 원칙: "원하는 결과의 가능성을 최대화하는 최소한의 고신호 토큰 집합."
- **패턴 검증**: 컨텍스트 격리의 이론적 정당화. 컨텍스트 부패 — 서브에이전트에 컨트롤러의 전체 컨텍스트를 주면 성능이 적극적으로 저하됨. 격리는 조직적 편의가 아니라 모델 정확도 유지를 위한 필수.

### 7-D. Effective harnesses for long-running agents (장기 실행)

- *2-A와 동일 — 위 참조*
- **패턴 검증**: 컨텍스트 격리가 시간적 격리로 확장 — 새 컨텍스트 윈도우는 전체 히스토리가 아닌 최소한의 고품질 컨텍스트로 초기화해야 하는 "서브에이전트"의 한 형태.

---

## 추가 배경 연구

### EmotionPrompt (감정적 프레이밍)

- **저자**: Cheng Li, Jindong Wang, Yixuan Zhang, Kaijie Zhu, Wenxin Hou, Jianxun Lian, Fang Luo, Qiang Yang, Xing Xie
- **연도/출판**: 2023, arXiv:2307.11760
- **URL**: https://arxiv.org/abs/2307.11760
- **핵심 발견**: 감정적 자극("이것은 내 경력에 매우 중요합니다")을 프롬프트에 추가하면 LLM 성능 +10.9% 향상. 다중 태스크(BIG-Bench, instruction induction 등)에서 검증.
- **관련성**: Superpowers가 의도적으로 회피하는 기법. Liking/감정 조작은 아첨 유발 위험.

### AFLOW: Automating Agentic Workflow Generation (구조화된 워크플로우)

- **저자**: Jinhao Jiang et al.
- **연도/출판**: 2024, arXiv:2410.10762; ICLR 2025
- **URL**: https://arxiv.org/abs/2410.10762
- **핵심 발견**: Monte Carlo Tree Search 기반 에이전트 워크플로우 자동 생성. 사전 정의된 작업 시퀀스가 에이전트 드리프트 방지. 구조가 자유도보다 성능 향상에 기여.
- **패턴 검증**: 구조화된 워크플로우(Superpowers의 brainstorm→plan→execute→finish 체인)가 비구조적 접근보다 우수하다는 근거.

---

## 출처 교차 참조 매트릭스

| # | 출처 | 패턴 1 | 패턴 2 | 패턴 3 | 패턴 4 | 패턴 5 | 패턴 6 | 패턴 7 |
|---|------|--------|--------|--------|--------|--------|--------|--------|
| 1 | Beck (2003) | O | | | | | | |
| 2 | Mathews+ (2024) | O | | | | | | |
| 3 | Fakhoury+ (2024) | O | | | | | | |
| 4 | Cui (2025) | O | | | | | | |
| 5 | Rajasekaran/Anthropic (2025) | | O | | | | | O |
| 6 | Yess AI (2025) | | O | | | | | |
| 7 | Rajasekaran (2026) | | O | | | | | |
| 8 | Sharma+ (2023/ICLR 2024) | | | O | | | | |
| 9 | Malmqvist (2024) | | | O | | | | |
| 10 | Vennemeyer+ (2025) | | | O | | | | |
| 11 | Meincke+ (2025) | | | O | | | O | |
| 12 | Gao+ (2026) SkillReducer | | | | O | | | |
| 13 | Zheng+ (2026) SkillRouter | | | | O | | | |
| 14 | Anthropic Docs | | | | O | | | |
| 15 | Schluntz+Zhang (2024) | | | | | O | | O |
| 16 | Anthropic Multi-Agent (2025) | | | | | O | | O |
| 17 | Wallace+ (ICLR 2025) | | | | | | O | |
| 18 | Cialdini (2021) | | | | | | O | |
| 19 | OpenAI Model Spec | | | | | | O | |
| 20 | Anthropic Context Eng. (2025) | | | | | | | O |

---

## 결론

Superpowers의 7가지 핵심 패턴 모두 학술 논문 또는 주요 AI 연구소(Anthropic, OpenAI)의 공식 엔지니어링 문서로 뒷받침됨. 특히:

1. **가장 강력한 실증**: Meincke et al.(2025)의 N=28,000 실험 — 설득 기법이 LLM 준수율을 2배 이상 향상
2. **가장 실용적**: SkillReducer(2026)의 55,315개 스킬 분석 — description 압축으로 품질 향상
3. **가장 근본적**: Sharma et al.(ICLR 2024)의 아첨 연구 — RLHF 훈련이 에이전트 합리화의 근본 원인

이 연구들은 Superpowers의 설계 결정이 경험적 직관이 아닌 검증된 연구에 기반함을 보여줌.
