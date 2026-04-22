---
phase: 7
plan: 3
wave: 2
depends_on: [7.1, 7.2]
files_modified:
  - .hxsk/prompts/setup.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "setup.md 에서 필수 단계(1·4·6)와 선택 단계(2·3·5·7·8·9)가 레이블로 명확히 구분된다"
    - "Step 4 심볼릭 링크 실패 시 cp -r 폴백이 적용되며 경고 메시지가 출력된다"
    - "DA-6 반영: Step 9(멀티 하네스)에 Tier 1/2/3 구분이 명시된다"
  artifacts:
    - "setup.md: [필수] · [선택] 레이블 추가"
    - "setup.md Step 4: symlink 폴백 bash 블록"
    - "setup.md Step 9: 하네스 티어 표 (Tier 1: Claude Code·Cursor·Copilot)"

cross_phase_invariants:
  inherit:
    - "md-store-memory.sh TYPE_DIR는 항상 요청된 타입으로 생성"
    - "md-recall-memory.sh는 쿼리 미매칭 시 [NO_MATCH] stderr 출력"
    - "prune-tick.sh는 300s stale lock 자동 해제"
    - "setup.md Step 0은 CORRUPTED 분기로 진입"
    - "setup.md U6은 명시적 스테이징만 사용"
    - "bootstrap.sh는 .hxsk/logs/에 실행 로그 저장"
    - "stop-context-save.sh는 원자적 mv 패턴"
    - "md-store-memory.sh는 YAML 안전 이스케이프"
  new:
    - "setup.md 필수 3단계(Step 1·4·6)와 선택 6단계가 레이블로 분리된다"
    - "setup.md Step 4는 symlink 실패 시 cp -r 폴백으로 진행한다"
    - "setup.md Step 9(멀티 하네스)는 Tier 1·2·3 구분을 명시한다"
---

# Plan 7.3: setup.md UX 재구조화 — 필수/선택 분리 + 하네스 Tier

<objective>
DA-7("단계 수보다 필수/선택 불명확이 진입장벽") + DA-6("9개 하네스 Pareto 위반") 소수의견 반영.
신규 사용자의 핵심 경로를 3단계로 인지할 수 있도록 레이블을 추가하고,
멀티 하네스 설정에 Tier 구분을 도입해 유지보수 부담을 줄인다.

Purpose: setup.md를 변경 없이 유지하면서 레이블·주석만 추가 — 기존 내용 재구성 금지
Output: 레이블 추가된 setup.md
</objective>

<context>
Load for context:
- .hxsk/prompts/setup.md (전체)
- predict/260422-1407-deploy-research/findings.md (Finding 3: 선택/필수 분리)
- predict/260422-1407-deploy-research/overview.md (DA-6, DA-7 소수의견)
</context>

<tasks>

<task type="auto">
  <name>setup.md 필수/선택 레이블 + 핵심 경로 안내 추가</name>
  <files>.hxsk/prompts/setup.md</files>
  <action>
    Step 0 헤더 직후에 "핵심 경로 요약" 박스 추가 (3줄):
    ```markdown
    > **빠른 시작 (약 5분):** Step 1 → Step 4 → Step 6 만 완료하면 기본 동작합니다.
    > 나머지(Step 2·3·5·7·8·9)는 필요에 따라 선택 적용하세요.
    ```

    각 Step 헤더에 레이블 추가:
    - `### [필수] Step 1: 진입점 읽기`
    - `### [선택] Step 2: 에이전트 지침 파일`
    - `### [선택] Step 3: HXSK 문서 구조 생성`
    - `### [필수] Step 4: 스킬 및 에이전트 설치`
    - `### [선택] Step 5: 자동 로드 경로 연결`
    - `### [필수] Step 6: 훅 등록`
    - `### [선택] Step 7: 메모리 시스템 확인`
    - `### [선택] Step 8: README 뱃지`
    - `### [선택] Step 9: Multi-Harness 활성화`

    Step 4 bash 블록에 symlink 폴백 추가:
    ```bash
    for skill_dir in .hxsk/skills/*/; do
      skill_name=$(basename "$skill_dir")
      if ! ln -sfn "../../.hxsk/skills/$skill_name" ".claude/skills/$skill_name" 2>/dev/null; then
        echo "[WARN] symlink 실패 — cp 폴백 사용 (Windows 환경)"
        cp -r ".hxsk/skills/$skill_name" ".claude/skills/$skill_name"
      fi
    done
    ```

    AVOID: Step 내용 재구성, 기존 bash 코드 블록 수정 — 레이블과 안내 텍스트만 추가
  </action>
  <verify>
    grep '\[필수\]\|\[선택\]' .hxsk/prompts/setup.md | wc -l
    grep 'symlink 실패' .hxsk/prompts/setup.md
  </verify>
  <done>
    - [필수] 3개 + [선택] 6개 레이블 존재
    - 핵심 경로 요약 박스 존재
    - symlink 폴백 블록 존재
  </done>
</task>

<task type="auto">
  <name>Step 9 하네스 Tier 표 추가 (DA-6 반영)</name>
  <files>.hxsk/prompts/setup.md</files>
  <action>
    Step 9(Multi-Harness) 섹션 상단에 Tier 표 추가:
    ```markdown
    | Tier | 하네스 | 지원 수준 | 어댑터 |
    |------|--------|-----------|--------|
    | **Tier 1** | Claude Code | 완전 지원 (네이티브) | 내장 |
    | **Tier 1** | Cursor 1.7+ | 완전 지원 | cursor-hooks.json |
    | **Tier 1** | GitHub Copilot CLI | 완전 지원 | copilot-hooks.json |
    | **Tier 2** | Gemini CLI | 부분 지원 | gemini-settings.json |
    | **Tier 2** | Windsurf | 부분 지원 | windsurf-hooks.json |
    | **Tier 2** | OpenCode | 부분 지원 (JS 래퍼 필요) | opencode-plugin.ts |
    | **Tier 2** | OpenAI Codex CLI | 부분 지원 | codex-hooks.json |
    | **Tier 3** | Aider / Continue / Antigravity | 커뮤니티 기여 | git 훅 폴백 |

    > Tier 1만 설치해도 핵심 기능이 완전히 동작합니다.
    > Tier 2·3는 필요 시 추가하세요.
    ```

    기존 어댑터 설치 명령 테이블은 유지 — 표만 앞에 추가.
    AVOID: 기존 설치 명령 수정 금지
  </action>
  <verify>
    grep 'Tier 1\|Tier 2\|Tier 3' .hxsk/prompts/setup.md | wc -l
  </verify>
  <done>Tier 1·2·3 표가 Step 9 상단에 존재</done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] grep '\[필수\]' .hxsk/prompts/setup.md → 3개
- [ ] grep '\[선택\]' .hxsk/prompts/setup.md → 6개
- [ ] grep 'symlink 실패' .hxsk/prompts/setup.md → 존재
- [ ] grep 'Tier 1' .hxsk/prompts/setup.md → 존재
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
</verification>

<success_criteria>
- [ ] 신규 사용자가 "Step 1·4·6만 하면 된다"는 것을 setup.md 상단에서 즉시 파악
- [ ] Tier 1 집중 설치가 권장됨을 Step 9에서 명시
- [ ] 기존 내용 무결성 유지
</success_criteria>
