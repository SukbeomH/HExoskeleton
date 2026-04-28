# define-term

Use when: 새 용어 등록(/define <term>), 펜딩 검토(/define review), 두 정의 병합(/define merge a b), 인덱스 재생성(/define rebuild), 또는 glossary-detect.sh가 등록 권유 메시지를 출력한 직후.

## Quick Reference
- **충돌 정책**: canonical+context 중복 시 HITL 차단 → alias 추가 또는 신규 context 지정
- **학습 정책**: aliases 추가만 자동 허용. canonical/context 변경은 항상 HITL
- **인덱스**: 모든 변경 후 `bash .hxsk/scripts/glossary-rebuild.sh` 자동 실행
- **저장 위치**: `.hxsk/memories/term-definition/YYYY-MM-DD_{term}-{context}.md`

---

## Mode: register `<term>`

**트리거**: 사용자가 `/define <term>` 또는 glossary-detect.sh의 📝 메시지 발생 시.

**절차**:
1. `.hxsk/GLOSSARY.md` 조회 → canonical+context 중복 검사
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
5. `.hxsk/.glossary-pending.tsv`에서 해당 term 항목 제거
6. `glossary-rebuild.sh` 실행

---

## Mode: review

**트리거**: `/define review` 또는 세션 종료(handoff) 시.

**절차**:
1. `.hxsk/.glossary-pending.tsv` 로드
2. count ≥ 3인 항목부터 정렬
3. 각 항목 HITL:
   - "등록", "거부(이번 세션만 무시)", "영구 Skip" 중 선택
4. 등록 선택 → register 모드로 진행
5. 처리 완료 항목은 tsv에서 제거
6. 완료 보고: "검토 N건: 등록 M, 거부 K"

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
4. `glossary-rebuild.sh` 실행

---

## Mode: rebuild

**트리거**: `/define rebuild` 또는 다른 모드 완료 후 자동 호출.

```bash
bash .hxsk/scripts/glossary-rebuild.sh
```

완료 후 "GLOSSARY rebuilt: N terms" 출력.

---

## 자동 학습 처리 (aliases only)

사용자가 alias로 3회 이상 사용한 표현 + 작업 성공 신호:
- `.hxsk/.glossary-pending.tsv`의 해당 항목 `learned: true` 플래그
- 다음 review 모드 시 HITL로 alias 추가 여부 확인
- alias 추가 승인 시 해당 파일 frontmatter의 `aliases` 배열에 append, `learned: true` 기록
- canonical/context는 자동 변경 없음 — 항상 HITL

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
- GLOSSARY.md 직접 편집 금지 — rebuild만
- aliases 외 자동 변경 금지
- 충돌 시 항상 HITL — 자동 해소 없음
- purge-log.tsv 대상 아님 (삭제는 merge 모드만, cleanse-memory 스킬이 오염 정화 담당)
