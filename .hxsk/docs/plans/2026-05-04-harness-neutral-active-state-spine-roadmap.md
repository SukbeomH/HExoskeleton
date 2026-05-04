---
phase: 2
plan: R4
wave: 0
depends_on:
  - .hxsk/docs/plans/2026-05-04-hermes-working-memory-spine-applicability.md
files_modified:
  - .hxsk/scripts/active-state.sh
  - .hxsk/hooks/session-start.sh
  - .hxsk/hooks/stop-context-save.sh
  - .hxsk/hooks/pre-compact-save.sh
  - .hxsk/scripts/bootstrap.sh
  - .hxsk/scripts/setup-verify.sh
  - .hxsk/scripts/verify-self-configure.sh
  - .hxsk/hooks/check-consistency.sh
  - .hxsk/hooks/scaffold-hxsk.sh
autonomous: true
user_setup: []
must_haves:
  truths:
    - "HXSK는 Hermes 특화 통합이 아니라 harness-neutral active-state spine를 core feature로 제공해야 한다"
    - "초기 URL(context-mode) 문맥의 핵심은 토큰 절감보다 context continuity, compaction aftercare, tool-output isolation, recall discipline 이다"
    - "병렬 작업은 same-worktree multi-writer를 기본 허용하지 않고 worktree-isolated execution slices를 기본값으로 둔다"
  artifacts:
    - .hxsk/docs/plans/2026-05-04-harness-neutral-active-state-spine-roadmap.md
cross_phase_invariants:
  inherit: []
  new:
    - "global harness layer는 transport/plumbing, repo-local HXSK는 meaning/state/verification SSOT를 맡는다"
    - "CURRENT.md / SESSION_HANDOFF.md 는 latest local snapshot, STATE.md / VERIFICATION.md 는 coordination surface 성격을 유지한다"
---

# HXSK Harness-Neutral Active-State Spine Roadmap

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** HXSK에 긴 세션 continuity / compaction aftercare / 상태 복원을 하네스-중립 core feature로 도입하고, 병렬 작업을 worktree-isolated execution model 위에서 안전하게 운영할 수 있도록 정리합니다.

**Architecture:** HXSK의 repo-local source of truth를 `CURRENT.md / STATE.md / SESSION_HANDOFF.md / VERIFICATION.md` 중심의 canonical active-state surface로 고정합니다. 하네스별 훅/플러그인은 이 surface를 읽고 쓰는 thin bridge 로만 남기고, continuity/recall/aftercare 규칙은 HXSK core script와 verify layer에서 강제합니다.

**Tech Stack:** bash, markdown, git worktrees, repo-local hooks, file-based memories, local verification scripts.

---

## 1. URL 개념을 HXSK 언어로 재해석

최초 URL의 핵심 개념은 다음과 같이 해석합니다.

1. **컨텍스트 절약보다 컨텍스트 탑재 통제**
   - 큰 로그/원시 툴 출력/DOM snapshot/대량 grep 결과를 대화창에 그대로 올리지 않는다.
   - HXSK에서는 이를 **repo-local artifact + verify output + memory tier split** 으로 다룬다.

2. **세션 연속성(session continuity)**
   - 모델이 긴 대화를 기억하는 것이 아니라, 끊겨도 다시 복원할 수 있어야 한다.
   - HXSK에서는 `CURRENT / STATE / SESSION_HANDOFF / VERIFICATION` 이 그 복원 표면이다.

3. **Compaction aftercare**
   - compact 전 snapshot 과 compact 후 최소 잔여 표면을 명시한다.
   - HXSK에서는 `PreCompact` 백업, `Stop` snapshot, `session-summary / session-handoff` memory 를 통해 구현한다.

4. **Code-as-compression / procedure compression**
   - 판단을 대화에 누적하지 말고 스크립트, 스킬, 게이트, 템플릿으로 외부화한다.
   - HXSK에서는 `.hxsk/skills/`, `.hxsk/agents/`, `.hxsk/workflow/GATES.md`, `.hxsk/scripts/*` 가 해당한다.

5. **Thin bridge**
   - global harness 는 plumbing, HXSK repo-local layer는 의미/검증/상태를 담당한다.

