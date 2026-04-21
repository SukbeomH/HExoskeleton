---
phase: 6
plan: 1
wave: 1
gap_closure: false
cross_phase_invariants:
  inherit: []
  new:
    - md-store-memory.sh TYPE_DIR는 항상 요청된 타입으로 생성된다
    - md-recall-memory.sh는 쿼리 미매칭 시 [NO_MATCH]를 stderr에 출력한다
    - prune-tick.sh는 SIGKILL 이후 stale lock을 자동 해제한다
    - setup.md Step 0은 .bootstrap-version 손상 시 CORRUPTED 분기로 진입한다
    - setup.md U6는 git add -A 대신 프레임워크 파일만 명시적 스테이징한다
---

# Plan 6.1: HXSK 신뢰성 수정 — scenario+predict 발견 이슈

> 작성일: 2026-04-21  
> 근거: scenario/260421-1553-hxsk-setup-e2e/summary.md + predict/260421-1600-hxsk-reliability/findings.md  
> Verify: `bash .hxsk/scripts/check-reliability.sh` → ISSUE COUNT: 0  
> Baseline: 11 issues  

---

## Objective

autoresearch:scenario(25 iterations) + autoresearch:predict(5 personas × 2 rounds)에서 발견된 신뢰성 이슈 11건을 수정한다.
데이터 손실(C1·C2), 보안(C3), 조용한 실패(RE-1·DA-4·SA-8), 환경 의존성(DA-3) 패턴을 제거한다.

---

## Context

Load for context:
- `.hxsk/hooks/md-store-memory.sh`
- `.hxsk/hooks/md-recall-memory.sh`
- `.hxsk/scripts/prune-tick.sh`
- `.hxsk/prompts/setup.md`
- `predict/260421-1600-hxsk-reliability/findings.md`
- `scenario/260421-1553-hxsk-setup-e2e/summary.md`

---

## Tasks

<task type="auto">
  <name>setup.md: CORRUPTED 분기 추가 + U6 명시적 스테이징</name>
  <files>
    .hxsk/prompts/setup.md
  </files>
  <action>
    **C1 (Critical): Step 0 CORRUPTED 분기 추가**
    
    현재 Step 0 감지 스크립트:
    ```
    case "${CUR_VERSION:-}" in
      "") echo "FRESH" ;;
      "$TARGET_VERSION") echo "VERIFY" ;;
      *) echo "UPGRADE" ;;
    esac
    ```
    
    문제: `.bootstrap-version` 파일이 존재하지만 `version:` 필드가 없을 때 (내용 손상) →
    `CUR_VERSION`이 빈 문자열 → FRESH 분기 → 기존 SPEC.md/memories 덮어쓰기.
    
    수정: 파일 존재 여부와 내용 유효성을 분리 확인:
    ```bash
    VERSION_FILE=".hxsk/.bootstrap-version"
    if [ ! -f "$VERSION_FILE" ]; then
      echo "FRESH"
    elif ! grep -q '^version:' "$VERSION_FILE"; then
      echo "CORRUPTED"
    else
      CUR_VERSION=$(grep '^version:' "$VERSION_FILE" | awk '{print $2}')
      case "$CUR_VERSION" in
        "$TARGET_VERSION") echo "VERIFY" ;;
        *)                  echo "UPGRADE" ;;
      esac
    fi
    ```
    
    CORRUPTED 분기 처리 안내 추가:
    ```
    - **`CORRUPTED`** → ".bootstrap-version 내용을 확인하세요: `cat .hxsk/.bootstrap-version`
      정상 내용: `version: X.Y.Z`. 손상 시 `echo "version: X.Y.Z" > .hxsk/.bootstrap-version` 후 재실행."
    ```
    
    ---
    
    **C3 (Critical): U6 git add -A → 명시적 스테이징**
    
    현재 (353번째 줄 근처):
    ```
    git add -A
    ```
    
    수정: 프레임워크 파일만 명시적 스테이징으로 교체:
    ```bash
    git add .hxsk/ CLAUDE.md AGENTS.md GEMINI.md .claude/settings.json 2>/dev/null || true
    ```
    
    주석 추가: `# .env 등 프로젝트 파일 제외 — 프레임워크 파일만 스테이징`
    
    AVOID: `git add -A` — .gitignore 미설정 .env 등 시크릿 파일 커밋 위험
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh 2>&1 | grep "FAIL C"
    # 출력 없음이면 C1, C3 통과
  </verify>
  <done>
    - check-reliability.sh: "FAIL C1" 출력 없음
    - check-reliability.sh: "FAIL C3" 출력 없음
    - setup.md에 "CORRUPTED" 문자열 포함: `grep -c 'CORRUPTED' .hxsk/prompts/setup.md` ≥ 1
    - setup.md에 "git add -A" 미존재: `grep -c 'git add -A' .hxsk/prompts/setup.md` = 0
  </done>
