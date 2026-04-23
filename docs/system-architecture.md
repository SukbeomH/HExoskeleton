# System Architecture

> HExoskeleton의 컴포넌트 관계와 데이터 흐름.
>
> 수준: L1 공개 아키텍처 · 상세 ADR은 `.hxsk/DECISIONS.md` 참조

## 1. High-Level Component View

```mermaid
graph TB
    User[User / Developer]

    subgraph Harness["AI 코딩 에이전트 하네스 (10+)"]
        CC[Claude Code]
        GC[Gemini CLI]
        CU[Cursor]
        CP[Copilot CLI]
        WS[Windsurf]
        OC[OpenCode]
        CX[Codex]
    end

    subgraph HXSK[".hxsk/ — 공유 외골격"]
        Skills[skills/<br/>22 재사용 절차]
        Agents[agents/<br/>18 오케스트레이터]
        Hooks[hooks/<br/>21 이벤트 훅]
        Scripts[scripts/<br/>12 유틸리티]
        Memory[memories/<br/>17 타입 × 2-hop]
        Workflow[workflow/GATES.md<br/>8 게이트]
        Templates[templates/<br/>33 템플릿]
        State[STATE.md<br/>CURRENT.md<br/>SPEC.md]
        Research[research/<br/>L3 근거]
    end

    subgraph Outputs["빌드 타겟"]
        Plugin[hxsk-plugin/]
        Antigrav[antigravity-<br/>boilerplate/]
        OpenCodeOut[opencode-<br/>boilerplate/]
    end

    User --> Harness
    Harness -->|Session Start| Hooks
    Hooks -->|Load| State
    Hooks -->|Recall| Memory
    Agents -->|Invoke| Skills
    Skills -->|Store| Memory
    Skills -->|Check| Workflow
    Skills -->|Use| Templates
    Skills -->|Reference| Research

    HXSK -.Build.-> Outputs

    style HXSK fill:#f0f8ff,stroke:#4a90e2
    style Harness fill:#fffacd,stroke:#daa520
    style Outputs fill:#e8f5e9,stroke:#4caf50
```

## 2. Agent-Skill Wrapping Pattern

HXSK는 **How / When-With-What** 분리 원칙을 엄격히 적용한다:

```mermaid
graph LR
    subgraph Agent["Agent (When/With What) — ~20 lines"]
        AF[Frontmatter<br/>model, tools, description]
        AB[Body<br/>## 탑재 Skills<br/>## 실행 순서]
    end

    subgraph Skill["Skill (How) — entry ≤200줄 + references/"]
        SF[Frontmatter<br/>name, description, trigger]
        SB[Quick Reference ≤5 lines<br/>+ 핵심 흐름 요약<br/>+ references/ 링크]
        SR[references/<br/>execution-flow.md<br/>deviation-rules.md 등]
    end

    subgraph Infra["Infrastructure"]
        H[Hooks<br/>PreToolUse/Stop]
        M[Memory Protocol]
    end

    Agent -->|mounts| Skill
    Skill -->|calls| M
    H -->|enforces| Skill
```

**크기 제약 (Progressive Disclosure — Phase 9)**:
- Agent body ≤ 20-30 lines (상세는 Skill에 위임)
- Skill Quick Reference ≤ 5 lines
- **Skill entry SKILL.md ≤ 200줄** (verifier/debugger ≤ 160줄)
- **Skill 상세는 `references/` 서브디렉토리로 분리** (선택 로드)
- CLAUDE.md ≤ 120 lines
- PATTERNS.md ≤ 2KB / 20 items

Phase 9 분할 결과: executor 681→98줄, planner 566→177줄, verifier 452→135줄, debugger 365→119줄 (~65-86% 절감).

근거: **SkillReducer 연구(2026)**는 48% 설명 압축 + 2.8% 품질 개선을 보고. **Anthropic 내부**는 시스템 프롬프트 ~1,800 tokens 최적, >2,500 tokens에서 34% 환각 증가를 관찰.

## 3. Session Lifecycle

