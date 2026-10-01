# HExoskeleton 설계 철학

> AI 에이전트의 외골격 — 추상화의 늪 없이, 실제 결과물을 내는 개발 방법론의 설계 원칙과 근거.

---

## 1. 핵심 관찰

HExoskeleton은 세 가지 관찰에서 출발합니다.

### 관찰 1: 에이전트의 네이티브 도구가 이미 충분하다

`Grep`, `Glob`, `Read` — 코딩 에이전트가 기본 탑재한 도구만으로 파일 시스템을 완전히 탐색할 수 있습니다.

| 접근 | 채택 여부 | 이유 |
|------|----------|------|
| 벡터 DB (Qdrant, Weaviate) | 미채택 | 외부 서비스 의존, 설정 복잡도 증가 |
| MCP 서버 | 미채택 | 추가 프로세스, 네트워크 오버헤드 |
| SQLite/JSON | 미채택 | 파일 수준 가독성 저하, Git diff 불가 |
| Python/Node 패키지 의존 | 미채택 | 설치·환경 구성 필수, 표준 라이브러리로 충분 |
| **bash + python3 표준 라이브러리 + 마크다운** | **채택** | 패키지 설치 0, 빌드 0, 저장소 = 플러그인 |

**근거**: [Anthropic Context Engineering Guide](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — "가장 작은 고신호 토큰 집합"

### 관찰 2: 파일 시스템이 곧 데이터베이스다

마크다운 파일은 사람이 읽을 수 있고, `git diff`로 변경을 추적할 수 있고, 어떤 에이전트든 `Read` 한 번이면 접근할 수 있습니다.

**근거**:
- [A-Mem](https://arxiv.org/html/2502.12110v11): 7-속성 노트 + 2-hop 그래프 검색
- [Nemori](https://arxiv.org/html/2508.03341v3): 타입 분리 + 중복 제거 + contextual description

### 관찰 3: 에이전트는 "어떻게"보다 "언제, 무엇으로"가 중요하다

절차는 스킬(Skill)에 둡니다. 서브에이전트는 별도 컨텍스트에서 돌아야 하는 역할에만 둡니다.

**근거**:
- [RLM](https://arxiv.org/html/2512.24601v2): Phase → Plan → Task 구조

---

## 2. 설계 원칙

### 원칙 1: Lazy Loading 문서 계층

에이전트가 필요한 만큼만 읽도록 3단계로 구조화합니다.

| 레벨 | 내용 | 토큰 | 규칙 |
|------|------|------|------|
| **L0** | YAML frontmatter | ~50 | 스캔용 |
| **L1** | AGENTS.md (+ `.claude/CLAUDE.md`) | ~200-500 | 정책·제약·트리거만 |
| **L2** | SKILL.md, Agent.md | ~300-1000 | 상세 절차. Quick Reference ≤5줄 |
| **L3** | `skills/*/references/` | ~1000+ | 상세·근거. 필요 시에만 |

**규칙**: L1에는 정책, L2에는 절차, L3에는 상세와 근거. 상위 레벨은 하위를 참조하되 내용을 복제하지 않는다.

**근거**: SkillReducer (Gao et al., 2026, arXiv:2603.29919) — 55K 스킬 분석, description 압축 시 품질 2.8% 향상 (less-is-more). 60%+ 본문이 비실행 내용.

### 원칙 2: 스킬 우선, 에이전트는 격리가 필요할 때만

**Skill = How** (재사용 가능한 절차). 대부분의 작업(`planner`, `executor`, `debugger` 등)은 메인 세션이 스킬을 직접 로딩해 수행합니다.

서브에이전트는 별도 컨텍스트·도구 제한이 필요한 역할에만 둡니다 — 독립 검증(`verifier`)과 스펙 대조 리뷰(`spec-reviewer`). 두 에이전트는 frontmatter `skills:`로 스킬을 preload 하고, 스킬 이름과 같은 래퍼 에이전트는 두지 않습니다.

```
메인 세션 → debugger 스킬 로딩 → "1. 에러 수집 2. 가설 수립 3. 검증..."
메인 세션 → verifier 에이전트(별도 컨텍스트, 쓰기 도구 없음, verifier·empirical-validation preload)
```

에이전트 정의가 간결할수록 에이전트는 정확하게 동작합니다.

**근거**: Anthropic Context Engineering (2025) — "smallest set of high-signal tokens that maximize the likelihood of your desired outcome."

### 원칙 3: CSO (Claude Search Optimization)

스킬 description에는 **무엇을 하는지와 언제 쓰는지(트리거)** 만 기재합니다. 절차 요약을 넣으면 에이전트가 본문을 건너뜁니다.

```yaml
# Bad — 워크플로우 요약 포함
description: "메모리를 저장하고 검색하는 프로토콜. 2-hop 검색과 타입 분류를 지원"

# Good — 무엇 + 언제
description: "Stores and recalls project knowledge as typed markdown memories. Use after architecture decisions, bug fixes, or at session end."
```

**근거**: SkillReducer (2026) — 48% description 압축 + 2.8% 품질 향상. Anthropic 공식 문서: 시작 시 메타데이터만 프리로드, 본문은 관련성 판단 후 로딩.

### 원칙 4: 경험적 검증 (Empirical Validation)

"잘 되는 것 같다"는 증거가 아닙니다. 모든 주장은 실행 결과로 증명합니다.

**근거**: Anthropic harness blog (2025) — 명시적 검증 도구 없이 에이전트가 허위 완료 선언.

### 원칙 5: Iron Laws (밝은 선 규칙)

비타협 규칙은 `NO X WITHOUT Y FIRST` 형식으로 선언합니다.

```
NO EDIT WITHOUT READ FIRST
NO COMPLETION WITHOUT VERIFICATION
NO WRITE TO EXISTING FILES
```

**근거**:
- Meincke et al. (2025) SSRN #5357179: Authority 기법으로 LLM 준수율 33%→72% (N=28,000)
- Wallace et al. (ICLR 2025) arXiv:2404.13208: 명령 계층에서 최상위 규칙이 하위 합리화를 오버라이드
- OpenAI Model Spec (2025): "Root level rules" — 산업 표준 패턴

### 원칙 6: 프롬프트 + 인프라 이중 방어

프롬프트만으로는 thinking 부족 시 무시됩니다. 인프라(훅)로 이중 방어합니다.

```
Layer 1 (정책):   SKILL.md Iron Laws            — 스킬 로딩 시 (프로젝트 AGENTS.md 의 HXSK 블록은 요약 포인터)
Layer 2 (절차):   SKILL.md 합리화 테이블/게이트  — 스킬 로딩 시
Layer 3 (인프라): 가드 훅 (PreToolUse)          — Claude Code 플러그인에서 항상 실행
                  상태 훅 (read-before-edit, Stop 등) — `.hxsk/`가 있을 때만 (opt-in, Claude Code 플러그인 전용)
Layer 4 (라우팅): CSO description              — 올바른 스킬 선택
```

**근거**:
- Wallace et al. (ICLR 2025): 아키텍처 강제가 프롬프트 강제보다 일관되게 우수
- GitHub anthropics/claude-code#42796: thinking depth 73% 감소 시 프롬프트 규칙 무시 급증

### 원칙 7: 합리화 차단 (Anti-Rationalization)

LLM은 RLHF 훈련으로 인해 순응·지름길을 선호합니다. `| 변명 | 현실 |` 테이블로 명시 차단합니다.

| 변명 | 현실 |
|------|------|
| "이미 파일 내용을 안다" | 다른 에이전트가 수정했을 수 있다 |
| "확신한다" | 확신 ≠ 증거 |
| "단순한 변경이다" | 단순한 변경이 가장 많이 깨진다 |

**근거**:
- Sharma et al. (ICLR 2024) arXiv:2310.13548: RLHF가 아첨의 근본 원인
- Vennemeyer et al. (2025) arXiv:2509.21305: 아첨적 동의는 잠재 공간에서 분리 가능

### 원칙 8: 멀티 에이전트 수렴 (Multi-Agent Convergence)

하나의 프로젝트를 여러 AI 에이전트가 함께 다룹니다. 지침은 AGENTS.md 하나, 스킬은 Agent Skills 스펙 하나(`skills/` = `.agents/skills`), 워킹 상태(`.hxsk/`)는 공유합니다.

**Lock-in 없음**: 순수 마크다운이므로 어떤 에이전트든 읽고 쓸 수 있습니다.

---

## 3. 작성 원칙

### 문서 작성 규칙

| 대상 | 규칙 |
|------|------|
| AGENTS.md (L1) | 정책 수준. 모든 플랫폼 공통. 예시/포맷/스키마 제외. 사용자 프로젝트에는 `hxsk-init`이 짧은 HXSK 블록(포인터)만 추가 |
| `.claude/CLAUDE.md` (L1) | `@../AGENTS.md` import + Claude 전용 규칙만 |
| SKILL.md (L2) | Agent Skills 스펙 frontmatter. ≤500줄. Quick Reference ≤5줄 |
| `agents/*.md` (L2) | 격리가 필요한 역할만. `skills:`로 스킬 preload + 오케스트레이션 |
| references/ (L3) | 상세·근거. 스킬 디렉터리 안에 self-contained |

### 스킬 Description 규칙 (CSO)

- 무엇을 하는지 한 문장 + "Use when/at ..." 트리거
- 트리거 조건, 증상, 동의어(한국어 포함) 포함
- ≤1024자 (Agent Skills 스펙)
- 워크플로우 요약, 절차 설명 **금지**
- 에러 메시지, 도구명 포함 가능

### Iron Laws 작성 규칙

- `NO X WITHOUT Y FIRST` 형식
- 각 스킬의 `## Iron Laws` 섹션에 배치 (이 저장소 자체의 기여 규칙은 AGENTS.md Validation 섹션)
- 규칙당 한 줄
- 모든 플랫폼에 적용

### 합리화 테이블 작성 규칙

- `| 변명 | 현실 |` 포맷
- 규율 스킬(empirical-validation 등) 내부에 배치
- 에이전트의 실제 우회 패턴에서 수집
- 모델 업데이트 시 갱신 필요

---

## 4. 연구 기반

현재 아키텍처는 다음 연구를 분석하고 선택적으로 적용한 결과입니다.

### 메모리 시스템

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [A-Mem](https://arxiv.org/html/2502.12110v11) | frontmatter, related, 2-hop, compact | Memory Evolution |
| [Nemori](https://arxiv.org/html/2508.03341v3) | 타입 분리, contextual description, Predict-Calibrate(저장 전 중복 스킵으로 단순화) | — |

### 워크플로우

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) | SPEC→PLAN→EXECUTE 분리 | 전체 프레임워크 |
| [RLM](https://arxiv.org/html/2512.24601v2) | Phase → Plan → Task 구조 | Persistent REPL |
| [Git Worktree 멀티에이전트](https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution) | 파일 소유권 맵, 작업별 워크트리 격리, 컨플릭트 6유형 방지 | — |

### 에이전트 규율

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [Superpowers](https://github.com/obra/superpowers) | Iron Laws, Gate Functions, 합리화 테이블, CSO, 스킬 TDD(`skill-testing`), 2단계 리뷰(`spec-reviewer` → `pr-review`) | — |
| [Meincke et al. (2025)](https://papers.ssrn.com/sol3/papers.cfm?abstract_id=5357179) | Authority 기반 Iron Laws (N=28,000) | — |
| [Sharma et al. (ICLR 2024)](https://arxiv.org/abs/2310.13548) | 합리화 테이블 이론 근거 | — |
| [SkillReducer (2026)](https://arxiv.org/abs/2603.29919) | CSO description 최적화 | 본문 자동 압축 |
| [Wallace et al. (ICLR 2025)](https://arxiv.org/abs/2404.13208) | 명령 계층, Iron Laws 우선순위 | — |

### 품질 보증

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [Anthropic harness blog](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | Gate Function, 검증 체크포인트 | — |
| [Anthropic Context Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | Lazy Loading, 간결한 에이전트 정의 | — |
| [Anthropic multi-agent](https://www.anthropic.com/engineering/multi-agent-research-system) | 컨텍스트 격리, 역할 분리 | — |
