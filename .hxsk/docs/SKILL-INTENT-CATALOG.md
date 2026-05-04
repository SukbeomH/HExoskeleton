# Skill Intent Catalog

> HXSK 스킬 24개의 **제작 의도**, 대표 문서, 연결된 리서치 근거를 빠르게 훑어보기 위한 카탈로그입니다.
> 상세 절차는 각 `SKILL.md`, 전체 연구 맥락은 `.hxsk/research/INDEX.md`를 참조합니다.

## 읽는 법

- **제작 의도**: 이 스킬을 왜 만들었는지, 어떤 실패 모드를 줄이려는지
- **대표 리서치**: 스킬 설계에 직접 영향을 준 내부/외부 근거 문서
- **스킬 문서**: 실제 절차와 트리거 규칙이 들어 있는 canonical source

*Updated: 2026-05-04 · Source count: 24 skills*

## Core Workflow

| Skill | 제작 의도 | 스킬 문서 | 대표 리서치 |
|------|-----------|-----------|-------------|
| `bootstrap` | 설치·업데이트·검증을 한 스크립트로 수렴시켜 환경 차이로 인한 온보딩 실패를 줄이기 위함 | [`bootstrap`](../skills/bootstrap/SKILL.md)<br><sub>Use when .hxsk/.bootstrap-version is missing (fresh install) or exists</sub> | [`RESEARCH-code-as-specification.md`](../research/deployment-strategy/RESEARCH-code-as-specification.md) · [`RESEARCH-agents-md-agentic-engineering-2026.md`](../research/platform-integration/RESEARCH-agents-md-agentic-engineering-2026.md) |
| `debugger` | 추측성 수정 대신 반증 가능한 가설 기반 디버깅을 강제하기 위함 | [`debugger`](../skills/debugger/SKILL.md)<br><sub>Use when debugging bugs to find root causes, or after 3 failed fix attempts</sub> | [`claude-code-quality-mitigation.md`](../research/claude-code-quality-mitigation.md) · [`2026-04-23-hallucination-linguistic-features.md`](../research/2026-04-23-hallucination-linguistic-features.md) |
| `dispatcher` | 대규모 작업을 worktree 단위로 안전하게 병렬 분해하기 위함 | [`dispatcher`](../skills/dispatcher/SKILL.md)<br><sub>Use when PLAN.md or SPEC.md exists and tasks require splitting into waves</sub> | [`RESEARCH-github-task-management-workflow.md`](../research/workflow/RESEARCH-github-task-management-workflow.md) · [`RESEARCH-token-optimization-multi-hop.md`](../research/workflow/RESEARCH-token-optimization-multi-hop.md) |
| `executor` | 계획을 작은 태스크와 atomic commit으로 실제 구현까지 밀어붙이기 위함 | [`executor`](../skills/executor/SKILL.md)<br><sub>Use when a PLAN.md file exists and requires execution to implement tasks</sub> | [`RESEARCH-agentic-reasoning-token-optimization.md`](../research/memory-systems/RESEARCH-agentic-reasoning-token-optimization.md) |
| `plan-checker` | 실행 전에 plan 구조 결함을 차단해 잘못된 분해를 미리 막기 위함 | [`plan-checker`](../skills/plan-checker/SKILL.md)<br><sub>'Use when PLAN.md exists after /plan and before /execute to validate</sub> | [`RESEARCH-agentic-reasoning-token-optimization.md`](../research/memory-systems/RESEARCH-agentic-reasoning-token-optimization.md) |
| `planner` | 목표를 컨텍스트 예산 안에서 실행 가능한 태스크로 분해하기 위함 | [`planner`](../skills/planner/SKILL.md)<br><sub>Use when SPEC.md exists and you must decompose phase goals into exactly</sub> | [`RESEARCH-agentic-reasoning-token-optimization.md`](../research/memory-systems/RESEARCH-agentic-reasoning-token-optimization.md) · [`claude-code-quality-mitigation.md`](../research/claude-code-quality-mitigation.md) |
| `verifier` | 구현의 실질 내용과 wiring을 점검해 가짜 완료를 차단하기 위함 | [`verifier`](../skills/verifier/SKILL.md)<br><sub>Use when code exists but needs validation for stubs, wiring, and anti-patterns</sub> | [`claude-code-quality-mitigation.md`](../research/claude-code-quality-mitigation.md) |

