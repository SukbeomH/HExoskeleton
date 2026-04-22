---
phase: 7
plan: 6
wave: 3
depends_on: [7.3, 7.5]
files_modified:
  - llms.txt
  - README.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "llms.txt에 하네스별 진입 섹션이 분리되어 어떤 AI 에이전트든 자신에게 맞는 경로를 즉시 찾는다"
    - "README.md 상단에 하네스 선택 Quick Decision Tree가 있어 첫 5분 안에 설치 경로를 결정한다"
    - "Claude Code 특정 채널(Plugin Marketplace)은 선택지 중 하나로만 언급된다"
  artifacts:
    - "llms.txt: ## 하네스별 빠른 시작 섹션 추가"
    - "README.md: 하네스 선택 Decision Tree 추가"

cross_phase_invariants:
  inherit:
    - "setup.md 필수 3단계(Step 1·4·6)와 선택 6단계가 레이블로 분리"
    - "setup.md Step 9는 Tier 1·2·3 구분 명시"
    - "install.sh는 Tier 1 하네스를 완전 지원"
    - "hxsk-harness-sync.sh는 어댑터 드리프트를 감지"
  new:
    - "llms.txt는 하네스별 진입 경로를 분리 섹션으로 제공한다"
    - "README.md 상단 Decision Tree는 하네스 비종속으로 작성된다 (Claude Code 우선 표기 금지)"
---

# Plan 7.6: llms.txt + README — 하네스 비종속 발견 가능성 개선

<objective>
P2 마지막 단계 — 배포 방식이 아닌 "문서 진입점" 개선.
llms.txt에 하네스별 섹션을 추가하고, README 상단에 어떤 AI 에이전트 사용자든
3선택으로 빠르게 시작할 수 있는 Decision Tree를 추가한다.

HXSK 설계 의도: Claude Code 전용 진입점이 아닌 10+ 하네스 모두를 위한 동등한 진입 경로.

Purpose: "나는 Cursor 사용자인데 어떻게 시작하나?" → 5초 안에 답 찾기
Output: 개선된 llms.txt + README.md (레이블·섹션만 추가, 기존 내용 재구성 없음)
</objective>

<context>
Load for context:
- llms.txt (현재 전체)
- README.md (현재 전체)
- .hxsk/adapters/README.md (하네스별 경로)
- predict/260422-1407-deploy-research/overview.md (P3 범용 발견 가능성)
</context>

<tasks>

<task type="auto">
  <name>llms.txt 하네스별 빠른 시작 섹션 추가</name>
  <files>llms.txt</files>
  <action>
    기존 llms.txt 끝에 섹션 추가 (기존 내용 수정 없음):
    ```markdown
    ## 하네스별 빠른 시작

    어떤 AI 에이전트를 사용 중인가?

    ### Claude Code
    1. 이 llms.txt를 읽은 후 `.hxsk/prompts/setup.md`를 실행하세요.
    2. 또는: `bash .hxsk/scripts/install.sh --harness claude-code`

    ### Cursor 1.7+
    1. `.hxsk/prompts/setup.md` Step 1·4·6(필수) 실행
    2. `bash .hxsk/scripts/install.sh --harness cursor`

    ### GitHub Copilot CLI
    1. `.hxsk/prompts/setup.md` Step 1·4·6(필수) 실행
    2. `bash .hxsk/scripts/install.sh --harness copilot`

    ### Gemini CLI / Windsurf / OpenCode / Codex (Tier 2)
    1. `.hxsk/prompts/setup.md` Step 1·4·6(필수) 실행
    2. `.hxsk/adapters/README.md` 의 해당 하네스 섹션 참조

    ### Aider / Continue / Antigravity (Tier 3 — 커뮤니티 기여)
    1. `.hxsk/prompts/setup.md` Step 1·4(필수) 실행
    2. `bash .hxsk/scripts/install.sh --harness git-hook`
    ```

    AVOID: 기존 섹션 수정 금지 — 끝에만 추가
  </action>
  <verify>
    grep '하네스별 빠른 시작' llms.txt
    grep 'install.sh --harness' llms.txt | wc -l
  </verify>
  <done>
    - "하네스별 빠른 시작" 섹션 존재
    - 5개 하네스 그룹 각각 install.sh 또는 참조 경로 포함
  </done>
</task>

<task type="auto">
  <name>README.md 상단 Decision Tree 추가</name>
  <files>README.md</files>
  <action>
    README.md 첫 번째 `##` 헤더 바로 위에 Decision Tree 삽입:
    ```markdown
    ## 빠른 시작 — 3선택

    > **어떤 AI 에이전트를 사용 중인가?**
    >
    > | 에이전트 | 시작 명령 |
    > |---------|----------|
    > | Claude Code | `bash .hxsk/scripts/install.sh --harness claude-code` |
    > | Cursor 1.7+ | `bash .hxsk/scripts/install.sh --harness cursor` |
    > | GitHub Copilot CLI | `bash .hxsk/scripts/install.sh --harness copilot` |
    > | 기타 (Gemini·Windsurf·Codex 등) | [Tier 2·3 설치 안내](.hxsk/adapters/README.md) |
    >
    > 처음이라면: `.hxsk/prompts/setup.md` Step 1(필수) → Step 4(필수) → 위 명령 순서로 실행
    ```

    Claude Code Plugin Marketplace 언급은 제거하거나 "선택적 채널 중 하나" 형태로 각주 처리.
    AVOID: 기존 README 내용 재구조화 금지 — 삽입만
    AVOID: "Claude Code 권장" 또는 "Claude Code 전용" 표현 금지
  </action>
  <verify>
    grep '빠른 시작' README.md
    grep 'install.sh --harness' README.md | wc -l
    wc -l README.md  # 300줄 이하 유지 확인
  </verify>
  <done>
    - "빠른 시작" 섹션이 README 최상단 근처에 존재
    - 4개 에이전트 그룹 모두 install.sh 명령 또는 참조 포함
    - 전체 300줄 이하 유지
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] grep '하네스별 빠른 시작' llms.txt → 존재
- [ ] grep '빠른 시작' README.md → 존재
- [ ] wc -l README.md → 300 이하
- [ ] README에 "Claude Code 권장" / "Claude Code 전용" 없음
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
</verification>

<success_criteria>
- [ ] Claude Code 사용자와 Cursor 사용자 모두 동등하게 3단계 이내 시작 가능
- [ ] llms.txt가 하네스 비종속 진입점 역할 수행
- [ ] README 300줄 이하 유지
</success_criteria>
