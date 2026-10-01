---
name: verifier
description: "Verifies implemented work against the spec at three levels (exists, substantive, wired), scans for stubs, placeholders and anti-patterns, and appends a dated section to .hxsk/VERIFICATION.md. Use when code exists and phase completion must be confirmed (구현 검증, 완료 확인)."
---

## Quick Reference
- **Substance 검증**: `TODO/placeholder` 등 스텁 코드가 존재하면 즉시 **FAILED** 판정
- **Wiring 확인**: 파일 존재만으로는 부족, 실제 호출/연결 (Key Links)이 있어야 **VERIFIED**
- **Human 필요**: UI/Real-time/외부 서비스 검증이 필요하면 자동 검증 중단 및 **human_needed**
- **Status 결정**: 모든 Truths 검증 + Blocker 없음 = **passed**, 그 외 = **gaps_found**
- **Evidence 원칙**: 주장이 아닌 `grep` 등 실증적 증거 없이는 **VERIFIED** 불가

## Core Principle

**Trust nothing. Verify everything.**

- SUMMARY.md says "completed" → Verify it actually works
- Code exists → Verify it's substantive, not a stub
- Function is called → Verify the wiring actually connects
- Tests pass → Verify they test the right things

---

## Verification Process

### Step 0: Check for Previous Verification

```bash
grep -n '^## ' .hxsk/VERIFICATION.md   # dated sections; find the latest one for this scope
```

**RE-VERIFICATION MODE** (latest section for this scope has `gaps_found`): Extract must-haves + gaps → set `is_re_verification = true` → Skip to Step 3 (failed items: full check; passed items: quick regression).

**INITIAL MODE** (no previous): set `is_re_verification = false`, proceed Step 1.

### Step 1: Load Context (Initial Mode Only)

```bash
ls .hxsk/phases/{N}/*-PLAN.md && ls .hxsk/phases/{N}/*-SUMMARY.md
cat .hxsk/SPEC.md   # Goals + Success Criteria
```

### Step 2: Establish Must-Haves (Initial Mode Only)

**Option A:** Read from PLAN frontmatter (`must_haves.truths`, `.artifacts`, `.key_links`).

**Option B:** Derive from phase goal — truths (observable behaviors), artifacts (concrete files), key_links (critical wiring: component → API → DB).

### Step 3: Verify Observable Truths

For each truth: identify artifacts → check levels (Step 4) → check wiring (Step 5) → assign ✓ VERIFIED / ✗ FAILED / ? UNCERTAIN.

### Step 4: Verify Artifacts (Three Levels)

- **L1 Existence:** `test -f "{path}"`
- **L2 Substantive:** `grep -E "TODO|placeholder|stub" "{path}"` — no stubs
- **L3 Wired:** imports used, exports consumed, functions called correctly

**Stub Detection Patterns** → `references/stub-detection.md`

### Step 5: Verify Key Links (Wiring)

Check each link exists: Component→API (`grep "fetch.*api/chat"`), API→DB (`grep "prisma\."`), Form→Handler (`grep -A5 "onSubmit"`), State→Render (`grep "messages\.map"`).

### Step 6: Check Requirements Coverage

Requirements are the `## Goals` and `## Success Criteria` items in `.hxsk/SPEC.md` that this scope covers.

Status per requirement: ✓ SATISFIED / ✗ BLOCKED / ? NEEDS HUMAN.

### Step 7: Scan for Anti-Patterns

```bash
grep -r -E "TODO|FIXME|XXX|HACK" src/**/*.ts
grep -r -E "placeholder|coming soon" src/**/*.tsx
grep -r -E "return null|return \{\}|return \[\]" src/**/*.ts
```

Categorize: 🛑 Blocker / ⚠️ Warning / ℹ️ Info.

### Step 8: Identify Human Verification Needs

Always human: visual appearance, user flow, real-time behavior (WebSocket/SSE), external services, performance feel.

### Step 9: Determine Overall Status

`passed` = all truths verified, no blockers. `gaps_found` = any truth failed/stub/unwired/blocker. `human_needed` = automated pass but human items exist. Score = `verified_truths / total_truths`.

### Step 10: Structure Gap Output

Structure gaps in YAML (truth, status, reason, artifacts, missing items) so the `planner` skill can write gap-closure plans (`gap_closure: true`).

---

## Recording the Result

Append **one dated section** to `.hxsk/VERIFICATION.md` (the only verification record — no per-phase files) and update its `## Latest` line. When running as the `verifier` agent (no write tools), return the section text instead; the caller appends it.

**Section format (single source)** → `references/verification-templates.md`

---

## 관련 스킬

- **REQUIRED**: `empirical-validation` — Gate Function 5단계로 완료 검증
- **RECOMMENDED**: `memory-protocol` — 검증 결과를 메모리에 저장
- **RECOMMENDED**: `impact-analysis` — 검증 범위 결정 시 영향 분석 참조

## 네이티브 도구 활용

```
# Stub/placeholder 패턴 탐지
Grep(pattern: "TODO|FIXME|NotImplementedError|pass$|return null|return \\{\\}", path: "src/", output_mode: "content")

# 파일 존재 확인
Glob(pattern: "src/**/*.{ts,js,py}")

# 파일 substance 확인 (빈 파일/최소 구현 탐지)
Read(file_path: "{file}") → 라인 수와 내용 확인
```

## Iron Laws
NO VERIFY WITHOUT EVIDENCE FIRST
NO COMPLETION WITHOUT VERIFICATION FIRST
NO EXISTENCE WITHOUT SUBSTANCE FIRST
NO WIRING WITHOUT CONNECTION FIRST
NO FINAL APPROVAL WITHOUT HUMAN VERIFICATION FIRST
NO PASS WITHOUT CLEAN CODE FIRST
