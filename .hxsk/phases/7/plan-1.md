---
phase: 7
plan: 1
wave: 1
depends_on: []
files_modified:
  - .hxsk/scripts/bootstrap.sh
  - .hxsk/scripts/setup-verify.sh
autonomous: true
user_setup: []

must_haves:
  truths:
    - "bootstrap.sh 실패 시 원인과 복구 경로가 출력된다 (DA-7 반영)"
    - "bootstrap.sh 실행 결과가 .hxsk/logs/ 에 파일로 저장된다"
    - "setup-verify.sh가 필수 5개 조건을 검증하고 PASS/FAIL 반환한다"
  artifacts:
    - ".hxsk/logs/bootstrap-YYYYMMDD-HHMMSS.log 존재"
    - ".hxsk/scripts/setup-verify.sh 생성"
  key_links:
    - "bootstrap.sh FAIL → .hxsk/logs/ 로그 + setup.md 참조 메시지"

cross_phase_invariants:
  inherit:
    - "md-store-memory.sh TYPE_DIR는 항상 요청된 타입으로 생성"
    - "md-recall-memory.sh는 쿼리 미매칭 시 [NO_MATCH] stderr 출력"
    - "prune-tick.sh는 300s stale lock 자동 해제"
    - "setup.md Step 0은 CORRUPTED 분기로 진입"
    - "setup.md U6은 명시적 스테이징만 사용"
  new:
    - "bootstrap.sh는 항상 .hxsk/logs/에 실행 로그를 저장한다"
    - "bootstrap.sh FAIL 메시지는 구체적 원인 + setup.md 섹션 참조를 포함한다"
---

# Plan 7.1: bootstrap 오류 처리 + 설치 검증 스크립트

<objective>
DA-7 소수의견("자동화 전에 오류 복구 경로를 먼저 명시") 반영.
bootstrap.sh 실행 결과를 파일로 저장하고, 실패 시 구체적 복구 안내를 출력한다.
신규 setup-verify.sh로 설치 완료 상태를 자동 검증한다.

Purpose: 설치 실패 후 사용자가 스스로 복구할 수 있는 최소 안전망 확보
Output: 개선된 bootstrap.sh + .hxsk/scripts/setup-verify.sh
</objective>

<context>
Load for context:
- .hxsk/scripts/bootstrap.sh (현재 477줄)
- .hxsk/phases/6/plan-1-SUMMARY.md (Plan 6.1 완료 항목)
- predict/260422-1407-deploy-research/findings.md (Finding 6: 로그 미저장)
</context>

<tasks>

<task type="auto">
  <name>bootstrap.sh 로그 저장 + FAIL 메시지 개선</name>
  <files>.hxsk/scripts/bootstrap.sh</files>
  <action>
    1. 로그 디렉토리 생성 및 실행 로그 tee 저장:
       ```bash
       LOG_DIR=".hxsk/logs"
       mkdir -p "$LOG_DIR"
       LOG_FILE="$LOG_DIR/bootstrap-$(date +%Y%m%d-%H%M%S).log"
       # main 함수 래핑: bootstrap_main 2>&1 | tee "$LOG_FILE"
       ```
    2. FAIL 출력 패턴 개선 — 각 report_fail 호출 후 복구 경로 추가:
       ```bash
       report_fail() {
         local category="$1" msg="$2"
         echo "[FAIL] $category: $msg"
         echo "       → 복구: setup.md의 해당 Step을 참조하거나 \`bash .hxsk/scripts/setup-verify.sh\` 실행"
       }
       ```
    3. 종료 시 로그 경로 출력: "로그 저장됨: $LOG_FILE"
    AVOID: 로그 파일 누적 무한 증가 → 최근 10개만 유지 (find + rm 패턴)
  </action>
  <verify>
    bash .hxsk/scripts/bootstrap.sh
    ls .hxsk/logs/ | grep bootstrap
  </verify>
  <done>
    - .hxsk/logs/bootstrap-*.log 파일 생성됨
    - 실행 후 "로그 저장됨: .hxsk/logs/..." 출력
    - FAIL 항목에 "→ 복구:" 안내 포함
  </done>
</task>

<task type="auto">
  <name>setup-verify.sh 생성 — 5개 필수 조건 자동 검증</name>
  <files>.hxsk/scripts/setup-verify.sh</files>
  <action>
    신규 스크립트 생성. 다음 5개 조건을 순서대로 검증:
    1. .claude/skills/ 에 스킬 5개 이상 존재: `ls .claude/skills/ | wc -l`
    2. .claude/agents/ 에 에이전트 파일 존재: `ls .claude/agents/*.md 2>/dev/null`
    3. .claude/settings.json 에 훅 이벤트 7개 모두 존재:
       ```bash
       for hook in SessionStart PreToolUse PostToolUse PreCompact Stop SubagentStop SessionEnd; do
         grep -q "\"$hook\"" .claude/settings.json || FAIL+=("$hook 훅 누락")
       done
       ```
    4. .hxsk/memories/ 에 타입별 디렉토리 존재: `ls .hxsk/memories/`
    5. .hxsk/.bootstrap-version 파싱 가능: `grep '^version:' .hxsk/.bootstrap-version`

    출력 형식:
    ```
    [OK]   스킬 N개 설치됨
    [OK]   에이전트 M개 설치됨
    [FAIL] Stop 훅 누락 → setup.md Step 6 재실행
    ...
    PASS N/5 | FAIL M/5
    ```
    AVOID: set -e 전체 적용 금지 — 각 조건을 독립적으로 검사해야 함
  </action>
  <verify>
    bash .hxsk/scripts/setup-verify.sh
  </verify>
  <done>
    - 각 조건 [OK]/[FAIL] 출력
    - FAIL 항목에 복구 안내 포함
    - 전체 PASS/FAIL 집계 출력
    - exit 0 (모두 PASS) / exit 1 (하나 이상 FAIL)
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] bash .hxsk/scripts/bootstrap.sh → .hxsk/logs/ 에 로그 파일 생성
- [ ] bash .hxsk/scripts/setup-verify.sh → 5개 조건 검증 + PASS/FAIL 집계
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0 유지
</verification>

<success_criteria>
- [ ] bootstrap.sh 실행마다 .hxsk/logs/bootstrap-*.log 생성
- [ ] setup-verify.sh가 FAIL 항목에 구체적 복구 안내 출력
- [ ] 기존 신뢰성 11건 불변 조건 유지
</success_criteria>
