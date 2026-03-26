---
phase: 1
plan: 1
wave: 1
gap_closure: false
---

# Plan 1.1: Dispatcher v2 — 로컬 마크다운 이슈 트래킹 기반 병렬 오케스트레이션 구현

## Objective

기존 dispatcher 스킬을 확장하여 로컬 마크다운 이슈 트래킹(MASTER/WORK 문서)을 핵심으로 하는 6-Phase 오케스트레이션 라이프사이클을 구현한다. 설계 문서: `docs/plans/2026-03-26-dispatcher-v2-design.md`

## Context
Load these files for context:
- docs/plans/2026-03-26-dispatcher-v2-design.md
- .hxsk/skills/dispatcher/SKILL.md
- .hxsk/agents/dispatcher.md
- scripts/issue-create.sh
- scripts/issue-list.sh
- scripts/merge-worktrees.sh
- .gitignore

## Tasks

### Wave 1: 기반 인프라 (템플릿 + 스크립트 + gitignore)

<task type="auto">
  <name>MASTER/WORK 이슈 템플릿 생성</name>
  <files>
    .hxsk/templates/MASTER-ISSUE.md
    .hxsk/templates/WORK-ISSUE.md
  </files>
  <action>
    설계 문서의 MASTER Document, WORK Document 스키마를 템플릿으로 작성.

    Steps:
    1. MASTER-ISSUE.md 템플릿 생성 (frontmatter: id, title, branch, status, works, wave_plan, created / body: Objective, Progress, Merge Log, Notes)
    2. WORK-ISSUE.md 템플릿 생성 (frontmatter: id, master, title, status, wave, depends_on, files, side_effect_files, worktree, worktree_branch / body: Tasks, Result, Failure Log)

    AVOID: 템플릿에 예시 값을 하드코딩하지 않음. 플레이스홀더 `{...}` 사용
    USE: 기존 `.hxsk/templates/` 내 다른 템플릿의 포맷 컨벤션 참조
  </action>
  <verify>
    # 파일 존재 확인
    test -f .hxsk/templates/MASTER-ISSUE.md && test -f .hxsk/templates/WORK-ISSUE.md && echo "PASS"
    # frontmatter 필수 필드 확인
    grep -q "wave_plan:" .hxsk/templates/MASTER-ISSUE.md && grep -q "depends_on:" .hxsk/templates/WORK-ISSUE.md && echo "FIELDS OK"
  </verify>
  <done>
    두 템플릿 파일이 존재하고, 설계 문서의 모든 frontmatter 필드와 body 섹션을 포함
  </done>
</task>

<task type="auto">
  <name>issue-create.sh MASTER/WORK 모드 추가</name>
  <files>
    scripts/issue-create.sh
  </files>
  <action>
    기존 issue-create.sh를 확장하여 MASTER/WORK 문서 생성을 지원.

    Steps:
    1. 첫 번째 인자로 모드 분기: `master`, `work`, 또는 기존 모드 (하위 호환)
    2. `master` 모드: `bash scripts/issue-create.sh master <title>` → MASTER-{id}.md 생성
       - id: 기존 MASTER-*.md 중 최대 번호 + 1 (3자리 패딩)
       - 파일명: MASTER-{id}.md
       - 템플릿 기반으로 frontmatter 채우기
    3. `work` 모드: `bash scripts/issue-create.sh work <master-id> <title> <wave> [depends_on] [files]`
       - id: WORK-{master-id}-{seq}
       - 파일명: WORK-{master-id}-{seq}.md
       - seq: 해당 master의 기존 WORK 중 최대 seq + 1
    4. 기존 인자 패턴(title, type, priority)은 레거시 모드로 유지

    AVOID: 기존 기능 깨뜨리지 않음. 첫 인자가 master/work가 아니면 기존 로직 실행
    USE: 기존 ISSUES_DIR 변수, 기존 타임스탬프 생성 패턴 재사용
  </action>
  <verify>
    # MASTER 생성 테스트
    bash scripts/issue-create.sh master "테스트 마스터플랜" 2>/dev/null
    test -f .hxsk/issues/MASTER-001.md && echo "MASTER OK"
    # WORK 생성 테스트
    bash scripts/issue-create.sh work 001 "테스트 워크" 1 "" "src/test.ts" 2>/dev/null
    test -f .hxsk/issues/WORK-001-1.md && echo "WORK OK"
    # 레거시 모드 테스트
    bash scripts/issue-create.sh "레거시 이슈" task P2 2>/dev/null | grep -q "CREATED" && echo "LEGACY OK"
    # 정리
    rm -f .hxsk/issues/MASTER-001.md .hxsk/issues/WORK-001-1.md .hxsk/issues/001-*.md
  </verify>
  <done>
    master/work/legacy 3가지 모드 모두 정상 동작. 기존 스크립트 하위 호환 유지.
  </done>
