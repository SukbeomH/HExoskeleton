---
phase: 1
plan: 1
wave: 1
gap_closure: false
---

# Plan 1.1: Setup v2 — 멱등 수렴 패턴 + 2-hop 컨텍스트 + 범용 에이전트 지원

## Objective

bootstrap.sh를 멱등 수렴 엔진으로 전환하고, setup 프롬프트에 상태 인식 분기를 추가하며, session-start.sh에 source 기반 분기를 도입한다. 설계 문서: `docs/plans/2026-03-26-setup-v2-design.md`

## Context
Load these files for context:
- docs/plans/2026-03-26-setup-v2-design.md
- scripts/bootstrap.sh
- prompts/setup.md
- prompts/setup-claude.md
- .hxsk/hooks/session-start.sh
- .hxsk/skills/bootstrap/SKILL.md

## Tasks

### Wave 1: 기반 인프라 (버전 마커 + bootstrap.sh 멱등화)

<task type="auto">
  <name>bootstrap-version 템플릿 생성</name>
  <files>
    .hxsk/templates/bootstrap-version.yaml
  </files>
  <action>
    .bootstrap-version 파일의 YAML 템플릿 작성.

    Steps:
    1. frontmatter 없이 순수 YAML 파일로 작성
    2. 필드: version, last_run, components (skills/N, agents/N, hooks/N, memories/N)
    3. 주석으로 각 필드 설명

    AVOID: 복잡한 구조. 플랫한 YAML만 사용
    USE: 기존 .hxsk/templates/ 컨벤션 참조
  </action>
  <verify>
    test -f .hxsk/templates/bootstrap-version.yaml && echo "PASS"
    grep -q "version:" .hxsk/templates/bootstrap-version.yaml && echo "FIELDS OK"
  </verify>
  <done>
    템플릿 파일 존재, version/last_run/components 필드 포함
  </done>
</task>

<task type="auto">
  <name>bootstrap.sh 멱등 수렴 엔진 전환</name>
  <files>
    scripts/bootstrap.sh
  </files>
  <action>
    기존 bootstrap.sh를 멱등 수렴 패턴으로 확장. 기존 체크 로직 유지.

    Steps:
    1. 스크립트 상단에 BOOTSTRAP_VERSION 상수 추가 (예: "5.0.0")
    2. .hxsk/.bootstrap-version 읽기 로직 추가:
       - 파일 없음 → MODE="fresh"
       - 동일 버전 → MODE="verify"
       - 구버전 → MODE="update", OLD_VERSION 기록
    3. 기존 report_pass/fail/warn/skip에 report_new, report_updated 추가:
       - report_new(): printf "  [NEW] ..."
       - report_updated(): printf "  [UPDATED] ..."
    4. report_context() 함수 추가:
       - [NEW] 또는 [UPDATED] 시에만 md-recall-memory.sh 2-hop 호출
       - 관련 컨텍스트가 있으면 "  관련: ..." 출력
    5. 기존 각 체크 섹션에 모드별 분기 추가:
       - fresh: 전체 실행, 모두 [NEW]
       - verify: 구조 검증만, [OK] 또는 [FAIL]
       - update: 변경분 감지, [UPDATED] 또는 [OK]
    6. 스크립트 마지막에 .hxsk/.bootstrap-version 생성/갱신:
       version: {BOOTSTRAP_VERSION}
       last_run: $(date '+%Y-%m-%d')
       components: skills/{count}, agents/{count}, hooks/{count}, memories/{count}
    7. Summary에 모드 표시: "MODE: fresh | verify | update (from X.X.X)"

    AVOID: 기존 체크 로직을 제거하지 않음. 래핑하여 확장
    USE: 기존 report_* 헬퍼 패턴 유지, 새 헬퍼 추가
  </action>
  <verify>
    # fresh 모드 테스트 (기존 .bootstrap-version 없는 상태)
    rm -f .hxsk/.bootstrap-version
    bash scripts/bootstrap.sh 2>&1 | grep -q "MODE:" && echo "MODE OK"
    test -f .hxsk/.bootstrap-version && echo "VERSION FILE CREATED"
    # verify 모드 테스트 (동일 버전)
    bash scripts/bootstrap.sh 2>&1 | grep -q "verify" && echo "VERIFY MODE OK"
    # update 모드 테스트 (구버전 시뮬)
    sed -i '' 's/version: .*/version: 0.0.1/' .hxsk/.bootstrap-version
    bash scripts/bootstrap.sh 2>&1 | grep -q "update" && echo "UPDATE MODE OK"
  </verify>
  <done>
    fresh/verify/update 3모드 정상 동작. .bootstrap-version 자동 생성/갱신.
    기존 PASS/FAIL/WARN/SKIP 출력 유지 + NEW/UPDATED 추가.
  </done>
