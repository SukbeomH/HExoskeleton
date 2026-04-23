---
phase: 9
plan: "1D"
wave: 1
depends_on: []
files_modified:
  - .hxsk/skills/verifier/SKILL.md
  - .hxsk/skills/verifier/references/stub-detection.md
  - .hxsk/skills/verifier/references/verification-templates.md
  - .hxsk/skills/debugger/SKILL.md
  - .hxsk/skills/debugger/references/debugging-techniques.md
  - .hxsk/skills/debugger/references/debug-memory.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "verifier/SKILL.md가 ≤160줄이 되어 콜드스타트 컨텍스트 비용이 ~65% 절감된다"
    - "debugger/SKILL.md가 ≤160줄이 되어 콜드스타트 컨텍스트 비용이 ~55% 절감된다"
    - "Verification Process 핵심 흐름(3-Level: Existence/Substantive/Wired)이 entry에 유지된다"
    - "VERIFICATION.md Format 템플릿이 references에 완전히 보존된다"
    - "Debugger의 3-Strike Rule과 Rule Priority가 entry에 유지된다"
  artifacts:
    - ".hxsk/skills/verifier/SKILL.md 존재 (≤160줄)"
    - ".hxsk/skills/verifier/references/stub-detection.md 존재"
    - ".hxsk/skills/verifier/references/verification-templates.md 존재"
    - ".hxsk/skills/debugger/SKILL.md 존재 (≤160줄)"
    - ".hxsk/skills/debugger/references/debugging-techniques.md 존재"
    - ".hxsk/skills/debugger/references/debug-memory.md 존재"
  key_links:
    - "verifier entry의 Stub Detection → references/stub-detection.md"
    - "debugger entry의 Debugging Techniques → references/debugging-techniques.md"
---

# Plan 9.1D: verifier + debugger SKILL.md Progressive Disclosure 분할

<objective>
verifier(452줄)와 debugger(365줄)를 Progressive Disclosure 패턴으로 동시에 분할한다.
두 스킬 모두: Entry(≤160줄) + references/ 2개 파일씩

Purpose: 두 스킬 로드 시 컨텍스트 비용 각각 ~65%/~55% 절감
Output: 두 SKILL.md (≤160줄) + references/ 4개 파일
</objective>

<context>
Load for context:
- .hxsk/skills/verifier/SKILL.md (전체)
- .hxsk/skills/debugger/SKILL.md (전체)
</context>

<tasks>

<task type="auto">
  <name>리서치: verifier + debugger 전체 읽기 + 분할 경계 매핑</name>
  <files>읽기 전용</files>
  <action>
    **verifier/SKILL.md 분할 경계:**
    
    Entry (≤160줄):
    - frontmatter (9줄)
    - Quick Reference (7줄)
    - role (8줄)
    - Core Principle: Trust nothing. Verify everything. (10줄)
    - Verification Process: Step 번호 + 1줄 요약 (20줄) — 상세는 reference 불필요 (이미 간결)
    - 단, Stub Detection 패턴과 예제는 → references/stub-detection.md
    - VERIFICATION.md Format 핵심 섹션 구조 (20줄) — 전체 템플릿은 → references/verification-templates.md
    - 관련 스킬 섹션 유지

    References:
    - stub-detection.md: Universal/React/API Stub Patterns + Wiring Red Flags
    - verification-templates.md: VERIFICATION.md 전체 템플릿 + Must-Haves Structure 상세 + Anti-Patterns Found 예제

    ---

    **debugger/SKILL.md 분할 경계:**

    Entry (≤160줄):
    - frontmatter + Quick Reference + role
    - Core Philosophy: User=Reporter, AI=Investigator (10줄)
    - Foundation Principles + Cognitive Biases 요약 (15줄)
    - Systematic Investigation 흐름 (10줄)
    - 3-Strike Rule 요약 (5줄)
    - Debug Memory: 핵심 trigger만 (10줄) → 상세는 reference
    - "상세 → references/XXX.md" 링크

    References:
    - debugging-techniques.md: Debugging Techniques 전체 + Hypothesis Testing + When to Restart
    - debug-memory.md: Debug Memory 전체 (Prerequisites, Purpose, 저장 패턴 + 템플릿)

    AVOID: 3-Strike Rule을 references로 이동 — executor/AGENTS.md에서 참조됨
    AVOID: Cognitive Biases를 references로 이동 — 매 디버깅 세션 시작 시 참조 필요
  </action>
  <verify>두 스킬의 분할 경계가 정의됨, entry 예상 줄수 각각 ≤160 확인</verify>
  <done>verifier + debugger 분할 경계 모두 정의됨</done>
