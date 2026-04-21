# Research Index

> 리서치 문서 카탈로그. 각 카테고리별 문서, 상태, 핵심 결론 요약.
>
> **Status**: `active` 현행 유효 · `archived` 역사적 참고 · `superseded` 후속 결정으로 대체

## memory-systems/ (8) — all active

현재 메모리 아키텍처의 이론적 기반. 모두 현행 유효.

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| [RESEARCH-a-mem-agentic-memory.md](memory-systems/RESEARCH-a-mem-agentic-memory.md) | `active` | 7-속성 노트 + 2-hop 검색 채택, Memory Evolution 미채택 |
| [RESEARCH-nemori-self-organizing-agent-memory.md](memory-systems/RESEARCH-nemori-self-organizing-agent-memory.md) | `active` | 중복 제거 + 이중 메모리 채택, Predict-Calibrate 미채택 |
| [RESEARCH-agentic-reasoning-token-optimization.md](memory-systems/RESEARCH-agentic-reasoning-token-optimization.md) | `active` | ReWOO 계획-실행 분리, EASYTOOL 2단계 로딩 채택 |
| [RESEARCH-ontology-for-llm-agents.md](memory-systems/RESEARCH-ontology-for-llm-agents.md) | `active` | 14 타입 분류 + JSON Schema + type-relations.yaml |
| [RESEARCH-rlm-recursive-language-models.md](memory-systems/RESEARCH-rlm-recursive-language-models.md) | `active` | Agent-Skill 래핑 구조, 재귀적 분할 채택 |
| [RESEARCH-context-compression-98.md](memory-systems/RESEARCH-context-compression-98.md) | `active` | 컨텍스트 압축 기법 분석 |
| [RESEARCH-hybrid-search-fts5-rrf.md](memory-systems/RESEARCH-hybrid-search-fts5-rrf.md) | `active` | FTS5 + RRF 하이브리드 검색 분석 (향후 최적화 후보) |
| [RESEARCH-hxsk-applicability-hybrid-search-compression.md](memory-systems/RESEARCH-hxsk-applicability-hybrid-search-compression.md) | `active` | HXSK 적용 가능성 평가 |

## platform-integration/ (8)

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| [RESEARCH-everything-claude-code.md](platform-integration/RESEARCH-everything-claude-code.md) | `active` | Claude Code 전체 기능 정리 (skills, hooks, agents) |
| [RESEARCH-awesome-claude-code.md](platform-integration/RESEARCH-awesome-claude-code.md) | `active` | 커뮤니티 리소스 큐레이션 |
| [RESEARCH-claude-code-as-mcp-server.md](platform-integration/RESEARCH-claude-code-as-mcp-server.md) | `active` | Claude Code MCP 서버 활용 평가 |
| [RESEARCH-agents-md-agentic-engineering-2026.md](platform-integration/RESEARCH-agents-md-agentic-engineering-2026.md) | `active` | AGENTS.md 에이전틱 엔지니어링 트렌드 |
| [RESEARCH-google-antigravity-migration.md](platform-integration/RESEARCH-google-antigravity-migration.md) | `archived` | Antigravity IDE 마이그레이션 — 현재 비활성 플랫폼 |
| [RESEARCH-opencode-plugin-migration.md](platform-integration/RESEARCH-opencode-plugin-migration.md) | `archived` | OpenCode 플러그인 호환성 — Claude Code 집중으로 후순위 |
| [antigravity_doc_rules_and_workflows.md](platform-integration/antigravity_doc_rules_and_workflows.md) | `archived` | Antigravity 규칙/워크플로우 스냅샷 |
| [antigravity_doc_skills.md](platform-integration/antigravity_doc_skills.md) | `archived` | Antigravity 스킬 문서 스냅샷 |