</task>

### Wave 2: 프롬프트 + 세션 훅 (Wave 1 의존)

<task type="auto">
  <name>setup.md 상태 인식형 분기 추가</name>
  <files>
    prompts/setup.md
  </files>
  <action>
    기존 7-step 구조를 유지하면서 Step 0 상태 감지를 추가.

    Steps:
    1. 최상단에 "## Step 0: 상태 감지" 섹션 추가:
       - `.hxsk/.bootstrap-version` 파일 확인
       - 없으면 → "초기 설치" 경로 안내 (기존 Step 1~7)
       - 있으면 → "업데이트" 경로 안내
    2. 기존 Step 1~7은 "## 초기 설치" 하위로 감싸기
    3. "## 업데이트" 섹션 추가:
       - `bash scripts/bootstrap.sh` 실행
       - [NEW/UPDATED/OK] 보고서 확인 안내
       - 에이전트별 설정 갱신 분기
    4. "다음 단계" 섹션도 초기/업데이트에 따라 분기

    AVOID: 기존 Step 내용을 변경하지 않음. 구조만 감싸기
    USE: 에이전트가 자율 판단할 수 있는 명확한 조건문 형태
  </action>
  <verify>
    grep -q "Step 0" prompts/setup.md && echo "STEP0 OK"
    grep -q "초기 설치" prompts/setup.md && echo "FRESH PATH OK"
    grep -q "업데이트" prompts/setup.md && echo "UPDATE PATH OK"
    grep -q "bootstrap-version" prompts/setup.md && echo "VERSION CHECK OK"
  </verify>
  <done>
    Step 0 상태 감지 존재. 초기/업데이트 두 경로 존재. 기존 Step 1~7 내용 보존.
  </done>
</task>

<task type="auto">
  <name>setup-claude.md 상태 인식형 분기 추가</name>
  <files>
    prompts/setup-claude.md
  </files>
  <action>
    setup.md와 동일한 상태 감지 + 분기 패턴 적용.

    Steps:
    1. 최상단에 상태 감지 섹션 추가 (.bootstrap-version 확인)
    2. 기존 Quick Setup을 "초기 설치" 하위로
    3. "업데이트" 섹션: bootstrap.sh 실행 + Claude Code 전용 갱신 안내
       - hook 설정 변경 확인
       - 새 스킬 설치 안내
    4. "다음 단계" 분기

    AVOID: 범용 setup.md와 중복되는 내용 최소화. Claude 전용 부분만
    USE: 기존 구조 유지, 감싸기 패턴
  </action>
  <verify>
    grep -q "bootstrap-version" prompts/setup-claude.md && echo "VERSION CHECK OK"
    grep -q "업데이트" prompts/setup-claude.md && echo "UPDATE PATH OK"
  </verify>
  <done>
    상태 감지 + 초기/업데이트 분기 존재. Claude 전용 hook 갱신 안내 포함.
  </done>
</task>

<task type="auto">
  <name>session-start.sh source 분기 추가</name>
  <files>
    .hxsk/hooks/session-start.sh
  </files>
  <action>
    세션 시작 시 source 필드 기반으로 로드 범위를 조절.

    Steps:
    1. main() 함수 상단에서 stdin JSON의 source 필드 파싱 시도
    2. source가 없으면 .hxsk/.session-active 파일로 fallback 판별:
       - 파일 있음 → SOURCE="resume"
       - 파일 없음 → SOURCE="startup"
    3. case문으로 분기:
       - startup: 기존 풀 로드 (5개 파트 전부) + .session-active 생성
       - resume: CURRENT.md + uncommitted changes만
       - compact: STATE.md 첫 15줄 + 활성 PLAN 정보만
    4. 기존 로드 로직을 startup 케이스로 이동 (리팩터링)
    5. resume/compact용 경량 로드 로직 추가

    AVOID: 기존 startup 동작을 변경하지 않음. 새 분기만 추가
    USE: 기존 json_get 함수로 source 파싱, _json_parse.sh 재사용
  </action>
  <verify>
    # startup 시뮬 (stdin 없이 실행, .session-active 없음)
    rm -f .hxsk/.session-active
    echo '{}' | bash .hxsk/hooks/session-start.sh 2>/dev/null | grep -q "SessionStart" && echo "STARTUP OK"
    test -f .hxsk/.session-active && echo "MARKER CREATED"
    # resume 시뮬 (.session-active 존재)
    echo '{}' | bash .hxsk/hooks/session-start.sh 2>/dev/null | grep -q "SessionStart" && echo "RESUME OK"
    rm -f .hxsk/.session-active
  </verify>
  <done>
    startup/resume/compact 3분기 동작. .session-active 마커 생성/감지.
    기존 startup 동작 100% 보존.
  </done>