```mermaid
sequenceDiagram
    participant U as User
    participant H as Harness
    participant SS as session-start.sh
    participant S as .hxsk/STATE.md
    participant C as .hxsk/CURRENT.md
    participant M as memories/
    participant A as Agent/Skill
    participant Mod as track-modifications.sh
    participant AF as auto-format.sh
    participant Stop as stop-context-save.sh

    U->>H: claude code (세션 시작)
    H->>SS: SessionStart event
    SS->>S: Load STATE.md (active gate, tasks)
    SS->>C: Load CURRENT.md (narrative)
    SS->>M: Recall (2-hop grep)
    SS-->>H: Context injected

    U->>H: "/skill planner"
    H->>A: Invoke agent
    A->>A: Read SPEC.md, run skill
    A-->>H: Output (PLAN.md)

    H->>Mod: PostToolUse (Edit/Write)
    Mod->>S: Log modified files
    H->>AF: PostToolUse format

    U->>H: Ctrl+C (session end)
    H->>Stop: Stop event
    Stop->>C: Regenerate CURRENT.md (Nemori narrative)<br/>atomic mv flag claim (race-condition 방지)
    Stop->>M: Store session-summary memory
```

## 4. Memory System (A-Mem + ReWOO + Nemori)

```mermaid
graph TB
    subgraph Store["저장 경로"]
        Agent[Agent action]
        Hook[Hook event]
        Agent --> MS[md-store-memory.sh]
        Hook --> MS
        MS -->|yaml_safe() sanitize<br/>YAML injection 방지| Safe[안전한 frontmatter]
        Safe -->|YAML frontmatter| File[memories/{type}/YYYY-MM-DD_{slug}.md]
        MS -->|TYPE_DIR auto-create| File
        MS -->|Nemori dedup| Skip{중복?}
        Skip -.Yes.-> Skipped[Skip write]
        Skip --No--> File
    end

    subgraph Recall["회상 경로"]
        Query[Query string]
        Query --> MR[md-recall-memory.sh]
        MR -->|grep| Idx1[1st hop: keywords, title]
        Idx1 --> Related[related field]
        Related -->|2-hop frontmatter 한정<br/>awk /^---$/| Idx2[2nd hop: 연관 메모리]
        Idx2 --> Result[Compact or Full 결과<br/>HXSK_RECALL_MAX 줄 제한]
        MR -->|결과 없음| NoMatch[[stderr: NO_MATCH]]
    end

    subgraph Prune["프룬 사이클"]
        Trigger[md-store or bootstrap 호출]
        Trigger --> PT[prune-tick.sh<br/>60s cooldown<br/>stale lock 300s 감지]
        PT -->|Lock OK| PM[prune-memories.sh --auto]
        PM -->|tier cap=5| Local[local tier 프룬]
        PM -->|value elevation| Shared[decision/root-cause<br/>→ shared tier]
    end

    File -.- Recall
    File -.- Prune
```

### A-Mem 필드 (각 메모리 파일의 frontmatter):
```yaml
---
name: short-title
type: root-cause | architecture-decision | ... (17 types)
keywords: [bug, auth, session-token]
contextual_description: "≤200자 요약 — 어떤 맥락에서 유용한가"
related: [slug-of-related-memory-1, slug-of-related-memory-2]
created: YYYY-MM-DD
---
```

