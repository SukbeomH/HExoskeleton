---
allowed-tools:
- Read
- Write
- Grep
- Glob
- Bash
description: Use when debugging bugs to find root causes, or after 3 failed fix attempts
  to stop and document state.
name: debugger
trigger: 버그 디버깅, 오류 원인 찾기, 에러 추적, root cause, unexpected behavior, bug investigation,
  3 strike rule, 가설 검증, hypothesis testing, meta debugging, self code review, debug
  memory search, 과거 디버그 기록, systematic investigation, 변수 변경 테스트, 편향 피하기, 3 회 실패 후
  중단, fresh session, 상태 기록, root cause 분석, 증빙 기반 디버깅
---

## Quick Reference
- **3-Strike Rule**: 3회 실패 시 즉시 중단 → STATE.md 기록 → fresh session 권장
- **Memory First**: 조사 전 `.hxsk/memories/` 검색으로 과거 유사 사례 확인
- **Valid Hypothesis**: 반증 가능해야 함 (구체적 원인 명시, 추측 금지)
- **One Variable**: 한 번에 하나의 변수만 변경하여 테스트 및 문서화
- **Persist Findings**: 원인 발견 시 `root-cause`, 배제 시 `debug-eliminated` 저장

## Core Philosophy

### User = Reporter, AI = Investigator

**User knows:** what they expected, what happened, error messages, when it started.

**User does NOT know (don't ask):** what's causing it, which file, what the fix is.

Ask about experience. Investigate the cause yourself.

### Meta-Debugging: Your Own Code

When debugging code you wrote, you're fighting your own mental model.

- **Treat your code as foreign** — Read it as if someone else wrote it
- **Question your design decisions** — Your implementations are hypotheses
- **Admit your mental model might be wrong** — Code behavior is truth
- **Prioritize code you touched** — Modified lines are prime suspects

---

## Foundation Principles

- **What do you know for certain?** Observable facts, not assumptions
- **What are you assuming?** "This library should work this way" — verified?
- **Strip away everything you think you know.** Build understanding from facts.

---

## Cognitive Biases to Avoid

| Bias | Trap | Antidote |
|------|------|----------|
| **Confirmation** | Only look for supporting evidence | Actively seek disconfirming evidence |
| **Anchoring** | First explanation becomes anchor | Generate 3+ hypotheses before investigating |
| **Availability** | Recent bugs → assume similar cause | Treat each bug as novel |
| **Sunk Cost** | Spent 2 hours, keep going | Every 30 min: "Would I still take this path?" |

---

## Systematic Investigation

**Change one variable:** Make one change, test, observe, document, repeat.

**Complete reading:** Read entire functions, not just "relevant" lines.

**Embrace not knowing:** "I don't know" = good (now you can investigate). "It must be X" = dangerous.

**Debugging Techniques + Hypothesis Testing + When to Restart** → `references/debugging-techniques.md`

---

## 3-Strike Rule

After 3 failed fix attempts:

1. **STOP** the current approach
2. **Document** what was tried in DEBUG.md
3. **Summarize** to STATE.md
4. **Recommend** fresh session with new context

A fresh context often immediately sees what polluted context cannot.

---

## Debug Memory

Before any investigation, search past context:

```
Grep(pattern: "{symptom}", path: ".hxsk/memories/", output_mode: "files_with_matches")
```

Persist findings after each session (elimination, root cause, blocked state).

**Debug Memory 전체 프로토콜** → `references/debug-memory.md`

---

## 관련 스킬

- **REQUIRED**: `empirical-validation` — 수정 후 경험적 증거로 검증
- **REQUIRED**: `memory-protocol` — 근본 원인, 배제된 가설을 메모리에 저장
- **RECOMMENDED**: `impact-analysis` — 수정 전 영향 범위 분석

## Scripts

(없음 — Bash, Read, Grep 등 에이전트 네이티브 도구로 직접 수행)

## Iron Laws
NO CONTINUE_AFTER_3_FAILURES WITHOUT STATE_RECORDING_AND_FRESH_SESSION FIRST
NO HYPOTHESIS_FORMULATION WITHOUT FALSIFIABILITY FIRST
NO CHANGE_WITHOUT_ISOLATING_SINGLE_VARIABLE FIRST
NO DIAGNOSIS_WITHOUT_COMPLETE_FUNCTION_READING FIRST
NO INVESTIGATION_WITHOUT_PAST_MEMORY_SEARCH FIRST
NO ASKING_USER_FOR_ROOT_CAUSE FIRST
NO INVESTIGATION_WITHOUT_3_PLUS_HYPOTHESES FIRST
NO DEBUGGING_WITHOUT_TREATING_CODE_AS_FOREIGN FIRST
NO SESSION_END_WITHOUT_MEMORY_PERSISTENCE FIRST
