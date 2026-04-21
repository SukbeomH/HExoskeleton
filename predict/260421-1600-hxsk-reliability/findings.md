# HXSK Reliability Predict — Findings

**Session**: 260421-1600-hxsk-reliability  
**Date**: 2026-04-21

---

## Confirmed Findings (≥3/5 consensus)

### [CONFIRMED-01] DA-3: CLAUDE_PROJECT_DIR 미검증 systemic risk

**Severity**: HIGH  
**Consensus**: 5/5  
**Priority Score**: 0.88  
**Location**: `.hxsk/hooks/*.sh`, `.hxsk/scripts/*.sh` — 전 스크립트  

**Issue**: 모든 핵심 스크립트가 `${CLAUDE_PROJECT_DIR:-.}` 패턴 사용. 환경 변수 미설정 시 현재 디렉토리(`.`)로 폴백하지만, Claude Code 서브에이전트나 CI에서 CWD가 프로젝트 루트가 아닐 경우 전체 메모리 시스템이 잘못된 경로를 조용히 참조.

**Impact**: 단일 env 미설정 → 전체 훅 체인 무성 실패 (데이터 쓰기는 성공하지만 엉뚱한 위치에)

**Fix**:
```bash
# 각 스크립트 초반에 추가
if [ ! -d "${CLAUDE_PROJECT_DIR:-.}/.hxsk" ]; then
    echo "[ERROR] .hxsk/ not found. Set CLAUDE_PROJECT_DIR to project root." >&2
    exit 1
fi
PROJ="${CLAUDE_PROJECT_DIR:-.}"
```

---

### [CONFIRMED-02] RE-1: TYPE_DIR 누락 시 조용한 general 리다이렉트

**Severity**: HIGH  
**Consensus**: 5/5  
**Priority Score**: 0.85  
**Location**: `md-store-memory.sh:20-25`  

**Issue**:
```bash
TYPE_DIR="$MEMORIES_DIR/$TYPE"
if [ ! -d "$TYPE_DIR" ]; then
    TYPE_DIR="$MEMORIES_DIR/general"  # 조용히 general로
    mkdir -p "$TYPE_DIR"
fi
```
요청된 TYPE이 없으면 경고 없이 "general"에 저장. 에이전트는 타입별 저장 성공으로 인식. 이후 타입 필터 recall 시 영구 누락.

**Fix**:
```bash
if [ ! -d "$TYPE_DIR" ]; then
    echo "[WARN] Memory type '$TYPE' directory not found. Creating it." >&2
    mkdir -p "$TYPE_DIR"
fi
```

---

### [CONFIRMED-03] DA-4: md-recall-memory.sh fallback 무관 파일 반환

**Severity**: HIGH  
**Consensus**: 5/5  
**Priority Score**: 0.82  
**Location**: `md-recall-memory.sh:29-34`  

**Issue**: 쿼리 매칭 파일이 없으면 최근 수정 파일 N개를 반환. 반환 시 [NO_MATCH] 같은 마커 없음 → 에이전트가 실제 관련 결과와 폴백 결과 구분 불가.

**Impact**: 잘못된 "메모리 히트"로 에이전트 의사결정 오염

**Fix**:
```bash
if [ ${#matched_files[@]} -eq 0 ]; then
    echo "[NO_MATCH] No memory files found for query: $QUERY" >&2
    exit 0  # 빈 결과가 fallback보다 안전
fi
```

---

### [CONFIRMED-04] SA-8/RE-4: SIGKILL → stale lock → prune 영구 차단

**Severity**: MEDIUM  
**Consensus**: 5/5  
**Priority Score**: 0.71  
**Location**: `prune-tick.sh:57-63`  

**Issue**:
```bash
mkdir "$LOCK_DIR" || exit 0     # 잠금 획득
trap 'rmdir "$LOCK_DIR"' EXIT   # EXIT trap으로 해제
```
SIGKILL 시 trap이 실행되지 않아 LOCK_DIR 잔존. 이후 모든 prune-tick 호출이 `mkdir` 실패로 즉시 exit → prune 영구 차단.

**Fix**: stale lock 감지 추가
```bash
if [ -d "$LOCK_DIR" ]; then
    lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_DIR" 2>/dev/null || echo 0) ))
    if [ "$lock_age" -gt 300 ]; then
        rmdir "$LOCK_DIR" 2>/dev/null || true
    else
        exit 0
    fi
fi
```

---

### [CONFIRMED-05] RE-6/PE-6: md-recall-memory.sh head-100 하드 캡

**Severity**: MEDIUM  
**Consensus**: 4/5  
**Priority Score**: 0.68  
**Location**: `md-recall-memory.sh:23`  

**Issue**: `| sort -r | head -100 | xargs grep -li "$QUERY"` — 최근 100개 파일만 검색. shared-tier 메모리가 100개 초과 시 오래된 기억(architecture-decision 등 고가치 항목)이 검색 범위에서 영구 제외.

**Fix**: 캡을 설정 변수화
```bash
RECALL_MAX="${HXSK_RECALL_MAX:-500}"
... | sort -r | head "$RECALL_MAX" | xargs grep -li "$QUERY"
```

---

### [CONFIRMED-06] RE-3: set -uo pipefail (missing -e) in hooks

**Severity**: MEDIUM  
**Consensus**: 4/5  
**Priority Score**: 0.65  
**Location**: `md-store-memory.sh:7`, `md-recall-memory.sh:8`  

