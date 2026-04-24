---
phase: 2
plan: R2
wave: 1
depends_on: []
files_modified:
  - .hxsk/research/platform-integration/VERIFY-opencode-compat.md
autonomous: true
user_setup:
  - "OpenCode 세션 실행 및 로그 확인 (Task 2)"

must_haves:
  truths:
    - "OpenCode 1.14.18에서 CLAUDE.md 폴백 동작 여부 ✅/❌ 판정"
    - "Skills 경로 (.claude/skills/) 로드 여부 ✅/❌ 판정"
    - "TypeScript 플러그인 MVP 스캐폴드 파일 존재 또는 불필요 결론"
  artifacts:
    - .hxsk/research/platform-integration/VERIFY-opencode-compat.md

cross_phase_invariants:
  inherit: []
  new:
    - "OpenCode 검증은 실제 CLI 실행 결과로만 판정 — 문서/코드 추론으로 대체 불가"
    - "검증 결과는 ✅/❌/⚠️ 3상태로만 기록"
---

# Plan 2.R2: OpenCode TypeScript 플러그인 실제 동작 검증

<objective>
OpenCode 1.14.18에서 HXSK 설정(CLAUDE.md, Skills, Hooks)이 실제로 로드·동작하는지
CLI 레벨에서 검증하고 결과를 기록한다.

Purpose: ROADMAP Phase 2 잔여 항목 완료. 향후 OpenCode 지원 여부를 결정하는 근거 수집
Output: VERIFY-opencode-compat.md (검증 결과 테이블 + 권장 경로)
</objective>

<context>
Load for context:
- .hxsk/research/platform-integration/RESEARCH-opencode-plugin-migration.md (기존 연구, 2026-01-30)
- .hxsk/ROADMAP.md (Phase 2 잔여 항목)
</context>

<tasks>

<task type="auto">
  <name>OpenCode CLI 레벨 검증 + 결과 파일 초안 작성</name>
  <files>.hxsk/research/platform-integration/VERIFY-opencode-compat.md</files>
  <action>
    다음 명령을 실행하고 결과를 기록한다:
    1. `opencode --version` — 현재 설치 버전 확인
    2. `opencode --help` — 지원 CLI 옵션 확인 (config/list 등)
    3. `ls ~/.config/opencode/ 2>/dev/null` — 글로벌 설정 구조 확인
    4. `.opencode/` 디렉토리 없는 상태에서 기대 동작 분석:
       - CLAUDE.md 폴백: RESEARCH 문서 내 "CLAUDE.md → AGENTS.md fallback" 항목 교차 검증
       - Skills 경로: `.claude/skills/` 탐색 여부

    결과 파일 구조:
    ## Verification Date
    ## OpenCode Version
    ## Test Environment
    ## Results Table
    | 항목 | 기대 동작 | 실제 결과 | 판정 |
    |------|-----------|-----------|------|
    | CLAUDE.md 폴백 | ... | ... | ✅/❌/⚠️ |
    | Skills 로드 | ... | ... | ✅/❌/⚠️ |
    | Hooks (bash) 지원 | 미지원 예상 | ... | ✅/❌/⚠️ |
    ## Recommendation
    ## Next Steps (TypeScript 플러그인 필요 시)

    AVOID: opencode 대화 세션 시작 — CLI 레벨 명령만 실행
    AVOID: RESEARCH 문서 내용을 검증 없이 그대로 복사 — 버전 1.14.18 기준 재확인
  </action>
  <verify>grep -q "## Results Table\|## Recommendation" .hxsk/research/platform-integration/VERIFY-opencode-compat.md && echo "VERIFY OK"</verify>
  <done>
    - VERIFY 파일에 Results Table + Recommendation 섹션 완비
    - 각 항목에 ✅/❌/⚠️ 판정 기록
    - OpenCode 버전 1.14.18 명시
  </done>
</task>

<task type="checkpoint:human-verify">
  <name>OpenCode 세션 실행 — CLAUDE.md/Skills 실제 로드 확인</name>
  <files>.hxsk/research/platform-integration/VERIFY-opencode-compat.md</files>
  <action>
    사용자가 이 프로젝트 루트에서 `opencode` 실행 후 다음을 확인:
    1. 세션 시작 시 CLAUDE.md 또는 AGENTS.md 로드 여부 (로그/메시지 확인)
    2. `.claude/skills/` 경로의 스킬 인식 여부
    3. Hook 이벤트 발생 여부 (SessionStart 등)

    확인 후 VERIFY 파일의 Results Table을 실제 결과로 업데이트:
    - CLI 레벨 추론과 세션 실제 동작이 일치하면 ✅ 유지
    - 불일치 발견 시 ⚠️ + 실제 관찰 내용 기록
  </action>
  <verify>grep -c "✅\|❌\|⚠️" .hxsk/research/platform-integration/VERIFY-opencode-compat.md | grep -v "^0$" && echo "판정 기록 존재"</verify>
  <done>
    - Results Table에 실제 세션 실행 결과 반영
    - CLAUDE.md 폴백 / Skills 로드 / Hooks 지원 3항목 모두 판정 완료
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] VERIFY 파일에 Results Table 존재
- [ ] 3개 항목 (CLAUDE.md, Skills, Hooks) 판정 완료
- [ ] Recommendation 섹션에 향후 방향 명시
</verification>

<success_criteria>
- [ ] 모든 태스크 검증 통과
- [ ] OpenCode 지원 여부 근거 문서 완성
- [ ] TypeScript 플러그인 필요 여부 결론 명시
</success_criteria>