</task>

<task type="auto">
  <name>verifier + debugger entry 재작성 + references/ 파일 생성 (4개)</name>
  <files>
    .hxsk/skills/verifier/SKILL.md
    .hxsk/skills/verifier/references/stub-detection.md
    .hxsk/skills/verifier/references/verification-templates.md
    .hxsk/skills/debugger/SKILL.md
    .hxsk/skills/debugger/references/debugging-techniques.md
    .hxsk/skills/debugger/references/debug-memory.md
  </files>
  <action>
    **verifier 분할:**
    1. verifier/SKILL.md 재작성 (≤160줄):
       - frontmatter + QR + role + Core Principle 유지
       - Verification Process: 각 Step 2줄 이하 요약
       - Stub Detection: "패턴 목록 → references/stub-detection.md 참조"
       - VERIFICATION.md Format: 섹션명 목록만 + "전체 → references/verification-templates.md"
       - 관련 스킬 유지

    2. mkdir -p .hxsk/skills/verifier/references/
    3. references/stub-detection.md: Universal/React/API Stub Patterns + Wiring Red Flags 전체
    4. references/verification-templates.md: VERIFICATION.md 전체 템플릿 + Must-Haves 상세 + Anti-patterns + Human Verification 섹션

    ---

    **debugger 분할:**
    5. debugger/SKILL.md 재작성 (≤160줄):
       - frontmatter + QR + role 유지
       - Core Philosophy + Foundation Principles 유지 (핵심)
       - Cognitive Biases to Avoid: 목록만 (이름+1줄)
       - Systematic Investigation: 흐름 유지
       - 3-Strike Rule: 완전히 유지 (다른 파일이 참조)
       - Debug Memory: trigger 한 줄 + "상세 → references/debug-memory.md"
       - Debugging Techniques: "→ references/debugging-techniques.md"
       - When to Restart + Hypothesis Testing: "→ references/debugging-techniques.md"

    6. mkdir -p .hxsk/skills/debugger/references/
    7. references/debugging-techniques.md: Debugging Techniques 전체 + Hypothesis Testing + When to Restart
    8. references/debug-memory.md: Debug Memory 전체 (Prerequisites, Purpose, 저장 패턴, 5개 템플릿)

    AVOID: 원본 내용 손실
    AVOID: 3-Strike Rule 이동 — debugger entry에 완전히 유지
  </action>
  <verify>
    wc -l .hxsk/skills/verifier/SKILL.md
    wc -l .hxsk/skills/debugger/SKILL.md
    ls .hxsk/skills/verifier/references/
    ls .hxsk/skills/debugger/references/
  </verify>
  <done>
    - verifier/SKILL.md ≤160줄
    - debugger/SKILL.md ≤160줄
    - 각 references/ 디렉토리에 2개 파일 존재
    - 3-Strike Rule이 debugger entry에 유지됨
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] wc -l .hxsk/skills/verifier/SKILL.md → ≤160
- [ ] wc -l .hxsk/skills/debugger/SKILL.md → ≤160
- [ ] ls .hxsk/skills/verifier/references/ → 2개 파일
- [ ] ls .hxsk/skills/debugger/references/ → 2개 파일
- [ ] grep "3-Strike\|3-strike" .hxsk/skills/debugger/SKILL.md → 존재
</verification>

<success_criteria>
- [ ] verifier/SKILL.md ≤160줄 (분할 전 452줄 → ~65% 절감)
- [ ] debugger/SKILL.md ≤160줄 (분할 전 365줄 → ~55% 절감)
- [ ] references/ 각 2개 파일 존재 + 비어있지 않음
- [ ] 3-Strike Rule이 debugger entry에 완전히 유지됨
</success_criteria>