**Issue**: `set -uo pipefail`에 `-e` 없음. 중간 명령 실패해도 스크립트 계속 실행. 특히 파일 생성 실패 후 후속 단계(태그 인덱싱 등)가 부분적 상태로 진행.

**Fix**: `set -euo pipefail` 또는 명시적 에러 처리 추가

---

### [CONFIRMED-07] RE-5: md-store-memory.sh YAML 인젝션 벡터

**Severity**: MEDIUM  
**Consensus**: 4/5  
**Priority Score**: 0.62  
**Location**: `md-store-memory.sh:37-39`  

**Issue**: 
```bash
echo "title: \"$TITLE\""
xargs grep -li "title: \"$TITLE\""
```
`$TITLE`에 `"` 또는 `\n` 포함 시 YAML frontmatter 구조 파괴. 에이전트 제어 입력이므로 실제 악용 가능성은 낮지만 내부 오류 발생 가능.

**Fix**: TITLE 값 sanitization
```bash
TITLE_SAFE="${TITLE//\"/\'}"
echo "title: \"$TITLE_SAFE\""
```

---

### [CONFIRMED-08] DA-5: check-consistency.sh Python 훅 미감지

**Severity**: MEDIUM  
**Consensus**: 4/5  
**Priority Score**: 0.60  
**Location**: `check-consistency.sh:136-147`  

**Issue**: 훅 레퍼런스 추출 패턴이 `bash .hxsk/` 만 탐색. `python3 .hxsk/` 또는 `node .hxsk/` 패턴 훅은 검증 대상에서 누락.

**Fix**: 패턴 확장
```bash
grep -E '(bash|python3|node|sh) \.hxsk/'
```

---

### [CONFIRMED-09] SA-5/PE-5: bootstrap.sh .env.example 자동 복사

**Severity**: MEDIUM  
**Consensus**: 4/5  
**Priority Score**: 0.58  
**Location**: `bootstrap.sh:203-210`  

**Issue**: `.env` 없을 때 `.env.example`을 자동 복사하면서 `report_new`만 호출 (warning 없음). 사용자가 `.env`가 생성됐는지 인지 못한 채로 placeholder 값이 실제 환경에 사용될 수 있음.

**Note**: DA 도전으로 HIGH → MEDIUM 하향 (자동 복사는 대부분 환경에서 safe)

**Fix**: `report_warn "Creating .env from .env.example — review values before proceeding"` 추가

---

### [CONFIRMED-10] SA-7: stop-context-save.sh 플래그 삭제 경쟁 조건

**Severity**: MEDIUM  
**Consensus**: 3/5  
**Priority Score**: 0.52  
**Location**: `stop-context-save.sh:20-21`  

**Issue**: `.modified-this-session` 플래그를 백그라운드 서브셸 시작 전에 삭제. 백그라운드 저장 실패 시 플래그 부재로 다음 세션이 "변경사항 없음"으로 오인.

**Fix**: 백그라운드 완료 후 플래그 삭제, 또는 완료 시 성공 마커 기록

---

### [CONFIRMED-11] DA-2: prune-memories.sh config source 임의 실행

**Severity**: MEDIUM  
**Consensus**: 3/5  
**Priority Score**: 0.50  
**Location**: `prune-memories.sh:62-63`  

**Issue**: `source "$PRUNE_CFG"` — PRUNE_CFG 파일(gitignored)을 직접 소싱. 파일 내용이 임의 bash이므로 오염된 설정 파일로 임의 코드 실행 가능.

**Note**: DA 도전으로 HIGH → MEDIUM 하향 (내부 툴체인, 외부 입력 경로 없음)

**Fix**: 설정 파일 파싱 방식 변경 (key=value 포맷만 허용)
```bash
while IFS='=' read -r key val; do
    [[ "$key" =~ ^[A-Z_]+$ ]] && declare "$key=$val"
done < "$PRUNE_CFG"
```

---

## Probable Findings (2/5 consensus)

### [PROBABLE-01] RE-2: 2-hop related 검색 sed 조기 종료

**Severity**: LOW  
**Consensus**: 2/5  
**Priority Score**: 0.35  
**Location**: `md-recall-memory.sh:45`  

**Issue**: `sed -n '/^related:/,/^[a-z]/p'` — 종료 패턴 `/^[a-z]/`이 의도보다 일찍 트리거될 수 있음 (예: `review:`, `result:` 같은 소문자 필드).

**Condition**: related 필드 다음에 소문자 시작 frontmatter 필드가 있을 때만 발생

---

### [PROBABLE-02] SA-6: pre-compact-save.sh #!/bin/bash 불일치

**Severity**: LOW  
**Consensus**: 2/5  
**Priority Score**: 0.28  
**Location**: `pre-compact-save.sh:1`  

**Issue**: `#!/bin/bash` 사용 — 다른 모든 스크립트는 `#!/usr/bin/env bash`. NixOS나 일부 Linux 배포판에서 `/bin/bash` 경로 부재 가능.

---

## Minority Findings (1/5 consensus)

### [MINORITY-01] RE-7/PE-7: prune-memories.sh awk over-match

**Severity**: LOW  
**Consensus**: 1/5  
**Priority Score**: 0.15  
**Location**: `prune-memories.sh:170-182`  

**Issue**: `awk '/^---$/{c++; next} c==1'` frontmatter 전체 읽기 → 태그 매칭 시 비-태그 필드에서 오탐 가능.

**Note**: 실제 재현 시나리오 미확인. 관찰 유지.