6. **검색 가능한 회상(recall)**
   - past chat/log 전체가 아니라 필요한 artifact/memory 를 검색해 복원한다.
   - HXSK에서는 `md-recall-memory.sh`, memories tier, verification artifact 를 활용한다.

---

## 2. Core Vocabulary

이 작업의 canonical vocabulary는 아래로 고정합니다.

- **Canonical Active-State Surface**
  - `.hxsk/CURRENT.md`
  - `.hxsk/STATE.md`
  - `.hxsk/SESSION_HANDOFF.md`
  - `.hxsk/VERIFICATION.md`

- **Working-Memory Spine**
  - `SPEC.md`, `CURRENT.md`, `STATE.md`, `VERIFICATION.md`, `DECISIONS.md`, `PATTERNS.md`, `TODO.md`

- **Compaction Aftercare**
  - pre-compact snapshot → stop snapshot → memory prune/summary

- **Memory Tier Split**
  - harness memory = short pointer
  - HXSK memories = repo-specific long-form recall

- **Parallel Execution Slice**
  - 한 branch/worktree/agent 가 소유하는 독립 실행 단위

---

## 3. 병렬 작업 기본 모델

### 원칙
- **1 branch = 1 worktree = 1 active writer**
- same-worktree multi-writer 는 기본 금지
- 병렬성은 subagent 를 한 디렉터리에 몰아넣는 방식이 아니라 **worktree-isolated execution slices** 로 확보

### 문서별 소유권
- `CURRENT.md`
  - latest local snapshot
  - 세션/워크트리 단일 writer
- `SESSION_HANDOFF.md`
  - latest local re-entry note
  - 세션/워크트리 단일 writer
- `STATE.md`
  - structured coordination state
  - orchestration/gate transition 중심
- `VERIFICATION.md`
  - verification truth / evidence / verdict
  - 최종 verifier/integration owner 중심

### same-worktree 병렬 금지 이유
- stop hook 의 latest snapshot 쓰기가 last-writer-wins 충돌을 만든다.
- read-history / modified-session / track-log 류의 runtime 파일도 세션 단위 분리가 완전하지 않다.
- 따라서 병렬은 **새 worktree 생성**이 기본값이다.

---

## 4. 구현 대상

### Phase A — Active-State Core 도입
**Objective:** canonical active-state surface 를 HXSK core script 로 보장합니다.

**Files:**
- Create: `.hxsk/scripts/active-state.sh`
- Modify: `.hxsk/hooks/stop-context-save.sh`
- Modify: `.hxsk/hooks/session-start.sh`
- Modify: `.hxsk/hooks/pre-compact-save.sh`
- Modify: `.hxsk/hooks/scaffold-hxsk.sh`
- Modify: `.hxsk/scripts/bootstrap.sh`
- Modify: `.hxsk/scripts/setup-verify.sh`
- Modify: `.hxsk/scripts/verify-self-configure.sh`
- Modify: `.hxsk/hooks/check-consistency.sh`

**Definition of Done:**
- bootstrap/scaffold/self-configure 가 `CURRENT/STATE/SESSION_HANDOFF/VERIFICATION` 을 모두 보장한다.
- stop hook 이 `CURRENT.md` 와 `SESSION_HANDOFF.md` latest snapshot 을 갱신한다.
- session-start 가 handoff + current + state + verification 순으로 복원한다.
- pre-compact 가 handoff/verification 도 백업한다.
- consistency/setup/self-configure 검증에 active-state contract 가 포함된다.

### Phase B — Parallel Guardrails
**Objective:** 병렬 작업 운영 규칙을 문서와 검증에 명시합니다.

**Files:**
- Modify: `AGENTS.md`
- Modify: `docs/configuration-guide.md`
- Modify: `.hxsk/workflow/GATES.md`
- Optional: `.hxsk/agents/dispatcher.md`

**Definition of Done:**
- same-worktree concurrent writer 금지 문구가 명시된다.
- worktree-isolated execution slice 기본값이 문서화된다.
- `files:` ownership 뿐 아니라 state/verification ownership 의 원칙이 드러난다.

### Phase C — Compaction Aftercare 강화
**Objective:** compact 전후 잔여 상태를 구조적으로 다룹니다.

