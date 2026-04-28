---
phase: 11
plan: "2B"
wave: 2
depends_on: ["11/plan-1A"]
files_modified:
  - .hxsk/ground-truth/sources.yaml
  - .hxsk/.purge-log.tsv
  - .hxsk/hooks/md-store-memory.sh
  - .hxsk/hooks/md-recall-memory.sh
  - .hxsk/skills/cleanse-memory/SKILL.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "sources.yaml에 4종 GT 타입(docs/file/repo/api)의 시드 예시가 포함된다"
    - ".purge-log.tsv가 헤더(deleted_at|memory_id|reason|gt_source|original_summary|hitl_decision) 행을 가진 빈 파일로 초기화된다"
    - "md-store-memory.sh가 HXSK_CONTRADICTION_CHECK=1 환경변수 감지 시 contradiction check를 실행한다"
    - "md-recall-memory.sh가 contradicted_by 비어있지 않은 항목을 후순위로 처리하고 authority 높은 항목을 우선한다"
    - "cleanse-memory 스킬이 /cleanse <gt-source-id> 명령 형식을 지원한다"
  artifacts:
    - "test -f .hxsk/ground-truth/sources.yaml"
    - "head -1 .hxsk/.purge-log.tsv | grep 'deleted_at'"
    - "grep -c 'CONTRADICTION_CHECK' .hxsk/hooks/md-store-memory.sh | grep -v '^0$'"
    - "grep -c 'contradicted_by' .hxsk/hooks/md-recall-memory.sh | grep -v '^0$'"
  key_links:
    - "md-store-memory.sh → scope-bounded recall(≤5) → 인라인 contradiction 판단 → HITL 어댑터 → 삭제 또는 저장"
    - "cleanse-memory → sources.yaml scope → recall → diff → HITL → 삭제 + purge-log append"
    - "purge-log.tsv는 git 추적 대상 (gitignore 아님)"

cross_phase_invariants:
  inherit:
    - "HITL 어댑터 규약: exit 0=응답, 1=skip, 2=timeout. stdout은 선택값 문자열"
    - "term-definition 스키마: canonical + context 조합이 고유 키 (중복 등록 시 충돌)"
    - "base.schema.json 수정 시 additionalProperties: true 유지 (기존 메모리 하위 호환)"
    - "GLOSSARY.md는 자동 생성 파일 — 직접 편집 금지, glossary-rebuild.sh로만 갱신"
    - ".glossary-candidates.tsv / .glossary-pending.tsv는 gitignore 대상 (세션 런타임 파일)"
    - "자동 학습은 aliases 추가만 허용 — canonical/context 변경은 항상 HITL"
  new:
    - "purge-log.tsv는 영구 git 추적 — 삭제된 메모리의 audit trail 보존"
    - "contradiction check는 scope-bounded ≤5 recall만 사용 (컨텍스트 비용 최소화)"
    - "HXSK_CONTRADICTION_CHECK=0 환경변수로 check 완전 우회 가능"
    - "GT authority: high > medium > low. recall 정렬 시 authority 가중치 적용"
---

# Plan 11.2B: ADR-007 — 메모리 오염 정화 (GT Alignment + cleanse-memory skill)

<objective>
ADR-007 메모리 오염 정화 시스템의 애플리케이션 레이어를 구현한다.
Ground Truth 소스 카탈로그를 초기화하고, 신규 메모리 저장 시 자동 contradiction check,
명시 정화 명령(/cleanse), 그리고 audit log 구조를 구축한다.

Purpose: 오염 메모리가 검색에서 우선 노출되거나 신규 저장을 통해 전염되는 것을 차단한다.
Output: sources.yaml + purge-log.tsv + md-store-memory.sh 확장 + md-recall-memory.sh 확장 + cleanse-memory 스킬.
</objective>

---

## Task 1: GT 카탈로그 + md-store-memory.sh contradiction check

<files>
- .hxsk/ground-truth/sources.yaml     (신규)
- .hxsk/.purge-log.tsv                (신규)
- .hxsk/hooks/md-store-memory.sh      (수정)
</files>