## deployment-strategy/ (6)

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| [RESEARCH-code-as-specification.md](deployment-strategy/RESEARCH-code-as-specification.md) | `active` | 코드 = 스펙 접근법, 문서/코드 균형 지침 |
| [RESEARCH-boilerplate-safe-apply.md](deployment-strategy/RESEARCH-boilerplate-safe-apply.md) | `archived` | 기존 프로젝트 덮어쓰기 방지 — Self-Configure로 해소 |
| [RESEARCH-plugin-feasibility.md](deployment-strategy/RESEARCH-plugin-feasibility.md) | `superseded` | 플러그인 전환 분석 → Self-Configure 모델로 최종 결정 |
| [RESEARCH-plugin-auto-release.md](deployment-strategy/RESEARCH-plugin-auto-release.md) | `superseded` | release-please 워크플로우 → 인프라 삭제로 무효 |
| [RESEARCH-plugin-vs-safe-apply.md](deployment-strategy/RESEARCH-plugin-vs-safe-apply.md) | `superseded` | 플러그인 vs 안전 적용 비교 → Self-Configure로 무효 |
| [RESEARCH-gsd-in-plugin.md](deployment-strategy/RESEARCH-gsd-in-plugin.md) | `superseded` | .gsd/ 플러그인 내장 → .hxsk/ 전환 + Self-Configure로 무효 |

## language-support/ (3)

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| RESEARCH-multi-language-support.md | `archived` | 다국어 확장 가능성 — 현재 bash+markdown 전용 |
| RESEARCH-prior-art-multi-language.md | `archived` | 다국어 감지/품질 도구 선행 사례 |
| RESEARCH-python-specific-audit.md | `superseded` | Python 종속 전수 조사 → Python 완전 제거로 목적 달성 |

## tooling/ (2) — all active

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| RESEARCH-bash-cli-tools-for-llm.md | `active` | LLM 에이전트용 bash CLI 도구 조사 |
| RESEARCH-mcp-vs-cli.md | `active` | MCP vs CLI 트레이드오프 → CLI(bash) 선택 근거 |

## architecture/ (3)

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| RESEARCH-code-entropy-dependency-minimization.md | `active` | 코드 엔트로피 + 종속성 최소화 — 핵심 설계 원칙 |
| solution_comparison_report_guide.md | `active` | 솔루션 비교 보고서 작성 프레임워크 |
| HOOK_ISSUE_REPORT.md | `archived` | macOS 훅 실행 이슈 (2026-02-11, 일시적) |

## workflow/ (1) — all active

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| [RESEARCH-github-task-management-workflow.md](workflow/RESEARCH-github-task-management-workflow.md) | `active` | GitHub Flow + Sub-Issues GA + Worktree 패턴 + 멀티에이전트 Conductor 패턴 |
| [RESEARCH-multi-platform-compatibility.md](workflow/RESEARCH-multi-platform-compatibility.md) | `active` | GitHub/GitLab/Gitea/Forgejo 호환성 매트릭스 + forge-detect.sh 추상화 전략 |
| [RESEARCH-token-optimization-multi-hop.md](workflow/RESEARCH-token-optimization-multi-hop.md) | `active` | 멀티홉 핸드오프 토큰 최적화 — 경로 전달·구조화 WORK 문서·요약 보고로 60-75% 절감 |
| [RESEARCH-git-issue-as-memory.md](workflow/RESEARCH-git-issue-as-memory.md) | `active` | Git 이슈·커밋·코멘트를 단기 실행 메모리로 활용 — 로컬 파일은 장기 메모리로 역할 분리 |
| [RESEARCH-autoresearch-methodology.md](workflow/RESEARCH-autoresearch-methodology.md) | `active` | Karpathy 원조 vs Goenka 일반화 비교 — 7원칙 추출, HXSK 수입 권장: 자동 revert 루프 + TSV 로그 + Guard 이중 게이트 |

## agent-discipline/ (3) — all active

Superpowers 플러그인 분석 및 에이전트 규율 강화 연구.

| 문서 | 상태 | 핵심 결론 |
|------|------|----------|
| superpowers-analysis.md | `active` | 14개 스킬 구조, 10가지 설계 패턴, HXSK 적용 권장 8항목 |
| superpowers-references.md | `active` | 7패턴 × 20개 학술/산업 출처 (Meincke+ 2025, SkillReducer 2026 등) |
| claude-code-quality-mitigation.md | `active` | GitHub #42796 품질 저하 이슈 — 6문제 중 4개 Superpowers 기법으로 완화 가능 |

---

## 요약

| 상태 | 개수 | 비율 |
|------|------|------|
| `active` | 21 | 64% |
| `archived` | 7 | 21% |
| `superseded` | 5 | 15% |

*Total: 33 documents across 7 categories*
*Updated: 2026-03-25 — status 태깅 완료*
