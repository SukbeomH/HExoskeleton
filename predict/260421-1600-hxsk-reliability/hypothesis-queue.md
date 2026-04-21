# HXSK Reliability Predict — Hypothesis Queue

**Session**: 260421-1600-hxsk-reliability  
**Date**: 2026-04-21  
**Format**: chain handoff ready (debug/fix/security)

---

## Ranked Hypotheses (priority_score 순)

### HYP-01: CLAUDE_PROJECT_DIR 미설정 시 메모리 쓰기 경로 오염
**score**: 0.88  
**chain**: fix  
**Testable**: `unset CLAUDE_PROJECT_DIR && bash .hxsk/hooks/md-store-memory.sh "test" "test" "test" "test"`  
**Expected failure**: `.hxsk/` 경로가 현재 디렉토리 기준으로 생성됨  
**Fix target**: 모든 훅/스크립트 초반에 `CLAUDE_PROJECT_DIR` presence check 추가  

---

### HYP-02: TYPE_DIR 없을 때 general 리다이렉트 + 타입 recall 영구 실패
**score**: 0.85  
**chain**: fix  
**Testable**:
```bash
rm -rf .hxsk/memories/architecture-decision
bash .hxsk/hooks/md-store-memory.sh "AD-test" "content" "tag" "architecture-decision"
ls .hxsk/memories/architecture-decision/ 2>/dev/null || echo "NOT CREATED"
ls .hxsk/memories/general/ | grep "AD-test"
```
**Expected**: general에 저장, architecture-decision 미생성  
**Fix**: `mkdir -p "$TYPE_DIR"` 추가 + stderr warning  

---

### HYP-03: recall fallback이 쿼리와 무관한 파일 반환
**score**: 0.82  
**chain**: debug  
**Testable**:
```bash
bash .hxsk/hooks/md-recall-memory.sh "zzz-nonexistent-topic-xyz" "." 5 compact
# → 최근 파일 5개 반환 여부 확인
```
**Expected failure**: 무관 파일 5개 + [NO_MATCH] 없음  
**Fix**: 매칭 없을 시 빈 결과 반환 + stderr에 [NO_MATCH] 출력  

---

### HYP-04: SIGKILL 후 prune-tick stale lock 재현
**score**: 0.71  
**chain**: debug  
**Testable**:
```bash
# 터미널 A
bash .hxsk/scripts/prune-tick.sh &
kill -9 $!
# 터미널 B
ls .hxsk/.prune-lock/ && echo "LOCK EXISTS"
bash .hxsk/scripts/prune-tick.sh  # → 즉시 exit 0 (차단 여부 확인)
```
**Expected failure**: LOCK_DIR 잔존, 이후 prune 차단  

---

### HYP-05: head-100 캡으로 오래된 고가치 메모리 검색 실패
**score**: 0.68  
**chain**: fix  
**Testable**: memories/ 폴더에 110개 이상 파일 생성 후 101번째 파일 쿼리 시도  
**Fix**: `HXSK_RECALL_MAX` 변수화, 기본값 500  

---

### HYP-06: set -euo pipefail 누락으로 부분 실패 후 계속 실행
**score**: 0.65  
**chain**: fix  
**Testable**:
```bash
# md-store-memory.sh에서 중간 명령을 강제 실패시킨 후
# 후속 단계 실행 여부 확인
```
**Fix**: `set -euo pipefail` 또는 명시적 `|| exit 1`  

---

### HYP-07: YAML 인젝션 — 따옴표 포함 TITLE로 frontmatter 파괴
**score**: 0.62  
**chain**: security  
**Testable**:
```bash
bash .hxsk/hooks/md-store-memory.sh 'Test "title"' "content" "tag" "general"
head -5 .hxsk/memories/general/test-title*.md  # frontmatter 구조 확인
```
**Expected failure**: YAML parse error 또는 구조 파괴  

---

### HYP-08: check-consistency.sh python3 훅 패턴 누락
**score**: 0.60  
**chain**: fix  
**Testable**:
```bash
grep -c 'python3 .hxsk' .claude/settings.json || echo "0 python3 hooks"
bash .hxsk/hooks/check-consistency.sh 2>&1 | grep -i "python"
# → python3 훅이 있는데 check에서 미감지 여부
```

---

### HYP-09: .env auto-copy 경고 없음
**score**: 0.58  
**chain**: fix  
**Testable**:
```bash
rm .env 2>/dev/null; bash .hxsk/scripts/bootstrap.sh 2>&1 | grep -i "\.env"
# → warning 없이 복사 완료 여부
```

---

### HYP-10: stop-context-save.sh 플래그 삭제 경쟁
**score**: 0.52  
**chain**: debug  
**Testable**: 백그라운드 저장 실패를 시뮬레이션 후 다음 세션 "변경사항 없음" 오인 여부  

---

### HYP-11: prune-memories.sh source 설정 파일 임의 실행
**score**: 0.50  
**chain**: security  
**Testable**:
```bash
echo 'echo PWNED >&2' > .hxsk/.prune-config.sh
bash .hxsk/scripts/prune-memories.sh --dry-run 2>&1 | grep PWNED
```
**Fix**: key=value 파싱으로 교체  

---

## Chain Handoff Ready

```json
{
  "fix_targets": ["HYP-01", "HYP-02", "HYP-03", "HYP-05", "HYP-06", "HYP-07", "HYP-08", "HYP-09"],
  "debug_targets": ["HYP-04", "HYP-10"],
  "security_targets": ["HYP-07", "HYP-11"],
  "priority_order": ["HYP-01", "HYP-02", "HYP-03", "HYP-04", "HYP-05"]
}
```