<action>
**ground-truth/ 디렉토리 + sources.yaml 생성**:
```yaml
# .hxsk/ground-truth/sources.yaml
# GT 소스 카탈로그. 4종 타입: docs | file | repo | api
# authority: high | medium | low
# scope: 이 GT가 적용되는 태그·디렉토리·심볼 목록
version: "1.0"
sources:
  - id: hxsk-spec
    type: file
    path: .hxsk/SPEC.md
    authority: high
    scope: [hxsk, workflow, gates, memory]
    description: "HXSK 프로젝트 공식 스펙"

  - id: hxsk-agents-md
    type: file
    path: AGENTS.md
    authority: high
    scope: [agent-boundaries, iron-laws, workflow]
    description: "에이전트 경계·Iron Law·워크플로우 규칙"

  - id: anthropic-sdk-docs
    type: docs
    url: ""            # 사용자가 등록 시 채움
    authority: high
    scope: [Agent, tool_use, messages, anthropic-sdk]
    description: "Anthropic SDK 공식 문서 (URL은 /define-gt 시 입력)"

  - id: hxsk-repo
    type: repo
    path: .
    authority: medium
    scope: [skills, agents, hooks, scripts]
    description: "Hexoskeleton 로컬 레포지토리"
```

의심스러운 등록 기준 (HITL 재질문 트리거):
- `url` 필드가 비어 있는 docs 타입
- `scope` 필드가 빈 배열
- 동일 id가 이미 존재

**purge-log.tsv 초기화**:
헤더 행만 있는 빈 파일 생성 (git 추적 대상):
```
deleted_at	memory_id	reason	gt_source	original_summary	hitl_decision
```

**.hxsk/hooks/md-store-memory.sh 수정** (기존 파일 읽은 후 수정):
파일 끝 또는 적절한 위치에 contradiction check 블록 추가:
```bash
# Contradiction Check (ADR-007)
if [[ "${HXSK_CONTRADICTION_CHECK:-1}" == "1" ]]; then
  # 신규 메모리의 tags/scope와 겹치는 기존 메모리 ≤5개 recall
  # md-recall-memory.sh 호출 (scope-bounded: tags 첫 번째 값 쿼리)
  EXISTING=$(bash "$(dirname "$0")/md-recall-memory.sh" "$TAGS" "." 5 compact 1 2>/dev/null || true)
  if [[ -n "$EXISTING" ]]; then
    # Claude(인라인)에게 contradiction 판단 요청 신호 출력
    # Claude가 다음 턴에 비교 후 HITL 처리
    echo "[CONTRADICTION_CHECK] scope=$TAGS existing_count=$(echo "$EXISTING" | wc -l)" >&2
    echo "$EXISTING" >&2
  fi
fi
```

AVOID: md-store-memory.sh의 기존 저장 로직 변경 금지 — check 블록은 부가 로직으로 append.
AVOID: contradiction check가 저장을 자동 차단하게 만들지 말 것 — 신호 출력만, 차단은 Claude(HITL)가 담당.
AVOID: python3 의존 금지.
</action>

<verify>
test -f .hxsk/ground-truth/sources.yaml && cat .hxsk/ground-truth/sources.yaml | python3 -c "import sys; import yaml; yaml.safe_load(sys.stdin); print('valid YAML')" 2>/dev/null || grep -c "id:" .hxsk/ground-truth/sources.yaml
head -1 .hxsk/.purge-log.tsv | grep "deleted_at"
HXSK_CONTRADICTION_CHECK=1 bash .hxsk/hooks/md-store-memory.sh --help 2>&1 || grep "CONTRADICTION_CHECK" .hxsk/hooks/md-store-memory.sh
</verify>

<done>
- sources.yaml: 4개 소스 항목, 4종 타입 각 1개 이상 예시 포함
- purge-log.tsv: 헤더 행 존재 (deleted_at 컬럼 확인)
- md-store-memory.sh: "CONTRADICTION_CHECK" 문자열 grep 성공
</done>

---

## Task 2: md-recall-memory.sh 우선순위 확장 + cleanse-memory 스킬