</task>

<task type="auto">
  <name>md-store-memory.sh: TYPE_DIR 수정 + set -e + PROJ 검증</name>
  <files>
    .hxsk/hooks/md-store-memory.sh
  </files>
  <action>
    파일 전체를 Read한 후 아래 3가지를 수정:
    
    **RE-3a: set -uo pipefail → set -euo pipefail (7번째 줄)**
    ```bash
    # 변경 전
    set -uo pipefail
    # 변경 후
    set -euo pipefail
    ```
    
    **DA-3: CLAUDE_PROJECT_DIR 검증 추가 (PROJECT_DIR 설정 직후)**
    
    현재 (17번째 줄):
    ```bash
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    ```
    
    수정: PROJECT_DIR 설정 직후에 .hxsk/ 존재 확인 추가:
    ```bash
    PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
    if [ ! -d "$PROJECT_DIR/.hxsk" ]; then
        echo "[ERROR] md-store-memory: .hxsk/ not found at '$PROJECT_DIR'. Set CLAUDE_PROJECT_DIR to project root." >&2
        exit 1
    fi
    ```
    
    **RE-1: TYPE_DIR silent redirect 수정 (20-25번째 줄 근처)**
    
    현재:
    ```bash
    TYPE_DIR="$MEMORIES_DIR/$TYPE"
    if [ ! -d "$TYPE_DIR" ]; then
        TYPE_DIR="$MEMORIES_DIR/general"
        mkdir -p "$TYPE_DIR"
    fi
    ```
    
    수정: general로 리다이렉트하지 않고 요청된 타입 디렉토리를 직접 생성:
    ```bash
    TYPE_DIR="$MEMORIES_DIR/$TYPE"
    if [ ! -d "$TYPE_DIR" ]; then
        echo "[INFO] md-store-memory: Creating memory type directory: $TYPE" >&2
        mkdir -p "$TYPE_DIR"
    fi
    ```
    
    AVOID: `TYPE_DIR="$MEMORIES_DIR/general"` 폴백 — 타입별 recall 영구 실패 원인
    USE: `mkdir -p "$TYPE_DIR"` 직접 생성 — 요청된 타입 경로 유지
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh 2>&1 | grep "FAIL RE-1\|FAIL RE-3a\|FAIL DA-3.*store"
    # 출력 없음이면 통과
    
    # 기능 검증: 없는 타입으로 저장 시 해당 디렉토리 생성 확인
    TEST_TYPE="test-type-$$"
    bash .hxsk/hooks/md-store-memory.sh "test title" "test body" "test-tag" "$TEST_TYPE" 2>&1
    ls ".hxsk/memories/$TEST_TYPE/" && rm -rf ".hxsk/memories/$TEST_TYPE" && echo "TYPE_DIR creation: OK"
  </verify>
  <done>
    - check-reliability.sh: "FAIL RE-1" 없음
    - check-reliability.sh: "FAIL RE-3a" 없음
    - check-reliability.sh: "FAIL DA-3" (store) 없음
    - 새 타입으로 저장 시 해당 타입 디렉토리 생성 확인
    - general로 잘못 저장되지 않음 확인
  </done>
</task>

