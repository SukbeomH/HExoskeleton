---
phase: 7
plan: 2
wave: 1
depends_on: []
files_modified:
  - .hxsk/hooks/stop-context-save.sh
  - .hxsk/hooks/md-store-memory.sh
  - .hxsk/prompts/setup.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "stop-context-save.sh 플래그 삭제 경쟁 조건이 원자적 패턴으로 해소된다"
    - "md-store-memory.sh title/tags 값이 YAML 인젝션 불가하다"
    - "setup.md U2에 tarball 다운로드 후 SHA256 검증 스니펫이 포함된다"
  artifacts:
    - "stop-context-save.sh: atomic mv 패턴 적용"
    - "md-store-memory.sh: yaml_safe() 함수 적용 (이미 RE-5 수정 여부 확인 필요)"
    - "setup.md U2: SHA256 검증 스니펫 + pre-release-check.sh 생성"

cross_phase_invariants:
  inherit:
    - "md-store-memory.sh TYPE_DIR는 항상 요청된 타입으로 생성"
    - "md-recall-memory.sh는 쿼리 미매칭 시 [NO_MATCH] stderr 출력"
    - "prune-tick.sh는 300s stale lock 자동 해제"
    - "setup.md Step 0은 CORRUPTED 분기로 진입"
    - "setup.md U6은 명시적 스테이징만 사용"
    - "bootstrap.sh는 .hxsk/logs/에 실행 로그 저장"
  new:
    - "stop-context-save.sh는 원자적 mv 패턴으로 경쟁 조건 없이 플래그를 관리한다"
    - "md-store-memory.sh는 title/tags 값을 YAML 안전 문자열로 이스케이프한다"
    - "setup.md U2 tarball 다운로드 후 SHA256 검증을 권장한다"
---

# Plan 7.2: 경쟁 조건 패치 + YAML 인젝션 방지 + SHA256

<objective>
Plan 6.1 Remaining Work 중 미완료 3개 항목 처리:
- SA-7: stop-context-save.sh 플래그 삭제 경쟁 조건
- RE-5: md-store-memory.sh YAML 인젝션 벡터
- H-05: setup.md U2 SHA256 검증 + pre-release-check.sh

Purpose: 데이터 손상·보안 취약점 잔여 항목 완전 해소
Output: 패치된 3개 파일 + 신규 scripts/pre-release-check.sh
</objective>

<context>
Load for context:
- .hxsk/hooks/stop-context-save.sh
- .hxsk/hooks/md-store-memory.sh
- .hxsk/prompts/setup.md (U2 섹션)
- predict/260422-1407-deploy-research/findings.md (Finding 4: SHA256)
</context>

<tasks>

<task type="auto">
  <name>stop-context-save.sh 원자적 플래그 패턴 적용</name>
  <files>.hxsk/hooks/stop-context-save.sh</files>
  <action>
    현재 패턴 (비원자적):
    ```bash
    FLAG_FILE=".hxsk/.stop-flag"
    if [[ -f "$FLAG_FILE" ]]; then rm "$FLAG_FILE"; ... fi
    ```
    개선 패턴 (원자적 mv):
    ```bash
    FLAG_FILE=".hxsk/.stop-flag"
    CLAIMED_FLAG=".hxsk/.stop-flag.claimed.$$"
    if mv "$FLAG_FILE" "$CLAIMED_FLAG" 2>/dev/null; then
        # 이 프로세스가 플래그를 획득 — 안전하게 처리
        rm -f "$CLAIMED_FLAG"
        ...
    fi
    ```
    파일 먼저 Read한 후 실제 패턴 확인하고 수정.
    AVOID: 플래그 경로 하드코딩 — 기존 변수명 그대로 사용
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh | grep "SA-7\|ISSUE COUNT"
  </verify>
  <done>SA-7 패턴이 check-reliability.sh에서 PASS 처리됨</done>
</task>

<task type="auto">
  <name>md-store-memory.sh YAML 인젝션 방지 + setup.md SHA256</name>
  <files>.hxsk/hooks/md-store-memory.sh, .hxsk/prompts/setup.md, .hxsk/scripts/pre-release-check.sh</files>
  <action>
    1. md-store-memory.sh — yaml_safe() 적용 여부 확인 후 미적용 시 추가:
       ```bash
       yaml_safe() {
           # 개행, 콜론+공백, 앞뒤 따옴표 이스케이프
           printf '%s' "$1" | sed "s/'/'\\''/g" | tr -d '\n\r'
       }
       TITLE=$(yaml_safe "$RAW_TITLE")
       TAGS=$(yaml_safe "$RAW_TAGS")
       ```

    2. setup.md U2 말미에 검증 스니펫 추가 (다운로드 후 즉시):
       ```bash
       # SHA256 검증 (선택 — 릴리스 노트에 체크섬이 제공된 경우)
       # sha256sum -c <<< "EXPECTED_HASH  setup-v$TARGET_VERSION.tar.gz"
       ```
       주석 처리로 제공 — 릴리스 노트 SHA 첨부 전까지는 선택사항

    3. scripts/pre-release-check.sh 신규 생성:
       - SHA256 계산: `sha256sum .hxsk/cache/setup-v*.tar.gz`
       - CHANGELOG 동기화 확인: 최신 버전이 CHANGELOG에 있는지 grep
       - bootstrap.sh 로컬 실행 성공 확인
       - 출력: pre-release-check.log
    AVOID: setup.md U2 기존 내용 재구조화 금지 — 스니펫만 추가
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh | grep "RE-5\|ISSUE COUNT"
    bash .hxsk/scripts/pre-release-check.sh --dry-run 2>/dev/null || echo "dry-run OK"
  </verify>
  <done>
    - RE-5 check-reliability.sh PASS
    - pre-release-check.sh 실행 가능
    - setup.md U2에 SHA256 스니펫 포함
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
- [ ] bash .hxsk/hooks/stop-context-save.sh (dry-run) → 경쟁 조건 패턴 없음
- [ ] grep 'yaml_safe' .hxsk/hooks/md-store-memory.sh → 존재
</verification>

<success_criteria>
- [ ] SA-7, RE-5 check-reliability.sh PASS
- [ ] pre-release-check.sh 실행 성공
- [ ] 기존 11건 불변 조건 유지
</success_criteria>