<files>
- .hxsk/hooks/md-recall-memory.sh        (수정)
- .hxsk/skills/cleanse-memory/SKILL.md   (신규)
</files>

<action>
**md-recall-memory.sh 수정** (기존 파일 읽은 후 수정):
기존 정렬 로직(`sort -r`) 이후에 provenance 우선순위 필터 추가:
1. `contradicted_by` 필드에 값이 있는 파일은 결과 후순위 이동 (정렬 후 tail로 이동)
2. `authority: high` 메모리는 결과 앞순위 (grep으로 authority 값 추출 후 재정렬)
구현: 기존 RESULTS 변수를 가공하는 post-process 블록으로 추가.

```bash
# ADR-007: Provenance 우선순위 후처리
# contradicted_by 비어있지 않은 항목을 후순위로
if [[ -n "$RESULTS" ]]; then
  CLEAN=$(echo "$RESULTS" | while read -r f; do
    grep -q "contradicted_by: \[\]" "$f" 2>/dev/null || ! grep -q "contradicted_by:" "$f" 2>/dev/null && echo "$f"
  done)
  CONTAMINATED=$(echo "$RESULTS" | while read -r f; do
    grep -q "contradicted_by:" "$f" 2>/dev/null && ! grep -q "contradicted_by: \[\]" "$f" 2>/dev/null && echo "$f"
  done)
  RESULTS=$(printf "%s\n%s" "$CLEAN" "$CONTAMINATED" | grep -v "^$" | head -"$LIMIT")
fi
```

AVOID: 기존 compact/full 출력 로직 변경 금지 — 후처리 블록만 추가.
AVOID: RESULTS 빈 경우 에러 처리 누락 금지 (|| true 패턴 유지).

**cleanse-memory/SKILL.md 작성** (≤200줄):
Quick Reference (5줄):
```
Use when: GT 소스 대비 메모리 오염 의심 시, /cleanse <gt-id> 또는 /cleanse --all
트리거: 사용자 명시 호출만 (자동 sweep 없음)
삭제 정책: HITL 확정 후 영구 삭제 + .purge-log.tsv append
우회: HXSK_CONTRADICTION_CHECK=0 으로 신규 저장 시 check 비활성화
audit: .purge-log.tsv (git 추적) + git history 로 삭제 이력 복구 가능
```

처리 흐름 명세:
1. `sources.yaml`에서 `<gt-id>` scope 로드
2. scope 태그로 `.hxsk/memories/**/*.md` 검색 (≤20개 제한)
3. 각 메모리 파일과 GT 사실 비교 (인라인 Claude 판단):
   - 일치: 패스
   - 모순 의심: HITL → `[삭제 / 보관(scope 분리) / GT가 오류 / Skip]`
4. 삭제 결정 시:
   - 파일 삭제 (`rm`)
   - `.purge-log.tsv`에 행 append (original_summary ≤200자)
   - 관련 메모리의 `contradicted_by` 필드 갱신
5. 정화 보고서 출력:
   - 검사 N건, 삭제 M건, 보관 K건, 토큰 추정 ~X input / ~Y output

AVOID: GT URL이 비어있는 docs 타입에 대해 자동 fetch 금지 — URL 없으면 HITL로 재질문.
AVOID: scope 외 메모리 삭제 금지 — scope 경계 엄격 준수.
AVOID: purge-log.tsv를 gitignore 대상으로 만들지 말 것 (audit trail은 git 추적 필수).
</action>

<verify>
grep -c "contradicted_by" .hxsk/hooks/md-recall-memory.sh
test -f .hxsk/skills/cleanse-memory/SKILL.md && wc -l .hxsk/skills/cleanse-memory/SKILL.md
grep -c "purge-log\|gt-id\|HITL" .hxsk/skills/cleanse-memory/SKILL.md
</verify>

<done>
- md-recall-memory.sh: "contradicted_by" grep 성공 + 기존 compact/full 출력 정상 동작
- cleanse-memory/SKILL.md: 존재 + ≤200줄 + purge-log/HITL/gt-id 관련 문자열 포함
- .purge-log.tsv: gitignore 미포함 확인 (`grep purge-log .gitignore` → 0 건)
</done>
