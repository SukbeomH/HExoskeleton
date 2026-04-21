# HXSK Setup E2E — Scenario Exploration

**Scenario**: 실제 사용자 입장에서 setup 단계부터 e2e 검증  
**Domain**: Software / HXSK boilerplate  
**Depth**: Standard (25 iterations)  
**Focus**: failures, first-run UX, upgrade path, edge-cases  
**Date**: 2026-04-21  
**Score**: 900 / scenario_score formula

---

## Dimension Coverage

| Dimension | Iterations | Critical | High | Medium | Low |
|-----------|-----------|---------|------|--------|-----|
| happy_path | 1 | — | — | — | 1 |
| first_run_ux | 4 (#2,10,16,24) | — | 4 | — | — |
| error_path | 5 (#3,4,11,12,17) | 2 | 2 | 1 | — |
| upgrade_path | 6 (#6,7,8,9,19,23) | 1 | 2 | 2 | — |
| edge_case | 7 (#5,13,14,18,22,25,+) | 1 | 1 | 3 | 1 |
| permission | 1 (#15) | — | 1 | — | — |
| integration | 1 (#21) | — | — | 1 | — |
| recovery | 1 (#20) | — | 1 | — | — |
| temporal | 1 (#23) | — | — | 1 | — |

---

## CRITICAL Scenarios (3)

### [CRITICAL] #3: Step 0 .bootstrap-version 파일 손상 → FRESH 오분기

**Actors:** Claude Code 에이전트  
**Precondition:** `.hxsk/.bootstrap-version` 존재, 내용 손상 (`version:` 필드 없음)  
**Trigger:** Step 0 감지 스크립트 실행  
**Flow:**
1. `grep '^version:' .hxsk/.bootstrap-version` → 매칭 없음
2. `CUR_VERSION=""` → `FRESH` 분기 진입
3. 실제 v5.4.0+ 설치 상태에서 FRESH 처리
4. SPEC.md, STATE.md, PATTERNS.md 덮어쓰기 시도

**Expected outcome:** 파일 존재 + `version:` 없음 → `CORRUPTED` 분기, 수동 복구 안내  
**Severity:** Critical

---

### [CRITICAL] #17: md-store-memory.sh 타입 디렉토리 없음 → 조용한 실패

**Actors:** Claude Code 에이전트  
**Precondition:** `.hxsk/memories/` 있지만 타입 서브디렉토리 없음  
**Trigger:** `bash .hxsk/hooks/md-store-memory.sh "제목" "내용" "태그" "architecture-decision"` 실행  
**Flow:**
1. `TARGET_DIR=".hxsk/memories/architecture-decision"` 도출
2. 디렉토리 없음 → 파일 생성 실패
3. exit code 1, 에러 메시지 없음 (조용한 실패)
4. 에이전트는 저장됐다 가정하고 계속 진행

**Expected outcome:** `md-store-memory.sh` 내부에서 `mkdir -p "$TARGET_DIR"` 수행  
**Severity:** Critical

---

### [CRITICAL] #19: U6 git add -A → .env 파일 커밋 포함

**Actors:** 업그레이드 사용자  
**Precondition:** 프로젝트 루트 `.env` 파일 존재, `.gitignore`에 `.env` 없음  
**Trigger:** Step U6 `git add -A` 실행  
**Flow:**
1. `git add -A` → `.env` 스테이징
2. `git commit -m "chore(hxsk): ..."` → 비밀 키 커밋 포함

**Expected outcome:** U6에서 `git add -A` 대신 프레임워크 파일 명시적 스테이징  
**Severity:** Critical — 시크릿 유출

---

## HIGH Scenarios (10)

### [HIGH] #2: setup.md 길이로 인한 단계 건너뜀

신규 사용자가 setup.md를 읽지 않고 `/bootstrap` 직접 실행 → `[FAIL] SPEC.md not found` 에러 + 다음 단계 안내 없음

### [HIGH] #4: Windows Git Bash symlink 생성 실패

Developer Mode OFF 환경에서 `ln -sfn` 실패 → `.claude/skills/` 미생성 → 스킬 로드 실패

### [HIGH] #5: 이전 실패 설치 잔재 — settings.json 덮어쓰기

부분 설치 후 재설치 시 기존 커스텀 훅이 담긴 settings.json 덮어쓰기

### [HIGH] #6: U1 수정 파일 감지 — 결정 트리 판단 기준 불명확

프레임워크 파일 수정 vs 프로젝트 확장 구분 기준 없어 오판 → `git stash` 후 U3 rsync → 머지 충돌

### [HIGH] #8: U3 rsync 폴백 — 빈 디렉토리 복사

rsync 없는 환경에서 `cp -r` 성공했지만 실제 파일 내용 없음 → U4 bootstrap FAIL

### [HIGH] #10: SPEC.md 플레이스홀더 미교체 → /planner 무의미한 계획

완료 체크리스트에 강제 검증 없어 `{placeholder}` 상태로 `/planner` 실행

### [HIGH] #11: settings.json 훅 누락 — PreCompact 미등록

8개 이벤트 중 일부 누락 → 컨텍스트 압축 전 메모리 저장 실패, 조용한 손실

### [HIGH] #15: .hxsk/ 읽기 전용 — 공유 환경 write 권한 없음

CI 에이전트 또는 read-only checkout에서 Step 3 파일 생성 실패

### [HIGH] #16: /planner 실행 시 SPEC.md Goals 섹션 없음 — GATE-0 미충족

Goals/Scope 섹션 없으면 GATE-0 차단, 형식 예시 안내 없음

### [HIGH] #20: 업그레이드 롤백 — .bak 파일 없어 복구 불가

settings.json 백업 조건부 실행 → 없을 때 `git checkout` 기반 복구 안내 없음

### [HIGH] #24: 완료 체크리스트 시각적 체크만 — 검증 명령 없음

"필수 스킬 5개 배치됨" 등 항목에 실제 검증 명령 없어 "다 했다" 착각

---

## MEDIUM Scenarios (8)

#7, #9, #12, #13, #18, #21, #23, #25 — 상세는 scenario-results.tsv 참조

---

## LOW Scenarios (1)

#14 — Claude Code + Gemini CLI 동시 symlink race condition (드문 케이스)