</task>

### Wave 3: 스킬 업데이트 + 통합 검증

<task type="auto">
  <name>bootstrap SKILL.md 업데이트 시나리오 추가</name>
  <files>
    .hxsk/skills/bootstrap/SKILL.md
  </files>
  <action>
    bootstrap 스킬에 업데이트 시나리오와 2-hop 보고를 추가.

    Steps:
    1. description에 "update, 업데이트, 갱신" 트리거 추가
    2. version을 5.0.0으로 범프
    3. Quick Reference에 업데이트 모드 설명 추가
    4. Procedure에 "Step 0: 모드 감지" 추가:
       - .bootstrap-version 확인 → fresh/update 분기
       - update 시 bootstrap.sh만 재실행 + [NEW/UPDATED/OK] 보고
    5. 기존 Step 1~7은 "초기 설치 시" 조건 명시
    6. "업데이트 시" 절차 추가:
       - bash scripts/bootstrap.sh 실행
       - 2-hop 컨텍스트 보고 확인
       - 변경사항 요약 출력

    AVOID: 기존 7단계 절차 변경 없음. 감싸기 + 분기 추가
    USE: 기존 SKILL.md 구조 패턴 유지
  </action>
  <verify>
    grep -q "version: 5.0.0" .hxsk/skills/bootstrap/SKILL.md && echo "VERSION OK"
    grep -q "업데이트" .hxsk/skills/bootstrap/SKILL.md && echo "UPDATE OK"
    grep -q "모드 감지" .hxsk/skills/bootstrap/SKILL.md && echo "MODE DETECT OK"
  </verify>
  <done>
    v5.0.0. 초기/업데이트 두 경로 존재. 2-hop 보고 언급.
  </done>
</task>

<task type="auto">
  <name>E2E 검증: fresh → verify → update 전체 사이클</name>
  <files>
    scripts/bootstrap.sh
    .hxsk/hooks/session-start.sh
    prompts/setup.md
    prompts/setup-claude.md
  </files>
  <action>
    전체 라이프사이클을 시뮬레이션하여 검증.

    Steps:
    1. fresh 모드: .bootstrap-version 삭제 → bootstrap.sh 실행 → [NEW] 태그 확인 → .bootstrap-version 생성 확인
    2. verify 모드: 동일 버전으로 재실행 → [OK] 태그 확인 → .bootstrap-version 변경 없음
    3. update 모드: .bootstrap-version의 version을 0.0.1로 수정 → 재실행 → [UPDATED] 태그 확인 → 2-hop 컨텍스트 출력 확인
    4. session-start.sh: startup → .session-active 생성 확인 → resume 분기 확인
    5. setup.md/setup-claude.md: .bootstrap-version 유무에 따른 분기 텍스트 존재 확인
    6. 테스트 후 .bootstrap-version 정리

    AVOID: 실제 프로젝트 상태를 변경하는 파괴적 테스트
    USE: 임시 파일 조작 후 원복
  </action>
  <verify>
    echo "ALL E2E TESTS PASSED" 이 출력되어야 함
  </verify>
  <done>
    fresh/verify/update 3모드 + session-start 분기 + setup 프롬프트 분기 전체 정상 동작
  </done>
</task>

<task type="checkpoint:human-verify">
  <name>사용자 리뷰</name>
  <files>
    scripts/bootstrap.sh
    .hxsk/hooks/session-start.sh
    prompts/setup.md
    prompts/setup-claude.md
    .hxsk/skills/bootstrap/SKILL.md
  </files>
  <action>
    전체 변경사항을 사용자가 리뷰.
    설계 문서와의 일관성, 범용 에이전트 호환성 확인.
  </action>
  <verify>
    사용자 승인
  </verify>
  <done>
    사용자가 전체 변경사항을 승인
  </done>
</task>

## Must-Haves
After all tasks complete, verify:
- [ ] bootstrap.sh가 fresh/verify/update 3모드 정상 동작
- [ ] .bootstrap-version 파일 자동 생성/갱신
- [ ] 2-hop 컨텍스트가 [NEW/UPDATED] 항목에서 출력
- [ ] setup.md에 Step 0 상태 감지 + 초기/업데이트 분기
- [ ] setup-claude.md에 동일 분기 + Claude 전용 갱신 안내
- [ ] session-start.sh가 startup/resume/compact 분기
- [ ] bootstrap SKILL.md v5.0.0 업데이트 시나리오 포함
- [ ] 기존 기능 하위 호환 (fresh 모드 = 기존 동작과 동일)

## Success Criteria
- [ ] All tasks verified passing
- [ ] Must-haves confirmed
- [ ] E2E fresh → verify → update 사이클 통과
- [ ] 사용자 리뷰 승인
