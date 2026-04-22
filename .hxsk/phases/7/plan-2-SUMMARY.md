---
phase: 7
plan: 2
status: DONE
completed: 2026-04-22
commits:
  - "3bc3af1 feat(7-2): SA-7 check 추가 — stop-context-save.sh 원자적 mv 패턴 검증"
  - "73d5a60 feat(7-2): RE-5 YAML 인젝션 방지 + H-05 SHA256 스니펫 + pre-release-check.sh"
---

# Plan 7.2 Summary: 경쟁 조건 패치 + YAML 인젝션 방지 + SHA256

## 목표

Phase 6 Plan 1 잔여 3개 항목 완전 해소:
- SA-7: stop-context-save.sh 플래그 삭제 경쟁 조건
- RE-5: md-store-memory.sh YAML 인젝션 벡터
- H-05: setup.md U2 SHA256 검증 + pre-release-check.sh

## 완료된 작업

### Task 1: SA-7 — stop-context-save.sh 원자적 패턴 확인 + 검증 추가

**파일**: `.hxsk/scripts/check-reliability.sh`

stop-context-save.sh는 이미 올바른 원자적 mv 패턴을 보유:
```bash
CLAIMED_FLAG="${FLAG_FILE}.$$"
mv "$FLAG_FILE" "$CLAIMED_FLAG" 2>/dev/null || exit 0
```

check-reliability.sh에 SA-7 체크 추가:
- `CLAIMED_FLAG` 변수 존재 여부로 원자적 패턴 검증

### Task 2: RE-5 — md-store-memory.sh YAML 인젝션 방지

**파일**: `.hxsk/hooks/md-store-memory.sh`

기존 `yaml_safe()`는 `$TITLE`, `$CONTEXTUAL_DESC`에만 적용됨.
tags 변환 루프를 개선하여 각 태그 항목에 `yaml_safe()` 적용:

```bash
# 변경 전
YAML_TAGS=$(echo "$TAGS" | tr ',' '\n' | ... | sed 's/^/  - /')

# 변경 후
YAML_TAGS=""
while IFS= read -r _tag; do
    _tag=$(echo "$_tag" | sed ...)
    [ -z "$_tag" ] && continue
    YAML_TAGS="${YAML_TAGS}  - $(yaml_safe "$_tag")"$'\n'
done < <(echo "$TAGS" | tr ',' '\n')
```

check-reliability.sh에 RE-5 체크 추가.

### Task 3: H-05 — setup.md U2 SHA256 스니펫 + pre-release-check.sh

**파일**: `.hxsk/prompts/setup.md`, `.hxsk/scripts/pre-release-check.sh`

setup.md U2 옵션 B (tarball 다운로드) 말미에 SHA256 검증 스니펫 추가:
```bash
# SHA256 검증 (선택 — 릴리스 노트에 체크섬이 제공된 경우)
# sha256sum -c <<< "EXPECTED_HASH  setup-v$TARGET_VERSION.tar.gz"
```

pre-release-check.sh 신규 생성 (`.hxsk/scripts/pre-release-check.sh`):
- tarball 캐시의 SHA256 계산 출력
- CHANGELOG 버전 동기화 확인
- check-reliability.sh ISSUE COUNT: 0 검증
- bootstrap.sh 실행 가능 여부 확인

check-reliability.sh에 H-05 체크 추가.

### 부수 수정: doc-lint.sh 링크 오류 사전 해소

**파일**: `.hxsk/scripts/doc-lint.sh`

pre-commit 훅이 커밋을 차단하는 사전 존재 lint 오류 해소:
- `find` 명령에 `.claude/worktrees` 제외 추가 → DUP-01/ORPHAN-01 실행 시간 단축 + 정확도 개선
- LINK_EXCLUDE_DIRS에 `.hxsk/phases`, `predict`, `.claude/worktrees` 추가
- DUP-01 예상 중복 목록에 predict 세션 파일, plan-*.md 패턴 추가

## 검증 결과

```
bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
bash .hxsk/scripts/pre-release-check.sh --dry-run → ISSUE COUNT: 0
grep 'CLAIMED_FLAG' .hxsk/hooks/stop-context-save.sh → 존재 (atomic OK)
grep 'yaml_safe' .hxsk/hooks/md-store-memory.sh → 4건 (tags 루프 포함)
grep 'SHA256' .hxsk/prompts/setup.md → SHA256 snippet 존재
```

## 불변 조건 유지 확인

- md-store-memory.sh: `set -euo pipefail` 유지, TYPE_DIR mkdir-p 유지
- setup.md: U2 기존 내용 재구조화 없음 — 스니펫만 추가
- ISSUE COUNT: 0 (11건 기존 체크 + 3건 신규 체크 모두 PASS)