## Analysis

| Skill | 제작 의도 | 스킬 문서 | 대표 리서치 |
|------|-----------|-----------|-------------|
| `arch-review` | 구조 규칙 위반을 초기에 차단해 설계 부채가 런타임 결함으로 번지지 않게 하기 위함 | [`arch-review`](../skills/arch-review/SKILL.md)<br><sub>Use when validating code for circular imports, layer violations, or design</sub> | [`RESEARCH-code-entropy-dependency-minimization.md`](../research/architecture/RESEARCH-code-entropy-dependency-minimization.md) |
| `codebase-mapper` | 에이전트가 코드를 건드리기 전에 구조와 진입점을 빠르게 파악하게 하기 위함 | [`codebase-mapper`](../skills/codebase-mapper/SKILL.md)<br><sub>Use when analyzing an existing codebase to generate ARCHITECTURE.md and</sub> | [`RESEARCH-code-entropy-dependency-minimization.md`](../research/architecture/RESEARCH-code-entropy-dependency-minimization.md) |
| `context-health-monitor` | 긴 세션에서 품질 저하 신호를 조기 감지해 fresh context 전환을 유도하기 위함 | [`context-health-monitor`](../skills/context-health-monitor/SKILL.md)<br><sub>Use when debugging fails 3 times, same approach repeats, or context usage</sub> | [`RESEARCH-context-compression-98.md`](../research/memory-systems/RESEARCH-context-compression-98.md) · [`claude-code-quality-mitigation.md`](../research/claude-code-quality-mitigation.md) |
| `empirical-validation` | 완료 선언을 코드 인상비평이 아닌 실행 증거에 묶기 위함 | [`empirical-validation`](../skills/empirical-validation/SKILL.md)<br><sub>Use when claiming work is complete, successful, or fixed, and empirical</sub> | [`claude-code-quality-mitigation.md`](../research/claude-code-quality-mitigation.md) |
| `impact-analysis` | 기존 파일 수정 전에 회귀 가능성과 연쇄 영향 범위를 드러내기 위함 | [`impact-analysis`](../skills/impact-analysis/SKILL.md)<br><sub>Use when modifying any existing file (excluding new standalone files)</sub> | [`RESEARCH-code-entropy-dependency-minimization.md`](../research/architecture/RESEARCH-code-entropy-dependency-minimization.md) |

## Git/Pr

| Skill | 제작 의도 | 스킬 문서 | 대표 리서치 |
|------|-----------|-----------|-------------|
| `commit` | 논리적으로 섞인 변경을 원자 커밋으로 분리해 추적성과 롤백성을 높이기 위함 | [`commit`](../skills/commit/SKILL.md)<br><sub>Use when staged changes exist requiring qlty checks, logical split detection,</sub> | [`RESEARCH-github-task-management-workflow.md`](../research/workflow/RESEARCH-github-task-management-workflow.md) |
| `create-pr` | 검증을 통과한 변경만 구조화된 PR로 승격시키기 위함 | [`create-pr`](../skills/create-pr/SKILL.md)<br><sub>Use when local changes pass A-E quality checks, lessons-learned review,</sub> | [`RESEARCH-github-task-management-workflow.md`](../research/workflow/RESEARCH-github-task-management-workflow.md) |
| `pr-review` | PR을 역할 기반 다중 관점으로 점검해 숨은 위험을 조기에 찾기 위함 | [`pr-review`](../skills/pr-review/SKILL.md)<br><sub>Use when a PR number or URL is provided to conduct a comprehensive code</sub> | [`RESEARCH-agents-md-agentic-engineering-2026.md`](../research/platform-integration/RESEARCH-agents-md-agentic-engineering-2026.md) |

## Utility

