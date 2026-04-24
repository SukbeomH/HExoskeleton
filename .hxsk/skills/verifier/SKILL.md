---
description: Use when code exists but needs validation for stubs, wiring, and anti-patterns
  to confirm phase completion.
name: verifier
trigger: 구현 검증, 완료 확인, 페이즈 검증, verify implementation, check phase completion, validate
  against spec, stub 탐지, stub check, anti-pattern 스캔, verify wiring, 3-level 검증, 재검증,
  re-verification, gap 식별, identify gaps, empirical validation, verify code substance,
  check TODO/FIXME, verification report 생성, verify artifacts, verify key links, 재검증
  모드, re-verification mode, 인간 검증 필요, human verification needed, human needed, 가짜
  구현 탐지, fake implementation check, placeholder 탐지, placeholder check, 연결성 검증, connection
  verification, wiring check, 증거 기반 검증, evidence based verification, 반패턴 스캔, anti-pattern
  scan, blocker 확인, check blockers, 검증 상태 결정, determine verification status, gaps
  식별, identify gaps, 검증 템플릿 생성, generate verification template, stub-free 확인, stub-free
  check, TODO 스캔, TODO scan, FIXME 스캔, FIXME scan, 빈 파일 탐지, empty file check, 최소 구현
  탐지, minimal implementation check, 외부 서비스 검증, external service verification, UI 검증,
  UI verification, 실시간 검증, real-time verification, WebSocket 검증, WebSocket check,
  SSE 검증, SSE check, 성능 검증, performance verification, 요구사항 커버리지, requirements coverage,
  만족도 확인, satisfaction check, 검증 점수 계산, calculate verification score, VERIFICATION.md
  생성, generate VERIFICATION.md, 검증 결과 저장, save verification result, 메모리 프로토콜, memory
  protocol, 영향 분석, impact analysis, 게이트 함수 검증, gate function verification, 신뢰성 검증,
  trust verification, 모든 것 검증, verify everything
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
ls .hxsk/phases/{N}/*-VERIFICATION.md 2>/dev/null
```

**RE-VERIFICATION MODE** (previous exists with gaps): Extract must-haves + gaps → set `is_re_verification = true` → Skip to Step 3 (failed items: full check; passed items: quick regression).

**INITIAL MODE** (no previous): set `is_re_verification = false`, proceed Step 1.

### Step 1: Load Context (Initial Mode Only)

```bash
ls .hxsk/phases/{N}/*-PLAN.md && ls .hxsk/phases/{N}/*-SUMMARY.md
grep "Phase {N}" .hxsk/ROADMAP.md
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

```bash
grep "Phase {N}" .hxsk/REQUIREMENTS.md
```

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

Structure gaps in YAML for `/plan --gaps` (truth, status, reason, artifacts, missing items).

---

## VERIFICATION.md Format

Sections to include: frontmatter (phase/verified/status/score/is_re_verification/gaps), Must-Haves (Truths table, Artifacts table, Key Links table), Anti-Patterns Found, Human Verification Needed, Gaps, Verdict.

**VERIFICATION.md 전체 템플릿** → `references/verification-templates.md`

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