</task>

<task type="auto">
  <name>issue-list.sh MASTER/WORK 출력 지원</name>
  <files>
    scripts/issue-list.sh
  </files>
  <action>
    issue-list.sh를 확장하여 MASTER/WORK 문서를 구분 표시.

    Steps:
    1. MASTER-*.md와 WORK-*.md 파일을 별도로 감지
    2. MASTER 문서: ID, STATUS, TITLE, WORKS 수, 현재 WAVE 표시
    3. WORK 문서: ID, MASTER, STATUS, WAVE, DEPENDS_ON, TITLE 표시
    4. 기존 형식(숫자-slug.md)은 레거시로 표시
    5. 필터 옵션: `bash scripts/issue-list.sh [master|work|all] [status]`

    AVOID: 기존 출력 형식을 완전히 깨뜨리지 않음
    USE: 기존 frontmatter 파싱 로직 재사용
  </action>
  <verify>
    # MASTER/WORK 생성 후 목록 확인
    bash scripts/issue-create.sh master "테스트" 2>/dev/null
    bash scripts/issue-create.sh work 001 "워크1" 1 2>/dev/null
    bash scripts/issue-list.sh master | grep -q "MASTER" && echo "MASTER LIST OK"
    bash scripts/issue-list.sh work | grep -q "WORK" && echo "WORK LIST OK"
    rm -f .hxsk/issues/MASTER-001.md .hxsk/issues/WORK-001-1.md
  </verify>
  <done>
    master/work/all 필터가 동작하고, 각 문서 타입에 맞는 컬럼 출력
  </done>
</task>

<task type="auto">
  <name>.gitignore 이슈 문서 untracked 정책 반영</name>
  <files>
    .gitignore
  </files>
  <action>
    .hxsk/issues/ 내 MASTER/WORK 마크다운 파일을 git-untracked로 설정.

    Steps:
    1. 기존 `!.hxsk/issues/` 규칙 유지 (디렉토리 자체는 tracked)
    2. `.hxsk/issues/MASTER-*.md` 와 `.hxsk/issues/WORK-*.md` 를 ignore 추가
    3. `.hxsk/issues/archive/` 도 ignore 추가
    4. `.hxsk/issues/.gitkeep`은 tracked 유지

    AVOID: 기존 레거시 이슈 파일(숫자-slug.md)의 tracking 상태를 변경하지 않음
    USE: 기존 gitignore 패턴 스타일과 일관된 주석 사용
  </action>
  <verify>
    echo "test" > .hxsk/issues/MASTER-999.md
    git check-ignore .hxsk/issues/MASTER-999.md && echo "IGNORED OK"
    git check-ignore .hxsk/issues/.gitkeep || echo "GITKEEP TRACKED OK"
    rm -f .hxsk/issues/MASTER-999.md
  </verify>
  <done>
    MASTER-*.md, WORK-*.md는 git-ignored. .gitkeep은 tracked. 기존 규칙 미파괴.
  </done>
</task>

### Wave 2: dispatcher 스킬 + 에이전트 업데이트