| Skill | 제작 의도 | 스킬 문서 | 대표 리서치 |
|------|-----------|-----------|-------------|
| `clean` | bash 중심 저장소에서 셸 품질 문제를 실행 전에 제거하기 위함 | [`clean`](../skills/clean/SKILL.md)<br><sub>Use when shell scripts need linting/formatting before execution or commit</sub> | [`RESEARCH-bash-cli-tools-for-llm.md`](../research/tooling/RESEARCH-bash-cli-tools-for-llm.md) |
| `cleanse-memory` | 파일 기반 메모리의 오염을 사람 승인 하에 국소적으로 정리하기 위함 | [`cleanse-memory`](../skills/cleanse-memory/SKILL.md)<br><sub>Use when Ground Truth alignment finds memory contamination and the user explicitly requests scoped cleanup with /cleanse.</sub> | [`RESEARCH-a-mem-agentic-memory.md`](../research/memory-systems/RESEARCH-a-mem-agentic-memory.md) · [`RESEARCH-nemori-self-organizing-agent-memory.md`](../research/memory-systems/RESEARCH-nemori-self-organizing-agent-memory.md) |
| `define-term` | 용어 정의를 분산 메모가 아니라 관리 가능한 glossary surface로 수렴시키기 위함 | [`define-term`](../skills/define-term/SKILL.md)<br><sub>Use when registering, reviewing, merging, or rebuilding HXSK glossary term definitions after glossary-detect suggests a candidate or the user invokes /define.</sub> | [`RESEARCH-ontology-for-llm-agents.md`](../research/memory-systems/RESEARCH-ontology-for-llm-agents.md) |
| `doc-lint` | 문서 SSOT와 링크 구조의 drift를 PR 전에 자동 검출하기 위함 | [`doc-lint`](../skills/doc-lint/SKILL.md)<br><sub>Use when modifying markdown files, preparing PRs, or suspecting link/structure</sub> | [`RESEARCH-agents-md-agentic-engineering-2026.md`](../research/platform-integration/RESEARCH-agents-md-agentic-engineering-2026.md) |
| `handoff` | 세션 종료 시 다음 실행자가 즉시 재진입할 수 있는 최소 상태를 남기기 위함 | [`handoff`](../skills/handoff/SKILL.md)<br><sub>Use when a session ends, work must pause, or another agent will continue</sub> | [`RESEARCH-token-optimization-multi-hop.md`](../research/workflow/RESEARCH-token-optimization-multi-hop.md) · [`RESEARCH-context-compression-98.md`](../research/memory-systems/RESEARCH-context-compression-98.md) |
| `memory-protocol` | 메모리 저장/검색 규칙을 표준화해 recall 품질과 재사용성을 높이기 위함 | [`memory-protocol`](../skills/memory-protocol/SKILL.md)<br><sub>Use when starting sessions, making architecture decisions, finding root</sub> | [`RESEARCH-a-mem-agentic-memory.md`](../research/memory-systems/RESEARCH-a-mem-agentic-memory.md) · [`RESEARCH-nemori-self-organizing-agent-memory.md`](../research/memory-systems/RESEARCH-nemori-self-organizing-agent-memory.md) |
| `refactor` | 행동 보존을 전제로 코드 스멜을 안전하게 줄이기 위함 | [`refactor`](../skills/refactor/SKILL.md)<br><sub>Use when code smells are identified and tests or specs exist to refactor</sub> | [`RESEARCH-code-entropy-dependency-minimization.md`](../research/architecture/RESEARCH-code-entropy-dependency-minimization.md) |
| `skill-testing` | 스킬이 실제로 에이전트 행동을 바꾸는지 압박 시나리오로 검증하기 위함 | [`skill-testing`](../skills/skill-testing/SKILL.md)<br><sub>Use when proving a skill alters agent behavior under pressure by comparing</sub> | [`superpowers-analysis.md`](../research/superpowers-analysis.md) · [`superpowers-references.md`](../research/superpowers-references.md) |
| `write-report` | 기술 선택 논의를 비기술 의사결정자도 읽을 수 있는 근거 문서로 바꾸기 위함 | [`write-report`](../skills/write-report/SKILL.md)<br><sub>Use when comparing 3-5 solutions to generate a decision report with TCO,</sub> | [`solution_comparison_report_guide.md`](../research/architecture/solution_comparison_report_guide.md) |
