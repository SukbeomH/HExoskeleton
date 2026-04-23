# Mandatory Discovery Protocol

Discovery is MANDATORY unless you can prove current context exists.

---

## Level 0 — Skip
*Pure internal work, existing patterns only*
- ALL work follows established codebase patterns (grep confirms)
- No new external dependencies
- Pure internal refactoring or feature extension
- Examples: Add delete button, add field to model, create CRUD endpoint

---

## Level 1 — Quick Verification (2-5 min)
- Single known library, confirming syntax/version
- Low-risk decision (easily changed later)
- Action: Quick docs check, no RESEARCH.md needed

---

## Level 2 — Standard Research (15-30 min)
- Choosing between 2-3 options
- New external integration (API, service)
- Medium-risk decision
- Action: Route to `/research-phase`, produces RESEARCH.md

---

## Level 3 — Deep Dive (1+ hour)
- Architectural decision with long-term impact
- Novel problem without clear patterns
- High-risk, hard to change later
- Action: Full research with RESEARCH.md

---

## Depth Indicators

- **Level 2+**: New library not in package.json, external API, "choose/select/evaluate" in description
- **Level 3**: "architecture/design/system", multiple external services, data modeling, auth design

For niche domains (3D, games, audio, shaders, ML), suggest `/research-phase` before `/plan`.

---

## Native Tool Usage for Discovery Assessment

```
# Discovery Level 평가 (키워드 기반)
# L0: skip (기존 코드 수정), L1: quick (단순 추가), L2: standard (새 기능), L3: deep (아키텍처)
Grep(pattern: "auth|security|database|api", path: "src/", output_mode: "count")

# 기존 PLAN.md 검색
Glob(pattern: ".hxsk/phases/*/*.md")

# 과거 플랜 deviation 확인
bash .hxsk/hooks/md-recall-memory.sh "deviation" "." 5 compact
```