### Tier 분리:
- **local/** — 세션 단기 메모리. gitignored. TTL + cap=5.
- **shared/** — 장기 지식. git 추적. 가치 태그(`decision`, `root-cause`, `architecture-decision`, `incident`) 보유 시 자동 승격.

## 5. Workflow Gates (SPEC → PLAN → EXECUTE → VERIFY → DONE)

```mermaid
stateDiagram-v2
    [*] --> GATE_0: SPEC.md 작성
    GATE_0 --> GATE_P1: Goals/Scope 확정
    GATE_P1 --> GATE_P2: feat/plan-{name} 브랜치
    GATE_P2 --> GATE_P3: 부모 이슈 생성
    GATE_P3 --> GATE_P4: PLAN.md tasks + files 선언
    GATE_P4 --> GATE_E0: sub-issues 생성
    GATE_E0 --> GATE_E1: Dispatcher 핸드오프
    GATE_E1 --> GATE_V0: Task PR 리뷰/승인
    GATE_V0 --> GATE_V1: 모든 sub-issues closed
    GATE_V1 --> GATE_V2: Conflict 해결, 테스트 통과
    GATE_V2 --> GATE_V3: Spec goals 검증
    GATE_V3 --> GATE_D0: 부모 PR merged
    GATE_D0 --> [*]: 결과 보고서 + 메모리 sync
```

게이트 조건 상세: `.hxsk/workflow/GATES.md`.

각 게이트는 `gate-check.sh`에 의해 검증되며, STATE.md에 기록된다.

## 6. Multi-Harness Adapter Pattern

HXSK는 Claude Code에 최적화되었지만 **10+ 하네스와 호환**된다. 핵심 설계는 "**opportunistic trigger + git fallback**":

```mermaid
graph TB
    subgraph Tier1["Tier 1: Opportunistic (기본, 설정 불필요)"]
        MStore[md-store-memory.sh]
        MRecall[md-recall-memory.sh]
        BS[bootstrap.sh]
        MStore --> Tick[prune-tick.sh<br/>60s cooldown]
        MRecall --> Tick
        BS --> Tick
        Tick -->|sentinel mtime<br/>mkdir atomic lock| PM[prune-memories.sh]
    end

    subgraph Tier2["Tier 2: Explicit Harness Hooks (선택)"]
        Cursor[cursor-hooks.json]
        Gemini[gemini-settings.json]
        Copilot[copilot-hooks.json]
        Windsurf[windsurf-hooks.json]
        OpenCode[opencode-plugin.ts]
        Cursor --> Tick
        Gemini --> Tick
        Copilot --> Tick
        Windsurf --> Tick
        OpenCode --> Tick
    end

    subgraph Tier3["Tier 3: Git Hook Fallback (lifecycle 훅 미지원 하네스)"]
        Aider[Aider]
        Continue[Continue]
        Antigrav[Antigravity]
        PostCommit[.hxsk/githooks/post-commit]
        PostMerge[.hxsk/githooks/post-merge]
        Aider -.writes.-> PostCommit
        Continue -.writes.-> PostCommit
        Antigrav -.writes.-> PostCommit
        PostCommit --> Tick
        PostMerge --> Tick
    end
```

**어댑터 드리프트 감지 및 동기화**:
- 드리프트 확인: `bash .hxsk/scripts/hxsk-harness-sync.sh --check`
- 동기화 적용: `bash .hxsk/scripts/hxsk-harness-sync.sh --sync`

**핵심 설계 결정 (DECISIONS.md)**: 외부 스케줄러(cron/launchd/systemd) 금지. `sentinel mtime + mkdir atomic lock`(BashFAQ/045)로 race condition 차단.

## 7. Dispatcher Wave 패턴 (병렬 실행)

5+ 독립 태스크가 있을 때 `dispatcher` skill이 활성화된다:

```mermaid
graph LR
    subgraph SPLIT["Phase 1: SPLIT"]
        PLAN[PLAN.md] --> Tasks[Task 1..N]
    end

    subgraph BRANCH["Phase 2: BRANCH"]
        Tasks --> W1[worktree-1<br/>feat/master/work-1]
        Tasks --> W2[worktree-2<br/>feat/master/work-2]
        Tasks --> W3[worktree-3<br/>feat/master/work-3]
    end

    subgraph Wave["Phase 3: Wave Loop"]
        W1 --> E1[executor]
        W2 --> E2[executor]
        W3 --> E3[executor]
        E1 --> M1[merge-worktrees.sh]
        E2 --> M1
        E3 --> M1
    end

    subgraph Verify["Phase 4: VERIFY"]
        M1 --> V[verifier<br/>SPEC.md must-haves]
        V --> Done[MERGED ✓]
    end
```

**규칙**:
- 같은 wave의 태스크는 동일 파일 수정 금지 (GATE-P3에서 검증)
- lockfile 수정 태스크는 `parallel: false` 필수
- 파일 소유권 선언 없이 병렬 작업 금지 (AGENTS.md Iron Law)

## 8. Build Pipeline (멀티 플랫폼)

```mermaid
graph LR
    Source[HExoskeleton 소스] --> BC[build-common.sh]
    BC --> BP[build-plugin.sh<br/>Claude Code]
    BC --> BA[build-antigravity.sh<br/>Antigravity IDE]
    BC --> BO[build-opencode.sh<br/>OpenCode]

    BP --> PathSub[${CLAUDE_PLUGIN_ROOT}<br/>경로 치환]
    BA --> PathSub
    BO --> PathSub2[OpenCode 경로 치환]

    PathSub --> PluginOut[hxsk-plugin/]
    PathSub --> AntigravOut[antigravity-boilerplate/]
    PathSub2 --> OCOut[opencode-boilerplate/]

    PluginOut -.GitHub Release.-> Artifact[hxsk-plugin-{ver}.zip]
```

**경로 전략(DECISION-001)**: `scripts/md-*.sh`는 `.hxsk/hooks/`의 심볼릭 링크. 빌드 시 `${CLAUDE_PLUGIN_ROOT}/scripts/`로 자동 치환되어 플러그인 환경에서도 동작.

## 9. Data Flow: "/skill executor" 실행 예시

```mermaid
sequenceDiagram
    participant U as User
    participant H as Harness
    participant A as executor agent
    participant S as executor skill
    participant MP as memory-protocol skill
    participant GH as githooks
    participant PM as prune-memories

    U->>H: /skill executor (PLAN.md 주어짐)
    H->>A: Invoke executor agent
    A->>S: Load executor SKILL.md (entry ≤200줄)
    Note over S: 필요 시 references/ 선택 로드<br/>(execution-flow, deviation-rules 등)
    S->>MP: Recall past deviations (2-hop)
    MP-->>S: 관련 lessons-learned

    loop 각 PLAN.md task
        S->>S: Read task spec
        S->>S: Read referenced files (NO EDIT WITHOUT READ)
        S->>S: Implement change
        S->>S: git commit (atomic)
        S->>MP: Store execution-summary
    end

    S->>S: Generate SUMMARY.md
    S-->>A: Execution done
    A-->>H: Output + commit list

    Note over GH,PM: 비동기 (post-commit 훅)
    GH->>PM: prune-tick.sh (60s cooldown)
    PM->>PM: --auto mode<br/>local-tier cap=5
```

## 10. Context Compaction Strategy

Claude Code가 컨텍스트 한계에 가까워지면 자동 압축을 트리거한다. HXSK는 이 순간을 **데이터 보존 기회**로 활용:

```mermaid
graph TB
    Full[Full Context<br/>~200K tokens] --> PC{PreCompact 이벤트}
    PC --> Save[pre-compact-save.sh]
    Save --> Snap[memories/session-snapshot/<br/>현재 스냅샷 저장]
    Save --> Trim[PATTERNS.md → 20 items/2KB]
    Save --> Arc[오래된 JOURNAL/CHANGELOG → archive/]

    PC --> Compact[Harness 압축 실행]
    Compact --> Restored[Compact된 컨텍스트]

    Restored -.Next session.-> Load[session-start.sh에서<br/>snapshot 회상]
```

상세: `.hxsk/hooks/pre-compact-save.sh`, `compact-context.sh`.

## 11. Key Architectural Decisions

| ADR | 결정 | 근거 |
|-----|------|------|
| DECISION-001 | `scripts/md-*.sh`는 심볼릭 링크 | 빌드 시 경로 치환으로 플러그인/네이티브 양쪽 동작 |
| (미번호) | 외부 Vector DB 금지 | bash `grep`이 충분. zero-dep 원칙 |
| (미번호) | Opportunistic prune-tick | cron/launchd 의존 없이 cooldown 60s 자가 트리거; stale lock 300s 감지 |
| (미번호) | Tier 분리 (local/shared) | git 추적 비용 vs 장기 지식 보존 밸런스 |
| (미번호) | GATES.md 파일 기반 검증 | AGENTS.md의 "Forge-agnostic" 원칙 — GitHub 없어도 동작 |
| (미번호) | 17 memory types | A-Mem + 도메인 특화(debug/security/session/test) 혼합; `test` 타입은 PR #138에서 정식 추가 (16→17) |
| (미번호) | `.prune-config` owner+perm 검증 | 그룹/월드-쓰기 가능 config 소싱 시 WARN+스킵 — 권한 상승 방지 |
| (미번호) | `yaml_safe()` + 2-hop frontmatter 한정 | YAML injection 방지; body false-match 제거 |

전체 ADR: `.hxsk/DECISIONS.md`.

## See Also

- [Project Overview](project-overview-pdr.md) — Why / 원리
- [Codebase Summary](codebase-summary.md) — 파일 인벤토리
- [Code Standards](code-standards.md) — 컨벤션과 Iron Laws
- [Deployment Guide](deployment-guide.md) — 빌드 파이프라인 상세
- [Configuration Guide](configuration-guide.md) — 설정 키 레퍼런스
- `.hxsk/DECISIONS.md` — 전체 ADR 이력
- `.hxsk/research/memory-systems/` — A-Mem, Nemori, ReWOO 근거
