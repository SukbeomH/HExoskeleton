---
name: cleanse-memory
description: "Finds and, after human confirmation, deletes .hxsk/memories entries that contradict a Ground Truth source, within an explicitly scoped cleanup. Use only when the user explicitly asks for it (/cleanse <ground-truth> <scope-tags>, /cleanse --dry-run)."
---

# cleanse-memory Skill

## Quick Reference
- **Use when**: GT(Ground Truth) 대비 메모리 오염 의심 시 — `/cleanse <gt> <scope-tag...>`
- **트리거**: 사용자 명시 호출만 (자동 sweep 없음)
- **삭제 정책**: HITL 확정 후 영구 삭제 + `.hxsk/.purge-log.tsv` append
- **우회**: `HXSK_CONTRADICTION_CHECK=0`으로 신규 저장 시 contradiction check 비활성화
- **audit**: `.purge-log.tsv` (git 추적) + git history로 삭제 이력 복구 가능

---

## 명령 형식

```
/cleanse <gt> <scope-tag...>            # GT 기준으로 scope 태그에 해당하는 메모리만 검사
/cleanse --dry-run <gt> <scope-tag...>  # 삭제 없이 후보 목록만 출력
```

`<gt>`는 Ground Truth 문서의 프로젝트 내 경로 또는 사용자가 준 URL. `<scope-tag>`는 메모리 태그(예: `auth`, `api`).

예시: `/cleanse .hxsk/SPEC.md auth session`, `/cleanse docs/api.md api`

---

## 처리 흐름

### Step 1: GT 로드
- `<gt>`가 경로면 Read, 사용자가 준 URL이면 WebFetch로 로드
- `<gt>`가 없거나 읽을 수 없으면 → **HITL 재질문**: "GT 문서 경로/URL을 알려주세요. 없으면 Skip."
- scope 태그가 없으면 → **HITL 재질문**: "적용 범위(태그)를 지정해주세요."

### Step 2: scope 내 메모리 검색 (≤20개 제한)
```bash
bash ../memory-protocol/scripts/md-recall-memory.sh "<scope_tag>" "." 20 full 1
```
- scope 태그를 순서대로 검색하여 관련 메모리 파일 수집
- 중복 제거 후 최대 20개

### Step 3: 인라인 Claude 판단 (각 메모리 파일)
각 파일에 대해 GT 사실과 비교:
- **일치** (no conflict): 패스 → 다음 파일
- **모순 의심** (contradiction suspected): HITL → 4지 선택

HITL 선택지:
```
[D] 삭제     — 확실한 오염, 영구 삭제 + purge-log 기록
[K] 보관     — 다른 scope로 이동 또는 태그 분리 후 보존
[G] GT 오류  — 이 메모리가 맞고 GT가 오류, Skip (메모리 유지)
[S] Skip     — 판단 보류, 이번 sweep에서 제외
```

### Step 4: 삭제 확정 시 처리
```bash
# 1. 파일 삭제
rm "<memory_filepath>"

# 2. purge-log.tsv append (없으면 헤더부터 생성)
[ -f .hxsk/.purge-log.tsv ] || printf 'deleted_at\tmemory_id\treason\tgt_source\toriginal_summary\thitl_decision\n' > .hxsk/.purge-log.tsv
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "<memory_id>" "<reason>" "<gt>" "<summary_≤200chars>" "<hitl_choice>" \
  >> .hxsk/.purge-log.tsv

# 3. 관련 메모리의 contradicted_by 갱신 (있는 경우)
# related 파일 목록 조회 후 해당 파일의 contradicted_by 배열에 삭제된 파일명 추가
```

purge-log 컬럼 형식:
| 컬럼 | 설명 |
|------|------|
| deleted_at | ISO-8601 UTC |
| memory_id | 파일 basename |
| reason | 1줄 삭제 사유 (≤80자) |
| gt_source | GT 경로 또는 URL |
| original_summary | contextual_description ≤200자 |
| hitl_decision | D / K / G / S |

### Step 5: 정화 보고서 출력
```
🔍 Cleanse Report: <gt>
  검사: N건 | 삭제: M건 | 보관: K건 | Skip: S건
  purge-log: .hxsk/.purge-log.tsv (M행 추가)
```

---

## Scope 경계 규칙

- scope 외 메모리는 절대 삭제 금지
- 한 번의 sweep 은 GT 하나 기준. 여러 GT 는 각각 따로 실행

---

## 제약 조건

- 사용자가 주지 않은 URL 은 fetch 금지 — HITL로 요청
- scope 외 파일 삭제 금지 — scope 경계 위반 시 즉시 중단
- purge-log.tsv를 gitignore 대상으로 만들지 말 것 (audit trail은 git 추적 필수)
- `--dry-run` 시 실제 삭제·purge-log 기록 금지, 후보 목록과 예상 삭제 수만 출력

---

## Iron Laws

- NO CLEANSE WITHOUT GT SOURCE LOAD FIRST
- NO DELETE WITHOUT HITL CONFIRMATION FIRST
- NO PURGE-LOG SKIP ON DELETE
- NO SCOPE BOUNDARY VIOLATION

---

## 관련 파일

- `.hxsk/.purge-log.tsv` — 삭제 audit trail (git 추적)
- `../memory-protocol/scripts/md-recall-memory.sh` — 메모리 검색 (provenance 우선순위 적용)
- `../memory-protocol/scripts/md-store-memory.sh` — 저장 시 contradiction check (ADR-007)