**Files:**
- Modify: `.hxsk/hooks/pre-compact-save.sh`
- Modify: `.hxsk/scripts/prune-memories.sh`
- Optional: `.hxsk/hooks/session-end.sh` / compact 관련 문서

**Definition of Done:**
- pre-compact snapshot 과 stop snapshot 의 책임 구분이 명확하다.
- compact 이후 최소 복원 표면이 항상 남는다.
- memory prune 이 canonical docs 를 손상시키지 않는다.

### Phase D — Cross-Harness Bridge Consolidation
**Objective:** Hermes/Codex/OpenCode 등 adapter 를 core contract 소비자로 정리합니다.

**Files:**
- Modify: `.hxsk/adapters/README.md`
- Modify: `.hxsk/adapters/hermes/README.md`
- Modify: `docs/codex-context-mode-hxsk-coexistence.md`

**Definition of Done:**
- 각 adapter 가 active-state surface read/write contract 를 동일하게 가리킨다.
- global plumbing vs repo-local semantics 계층 분리가 문서상 일치한다.

---

## 5. 병렬 실행 로드맵

### Wave 1 — Core script + hook wiring
병렬 가능:
- Task A: `active-state.sh` 추가, `stop-context-save.sh` / `session-start.sh` 반영
- Task B: `pre-compact-save.sh` / `bootstrap.sh` / `scaffold-hxsk.sh` 반영
- Task C: `setup-verify.sh` / `verify-self-configure.sh` / `check-consistency.sh` 반영

제약:
- 같은 파일을 여러 세션이 만지지 않도록 파일 소유권을 분리한다.
- merge 전에는 canonical verification bundle 을 한 번에 돌린다.

### Wave 2 — 문서/가드레일 정합화
병렬 가능:
- Task D: configuration/README/AGENTS 계층 정리
- Task E: GATES/dispatcher/parallel ownership 규칙 정리
- Task F: adapter readme / coexistence guide 정리

### Wave 3 — optional hardening
- worktree/session namespace 확대
- verification rollup helper
- active-state write owner enforcement
- task artifact → root verification rollup 자동화

---

## 6. 검증 기준

필수 검증:
```bash
bash .hxsk/scripts/doc-lint.sh
bash .hxsk/hooks/check-consistency.sh
bash .hxsk/scripts/setup-verify.sh
bash .hxsk/scripts/verify-self-configure.sh --all
bash .hxsk/scripts/local-verify.sh
```

병렬 운영 smoke check:
1. manager tree 에서 문서/plan closeout 유지
2. 별도 worktree 2개 생성
3. 각 worktree 가 `CURRENT.md`, `SESSION_HANDOFF.md` 를 local latest snapshot 으로 유지하는지 확인
4. root verification truth 는 마지막 integration pass 에서만 갱신

---

## 7. 위험과 완화

### 위험 1: `STATE.md` 성격 혼동
- 위험: narrative state 와 structured gate ledger 가 섞임
- 완화: `STATE.md` 는 구조화 상태 중심, narrative 는 `CURRENT.md`, next-session pointer 는 `SESSION_HANDOFF.md`

### 위험 2: same-worktree 병렬 writer 충돌
- 위험: last-writer wins
- 완화: worktree 분리 원칙 + 문서/검증 가드레일

### 위험 3: `VERIFICATION.md` 오염
- 위험: partial evidence 를 global verdict 처럼 기록
- 완화: task-local evidence 와 root verification verdict 를 분리

### 위험 4: 문서만 바뀌고 runtime 미반영
- 위험: drift 재발
- 완화: bootstrap/setup/self-configure/check-consistency 에 contract 검사 추가

---

## 8. Immediate Next Slice

가장 먼저 할 일:
1. `active-state.sh` 를 추가해 canonical surface 를 ensure 한다.
2. stop/session-start/pre-compact hook 을 core script 중심으로 재배선한다.
3. setup/self-configure/consistency 검증에 active-state contract 를 넣는다.
4. 이후 문서 가드레일과 adapter 계층을 정리한다.

이 순서가 좋은 이유는, 최초 URL 개념의 핵심인 **continuity / aftercare / controlled context loading** 을 가장 작은 runtime 단위에서 먼저 고정할 수 있기 때문입니다.