<task type="auto">
  <name>md-recall-memory.sh: [NO_MATCH] 추가 + head 캡 변수화 + set -e + PROJ 검증</name>
  <files>
    .hxsk/hooks/md-recall-memory.sh
  </files>
  <action>
    파일 전체를 Read한 후 아래 4가지를 수정:
    
    **RE-3b: set -uo pipefail → set -euo pipefail (8번째 줄)**
    ```bash
    set -euo pipefail
    ```
    
    **DA-3: CLAUDE_PROJECT_DIR 검증 (PROJECT_DIR/BASE_DIR 설정 직후)**
    ```bash
    if [ ! -d "${PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}/.hxsk" ]; then
        echo "[ERROR] md-recall-memory: .hxsk/ not found. Set CLAUDE_PROJECT_DIR to project root." >&2
        exit 1
    fi
    ```
    
    **RE-6: head -100 → HXSK_RECALL_MAX 변수화 (23번째 줄 근처)**
    
    현재:
    ```bash
    | sort -r \
    | head -100 \
    ```
    
    수정:
    ```bash
    RECALL_MAX="${HXSK_RECALL_MAX:-500}"
    ...
    | sort -r \
    | head "$RECALL_MAX" \
    ```
    
    **DA-4: 쿼리 미매칭 시 fallback 제거 + [NO_MATCH] 출력 (29-34번째 줄 근처)**
    
    현재 (매칭 없을 때 최근 파일 N개 반환):
    ```bash
    if [ ${#matched_files[@]} -eq 0 ]; then
        # 최근 파일 반환 (폴백)
        ...
    fi
    ```
    
    수정: fallback 대신 [NO_MATCH] 출력 후 빈 결과 반환:
    ```bash
    if [ ${#matched_files[@]} -eq 0 ]; then
        echo "[NO_MATCH] No memory files found for query: $QUERY" >&2
        exit 0
    fi
    ```
    
    AVOID: 쿼리와 무관한 최근 파일 반환 — 에이전트가 실제 recall과 fallback 구분 불가
    USE: [NO_MATCH] stderr + exit 0 — 빈 결과가 오염된 결과보다 안전
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh 2>&1 | grep "FAIL DA-4\|FAIL RE-6\|FAIL RE-3b\|FAIL DA-3.*recall"
    # 출력 없음이면 통과
    
    # [NO_MATCH] 동작 확인
    result=$(bash .hxsk/hooks/md-recall-memory.sh "zzz-impossible-query-xyz-$$" "." 5 compact 2>&1)
    echo "$result" | grep -q 'NO_MATCH' && echo "[NO_MATCH] test: OK" || echo "[NO_MATCH] test: FAIL"
  </verify>
  <done>
    - check-reliability.sh: "FAIL DA-4" 없음
    - check-reliability.sh: "FAIL RE-6" 없음
    - check-reliability.sh: "FAIL RE-3b" 없음
    - check-reliability.sh: "FAIL DA-3" (recall) 없음
    - 존재하지 않는 쿼리 실행 시 [NO_MATCH] 출력 확인
    - 정상 쿼리 실행 시 여전히 결과 반환 확인 (기존 기능 회귀 없음)
  </done>
</task>

