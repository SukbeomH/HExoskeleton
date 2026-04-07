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
| Python/Node 런타임 | 미채택 | 환경 구성 필수, 에이전트 도구만으로 충분 |
| **순수 bash + 마크다운** | **채택** | 외부 종속성 0, 빌드 0, 레포 = 배포 단위 |

**근거**: [Anthropic Context Engineering Guide](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — "가장 작은 고신호 토큰 집합"

### 관찰 2: 파일 시스템이 곧 데이터베이스다

마크다운 파일은 사람이 읽을 수 있고, `git diff`로 변경을 추적할 수 있고, 어떤 에이전트든 `Read` 한 번이면 접근할 수 있습니다.

**근거**:
- [A-Mem](https://arxiv.org/html/2502.12110v11): 7-속성 노트 + 2-hop 그래프 검색
- [Nemori](https://arxiv.org/html/2508.03341v3): 타입 분리 + 중복 제거 + contextual description

### 관찰 3: 에이전트는 "어떻게"보다 "언제, 무엇으로"가 중요하다

절차는 스킬(Skill)에, 오케스트레이션은 에이전트(Agent) 정의에 분리합니다.

**근거**:
- Anthropic 내부 테스트: 시스템 프롬프트 ~1,800 토큰 최적 구간
- Microsoft/Stanford 연구: 2,500 토큰 초과 시 환각 34% 증가
- [RLM](https://arxiv.org/html/2512.24601v2): Agent-Skill 래핑, Phase → Plan → Task 구조

---

## 2. 설계 원칙

### 원칙 1: Lazy Loading 문서 계층

에이전트가 필요한 만큼만 읽도록 3단계로 구조화합니다.

| 레벨 | 내용 | 토큰 | 규칙 |
|------|------|------|------|
| **L0** | YAML frontmatter | ~50 | 스캔용 |
| **L1** | CLAUDE.md, AGENTS.md | ~200-500 | 정책·제약·트리거만. ≤120줄 |
| **L2** | SKILL.md, Agent.md | ~300-1000 | 상세 절차. Quick Reference ≤5줄 |
| **L3** | .hxsk/research/ | ~1000+ | 출처·근거. 필요 시에만 |

**규칙**: L1에는 정책, L2에는 절차, L3에는 근거. 상위 레벨은 하위를 참조하되 내용을 복제하지 않는다.

**근거**: SkillReducer (Gao et al., 2026, arXiv:2603.29919) — 55K 스킬 분석, description 압축 시 품질 2.8% 향상 (less-is-more). 60%+ 본문이 비실행 내용.

### 원칙 2: Skill-Agent 분리 (How vs When)

**Skill = How** (재사용 가능한 절차). **Agent = When/With What** (오케스트레이션).

```
Agent (~20줄) → "디버깅 시 systematic-debugging 스킬 사용"
                 │ 위임
                 ▼
Skill (~100-300줄) → "1. 에러 수집 2. 가설 수립 3. 검증..."
```

에이전트 정의가 간결할수록 에이전트는 정확하게 동작합니다.

**근거**: Anthropic Context Engineering (2025) — "smallest set of high-signal tokens that maximize the likelihood of your desired outcome."

### 원칙 3: CSO (Claude Search Optimization)

스킬 description에는 **트리거 조건만** 기재합니다. 워크플로우 요약을 포함하면 에이전트가 본문을 건너뜁니다.

```yaml
# Bad — 워크플로우 요약 포함
description: "메모리를 저장하고 검색하는 프로토콜. 2-hop 검색과 14타입 분류를 지원"

# Good — 트리거 조건만
description: "Use when storing or retrieving project knowledge, after architecture decisions, bug fixes, or session ends"
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
Layer 1 (정책):   AGENTS.md Iron Laws          — 항상 로딩
Layer 2 (절차):   SKILL.md 합리화 테이블/게이트  — 스킬 로딩 시
Layer 3 (인프라): PreToolUse/Stop 훅           — thinking 무관 항상 실행
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

### 원칙 8: 수렴적 부트스트랩 (Convergent Bootstrap)

`bootstrap.sh`는 멱등(idempotent) 수렴 엔진입니다. 몇 번을 실행해도 동일한 최종 상태에 도달합니다.

```
fresh   → 모든 컴포넌트 생성, 카운트 기록
update  → 기존과 비교, 변경분만 표시
verify  → 구조 검증, 누락 자동 보충
```

### 원칙 9: 멀티 에이전트 수렴 (Multi-Agent Convergence)

하나의 프로젝트를 여러 AI 에이전트가 동시에 관리합니다. 에이전트 지침은 분리하되, 워킹 상태(`.hxsk/`)는 공유합니다.

**Lock-in 없음**: 순수 마크다운이므로 어떤 에이전트든 읽고 쓸 수 있습니다.

---

## 3. 작성 원칙

### 문서 작성 규칙

| 대상 | 규칙 |
|------|------|
| CLAUDE.md (L1) | ≤120줄. 검색 순서/트리거/제약만. 예시/포맷/스키마 제외 |
| AGENTS.md (L1) | 정책 수준. 모든 플랫폼 공통. Iron Laws 포함 |
| SKILL.md (L2) | Quick Reference ≤5줄. description = 트리거 조건만 (CSO) |
| Agent.md (L2) | ~20-30줄. 탑재 스킬 목록 + 오케스트레이션 |
| Research (L3) | 근거·출처. 필요 시에만 참조 |

### 스킬 Description 규칙 (CSO)

- "Use when..." 패턴으로 시작
- 트리거 조건, 증상, 동의어 포함
- 워크플로우 요약, 절차 설명 **금지**
- 에러 메시지, 도구명 포함 가능

### Iron Laws 작성 규칙

- `NO X WITHOUT Y FIRST` 형식
- AGENTS.md Validation 섹션에 배치
- 3줄 이내
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
| [Nemori](https://arxiv.org/html/2508.03341v3) | 타입 분리, 중복 제거, contextual description | Predict-Calibrate |

### 워크플로우

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [ReWOO](https://github.com/weitianxin/Awesome-Agentic-Reasoning) | SPEC→PLAN→EXECUTE 분리 | 전체 프레임워크 |
| [RLM](https://arxiv.org/html/2512.24601v2) | Agent-Skill 래핑 | Persistent REPL |

### 에이전트 규율

| 출처 | 적용 | 미적용 |
|------|------|--------|
| [Superpowers](https://github.com/obra/superpowers) | Iron Laws, Gate Functions, 합리화 테이블, CSO | 스킬 TDD, 2단계 리뷰 (Phase 2) |
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

---

## 5. 방향성 (로드맵)

### Phase 1: 규율 강화 (구현 완료)
Iron Laws, 합리화 테이블, Gate Function, CSO, PreToolUse/Stop 훅

### Phase 2: 검증 체계 고도화 (계획)
Gate Function 스킬화, 보조 문서 시스템, 2단계 리뷰 (spec→quality), PreToolUse 훅 강화

### Phase 3: 스킬 품질 보증 (계획)
스킬 TDD (서브에이전트 압박 시나리오), 프롬프트 템플릿 표준화, 합리화 테이블 자동 갱신

---

## 참고 문서

| 문서 | 위치 |
|------|------|
| Superpowers 분석 | `.hxsk/research/superpowers-analysis.md` |
| 근거 논문 20개 | `.hxsk/research/superpowers-references.md` |
| 품질 저하 완화 | `.hxsk/research/claude-code-quality-mitigation.md` |
| Phase 1 설계 | `.hxsk/docs/PLAN-phase1-discipline.md` |
| Phase 1 플로우차트 | `.hxsk/docs/PLAN-phase1-flowchart.md` |
