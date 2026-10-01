---
name: define-term
description: "Registers and merges project glossary terms stored as term-definition memories under .hxsk/memories/term-definition/, with human confirmation on conflicts. Use when a domain term needs a canonical definition or the user invokes /define (용어 정의, 용어 등록)."
---

# define-term

Use when: 새 용어 등록(/define <term>) 또는 두 정의 병합(/define merge a b).

## Quick Reference
- **충돌 정책**: canonical+context 중복 시 HITL 차단 → alias 추가 또는 신규 context 지정
- **변경 정책**: aliases 추가만 HITL 1회 확인으로 반영. canonical/context 변경은 항상 HITL
- **조회**: `.hxsk/memories/term-definition/` 를 Grep (canonical, aliases) — 별도 인덱스 없음
- **저장 위치**: `.hxsk/memories/term-definition/YYYY-MM-DD_{term}-{context}.md`

---

## Mode: register `<term>`

**트리거**: 사용자가 `/define <term>` 호출, 또는 대화 중 정의가 필요한 용어가 반복될 때 등록을 제안.

**절차**:
1. `Grep(pattern: "<term>", path: ".hxsk/memories/term-definition/", -i: true)` → canonical/aliases 중복 검사
   - 중복 발견 → **HITL 차단**: "기존 `{X}({context})`와 동일 의미인가?"
     - 동일 → 기존 파일 aliases에 추가 + `learned: false` 유지
     - 다름 → 새 context 지정 (다음 단계)
     - Skip → 중단
2. HITL로 수집:
   - canonical (정규 용어명)
   - context (hxsk | domain | library | custom)
   - aliases (쉼표 구분, 0개 가능)
   - definition (1-3줄)
3. 의심 등록 조건 재질문: aliases가 이미 알려진 canonical과 동일한 경우
4. 파일 저장: `YYYY-MM-DD_{canonical}-{context}.md` (소문자, 공백→하이픈)

---

## Mode: merge `<term-a>` `<term-b>`

**트리거**: `/define merge a b` — 두 term-definition 파일이 사실상 동일 의미로 판단될 때.

**절차**:
1. 두 파일 내용 표시
2. HITL: "어느 canonical을 정규형으로 유지?" + "나머지는 alias로 흡수"
3. 확정 후:
   - 선택된 canonical 파일에 나머지 aliases 병합
   - 나머지 파일 삭제 (`rm`)
   - `related` 필드에 병합 이력 기록

---

## 파일 네이밍 규칙

```
.hxsk/memories/term-definition/{YYYY-MM-DD}_{canonical-lowercase}-{context}.md
예: 2026-04-28_agent-hxsk.md
    2026-04-28_commit-git.md
    2026-04-28_plan-domain.md
```

중복 날짜 시 suffix 추가: `_agent-hxsk-2.md`

---

## Iron Laws
- aliases 외 자동 변경 금지
- 충돌 시 항상 HITL — 자동 해소 없음
- purge-log.tsv 대상 아님 (삭제는 merge 모드만, cleanse-memory 스킬이 오염 정화 담당)