<task type="auto">
  <name>prune-tick.sh: stale lock 감지 + PROJ 검증</name>
  <files>
    .hxsk/scripts/prune-tick.sh
  </files>
  <action>
    파일 전체를 Read한 후 아래 2가지를 수정:
    
    **DA-3: HXSK_DIR 설정 직후 .hxsk/ 검증 추가**
    ```bash
    if [ ! -d "$HXSK_DIR" ]; then
        echo "[ERROR] prune-tick: .hxsk/ not found at '$(dirname "$HXSK_DIR")'. Set CLAUDE_PROJECT_DIR." >&2
        exit 1
    fi
    ```
    
    **SA-8: SIGKILL stale lock 감지 추가 (59-62번째 줄 근처)**
    
    현재:
    ```bash
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        exit 0
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
    ```
    
    수정: stale lock 자동 해제 로직 추가:
    ```bash
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
        # stale lock 감지: 300초(5분) 이상 된 lock은 해제
        if [ -d "$LOCK_DIR" ]; then
            lock_ctime=$(stat -f %m "$LOCK_DIR" 2>/dev/null || stat -c %Y "$LOCK_DIR" 2>/dev/null || echo 0)
            now=$(date +%s)
            lock_age=$(( now - lock_ctime ))
            if [ "$lock_age" -gt 300 ]; then
                echo "[WARN] prune-tick: Removing stale lock (age: ${lock_age}s)" >&2
                rmdir "$LOCK_DIR" 2>/dev/null || true
                mkdir "$LOCK_DIR" 2>/dev/null || exit 0
            else
                exit 0
            fi
        else
            exit 0
        fi
    fi
    trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT
    ```
    
    AVOID: SIGKILL 이후 lock 디렉토리가 영구 잔존하는 현재 구조
    USE: mtime 기반 stale 감지 — 5분 후 자동 해제
    
    NOTE: `stat -f %m` (macOS) vs `stat -c %Y` (Linux) 크로스플랫폼 처리 포함
  </action>
  <verify>
    bash .hxsk/scripts/check-reliability.sh 2>&1 | grep "FAIL SA-8\|FAIL DA-3.*prune"
    # 출력 없음이면 통과
    
    # stale lock 시뮬레이션 (mtime을 과거로 조작)
    LOCK_TEST=".hxsk/.prune-lock-test-$$"
    mkdir "$LOCK_TEST"
    touch -t 200001010000 "$LOCK_TEST" 2>/dev/null || true
    # prune-tick이 stale 감지하는지 확인 (직접 실행 대신 패턴 확인)
    grep -q 'lock_age' .hxsk/scripts/prune-tick.sh && echo "Stale lock code: PRESENT" || echo "Stale lock code: MISSING"
    rmdir "$LOCK_TEST" 2>/dev/null || true
  </verify>
  <done>
    - check-reliability.sh: "FAIL SA-8" 없음
    - check-reliability.sh: "FAIL DA-3" (prune-tick) 없음
    - prune-tick.sh에 lock_age 변수 포함: `grep -c 'lock_age' .hxsk/scripts/prune-tick.sh` ≥ 1
    - prune-tick.sh에 300 임계값 포함: `grep -c '300' .hxsk/scripts/prune-tick.sh` ≥ 1
  </done>
</task>

---

## Final Verification

모든 태스크 완료 후 실행:

```bash
bash .hxsk/scripts/check-reliability.sh
# 기대 출력:
# ISSUE COUNT: 0
```

이슈 0건 = Plan 6.1 완료.

---

## Regression Checks

```bash
# 메모리 저장 기본 동작 확인
bash .hxsk/hooks/md-store-memory.sh "Plan6.1 smoke test" "verify regression" "test,plan6" "test" 2>&1
ls .hxsk/memories/test/*.md | tail -1 | xargs head -3

# recall 기본 동작 확인
bash .hxsk/hooks/md-recall-memory.sh "Plan6.1 smoke test" "." 3 compact 2>&1 | head -5

# prune-tick 기본 실행 (lock 획득 후 해제)
bash .hxsk/scripts/prune-tick.sh 2>&1; echo "Exit: $?"
```

---

## Metric Summary

| 수정 | 이슈 ID | 파일 | Before | After |
|------|---------|------|--------|-------|
| CORRUPTED 분기 | C1 | setup.md | `""` → FRESH | `""` → CORRUPTED |
| git add -A 제거 | C3 | setup.md | `git add -A` | 명시적 스테이징 |
| TYPE_DIR 직접 생성 | RE-1 | md-store-memory.sh | general 리다이렉트 | mkdir -p TYPE_DIR |
| set -euo | RE-3a/b | store+recall hooks | `-uo` | `-euo` |
| PROJ 검증 | DA-3 | store+recall+tick | 없음 | .hxsk/ 존재 확인 |
| [NO_MATCH] | DA-4 | md-recall-memory.sh | fallback 반환 | exit 0 + NO_MATCH |
| RECALL_MAX | RE-6 | md-recall-memory.sh | 하드코딩 100 | 변수 기본값 500 |
| stale lock | SA-8 | prune-tick.sh | 영구 차단 | 300s 후 자동 해제 |