<task type="auto">
  <name>dispatcher SKILL.md 6-Phase 리라이트</name>
  <files>
    .hxsk/skills/dispatcher/SKILL.md
  </files>
  <action>
    기존 4-Phase 구조를 설계 문서의 6-Phase Wave 루프 구조로 리라이트.

    Steps:
    1. frontmatter 업데이트:
       - description 갱신 (MASTER/WORK 기반 명시)
       - version 2.0.0으로 범프
       - trigger에 "이슈 분할, work split, parallel issue, 마스터플랜" 추가
       - allowed-tools에 Write 추가 (이슈 문서 생성/업데이트용)
    2. Quick Reference 갱신:
       - 입력: PLAN.md/SPEC.md → MASTER/WORK 문서
       - 출력: 6-Phase 라이프사이클
       - Main Root Resolve: `git worktree list | head -1 | awk '{print $1}'`
    3. Dispatch Protocol 리라이트:
       - Phase 1 (SPLIT): PLAN/SPEC → MASTER/WORK 분할, 위상 정렬, 파일 소유권 검증
       - Phase 2 (BRANCH): 이슈 브랜치 생성
       - Phase 3-5 Wave 루프: DISPATCH → TRACK → MERGE (설계 문서의 루프 다이어그램 포함)
       - Phase 6 (VERIFY → CLOSE): 통합 테스트, 아카이브, 워크트리 정리
    4. Subagent Interface 섹션 추가: 프롬프트 주입 템플릿, 서브에이전트 규약
    5. Crash Recovery Protocol 섹션 추가
    6. 기존 Issue Lazy Loading (L0/L1/L2) 섹션 제거
    7. Dispatch Rules 유지 + side_effect_files 규칙 추가

    AVOID: 기존 검증된 Wave 실행 패턴의 핵심 로직(Agent isolation, run_in_background)을 변경하지 않음
    USE: 설계 문서의 정확한 Phase 설명 및 다이어그램 사용
  </action>
  <verify>
    # 필수 섹션 존재 확인
    grep -q "Phase 1: SPLIT" .hxsk/skills/dispatcher/SKILL.md && echo "P1 OK"
    grep -q "Phase 2: BRANCH" .hxsk/skills/dispatcher/SKILL.md && echo "P2 OK"
    grep -q "Phase 3: DISPATCH" .hxsk/skills/dispatcher/SKILL.md && echo "P3 OK"
    grep -q "Phase 4: TRACK" .hxsk/skills/dispatcher/SKILL.md && echo "P4 OK"
    grep -q "Phase 5: MERGE" .hxsk/skills/dispatcher/SKILL.md && echo "P5 OK"
    grep -q "Phase 6: VERIFY" .hxsk/skills/dispatcher/SKILL.md && echo "P6 OK"
    grep -q "Crash Recovery" .hxsk/skills/dispatcher/SKILL.md && echo "RECOVERY OK"
    grep -q "version: 2.0.0" .hxsk/skills/dispatcher/SKILL.md && echo "VERSION OK"
    # Lazy Loading 제거 확인
    ! grep -q "L0.*L1.*L2" .hxsk/skills/dispatcher/SKILL.md && echo "LAZY REMOVED OK"
  </verify>
  <done>
    6-Phase Wave 루프 구조로 전환 완료. Lazy Loading 제거. version 2.0.0.
    설계 문서의 모든 Phase, Subagent Interface, Crash Recovery 반영.
  </done>
</task>

<task type="auto">
  <name>dispatcher.md 에이전트 정의 업데이트</name>
  <files>
    .hxsk/agents/dispatcher.md
  </files>
  <action>
    에이전트 정의를 6-Phase에 맞춰 업데이트하고, tools 정합성 문제 해소.

    Steps:
    1. description 갱신: "MASTER/WORK 기반 6-Phase 병렬 이슈 오케스트레이터"
    2. tools에 Write 명시 (SKILL.md의 allowed-tools와 일치)
    3. 오케스트레이션 단계를 6-Phase로 업데이트:
       1. PLAN/SPEC에서 MASTER/WORK 문서 생성 (issue-create.sh 활용)
       2. 이슈 브랜치 생성 및 파일 소유권 검증
       3. Wave별 루프: DISPATCH → TRACK → MERGE
       4. 통합 테스트, 아카이브, 사용자 승인 후 마스터 머지
    4. Key constraints 업데이트:
       - 오케스트레이터만 이슈 문서 쓰기
       - side_effect_files 포함 소유권 검증
       - 워크트리 보존 정책 (Phase 6 후 정리)

    AVOID: model: opus 변경 없음 (복잡한 오케스트레이션이므로 유지)
    USE: 기존 Agent Boundaries 섹션 유지
  </action>
  <verify>
    grep -q "6-Phase" .hxsk/agents/dispatcher.md && echo "PHASE OK"
    grep -q '"Write"' .hxsk/agents/dispatcher.md && echo "TOOLS OK"
    grep -q "MASTER/WORK" .hxsk/agents/dispatcher.md && echo "SCHEMA OK"
  </verify>
  <done>
    에이전트 정의가 SKILL.md와 일관된 6-Phase 구조. tools 목록 정합.
  </done>
</task>

### Wave 3: 통합 검증

<task type="auto">
  <name>End-to-End 드라이런 검증</name>
  <files>
    .hxsk/issues/
    scripts/issue-create.sh
    scripts/issue-list.sh
  </files>
  <action>
    실제 MASTER/WORK 문서 생성 → 목록 조회 → 정리까지 전체 흐름 검증.

    Steps:
    1. MASTER 생성: `bash scripts/issue-create.sh master "드라이런 테스트"`
    2. WORK 3개 생성:
       - Wave 1: WORK-001-1 (files: scripts/test1.sh), WORK-001-2 (files: scripts/test2.sh)
       - Wave 2: WORK-001-3 (depends_on: WORK-001-1, files: scripts/test3.sh)
    3. issue-list.sh로 목록 확인: master/work 필터 동작
    4. gitignore 검증: `git check-ignore` 으로 MASTER/WORK 파일 ignored 확인
    5. 메인 루트 resolve 검증: `git worktree list | head -1 | awk '{print $1}'` 정상 동작
    6. 테스트 파일 정리

    AVOID: 실제 워크트리 생성이나 브랜치 생성은 하지 않음 (드라이런)
    USE: 스크립트의 실제 출력으로 검증
  </action>
  <verify>
    # 정리 확인
    ! ls .hxsk/issues/MASTER-001.md 2>/dev/null && echo "CLEANUP OK"
  </verify>
  <done>
    MASTER/WORK 생성→조회→gitignore 검증→정리 전체 흐름 성공.
    스크립트 간 데이터 일관성 확인 완료.
  </done>
</task>

<task type="checkpoint:human-verify">
  <name>SKILL.md + Agent 정의 리뷰</name>
  <files>
    .hxsk/skills/dispatcher/SKILL.md
    .hxsk/agents/dispatcher.md
  </files>
  <action>
    리라이트된 dispatcher SKILL.md와 agent 정의를 사용자가 리뷰.
    설계 문서와의 일관성, 기존 기능과의 하위 호환성 확인.
  </action>
  <verify>
    사용자 승인
  </verify>
  <done>
    사용자가 SKILL.md와 agent 정의를 승인
  </done>
</task>

## Must-Haves
After all tasks complete, verify:
- [ ] MASTER/WORK 템플릿이 설계 문서의 스키마와 100% 일치
- [ ] issue-create.sh가 master/work/legacy 3모드 모두 정상 동작
- [ ] issue-list.sh가 MASTER/WORK 문서를 구분 표시
- [ ] .gitignore가 MASTER-*.md, WORK-*.md를 untracked 처리
- [ ] dispatcher SKILL.md가 6-Phase Wave 루프 구조
- [ ] dispatcher.md 에이전트의 tools가 SKILL.md allowed-tools와 일치
- [ ] 기존 레거시 이슈 기능 하위 호환

## Success Criteria
- [ ] All tasks verified passing
- [ ] Must-haves confirmed
- [ ] 드라이런 E2E 통과
- [ ] 사용자 리뷰 승인
