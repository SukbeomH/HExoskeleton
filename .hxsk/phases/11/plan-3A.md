---
phase: 11
plan: "3A"
wave: 3
depends_on: ["11/plan-1A", "11/plan-2A", "11/plan-2B"]
files_modified:
  - .hxsk/adapters/hitl/claude-code.sh
  - .hxsk/scripts/hitl-ask.sh
  - .hxsk/hooks/md-store-memory.sh
  - .hxsk/hooks/glossary-detect.sh
  - .hxsk/SPEC.md
  - .hxsk/adapters/hitl/_detect.sh
autonomous: true
user_setup: []

must_haves:
  truths:
    - "claude-code.sh의 TERM/QUESTION/OPTIONS가 JSON-safe 전처리 후 pending 파일에 기록된다"
    - "md-store-memory.sh의 EXIST_COUNT가 compact 출력의 실제 항목 수를 반영한다"
    - "glossary-detect.sh가 LC_ALL=C 환경에서도 한글 매칭을 시도할 수 있도록 UTF-8 로케일을 설정한다"
    - "SPEC.md Goals 및 Success Criteria의 메모리 타입 수가 16개로 갱신된다"
    - "_detect.sh의 CLAUDE_CODE 비표준 env var에 주석이 명시된다"
    - "hitl-ask.sh가 HXSK_PROJECT_DIR를 export하여 claude-code.sh와 변수명을 통일한다"
  artifacts:
    - "python3 -c \"import json; json.load(open('.hxsk/.hitl-pending.json'))\" # quote 포함 질문 삽입 후 파싱 성공"
    - "grep -c '^- \\\\*\\\\*' .hxsk/hooks/md-store-memory.sh | grep -v '^0$'"
    - "grep 'LC_ALL' .hxsk/hooks/glossary-detect.sh"
    - "grep '16개' .hxsk/SPEC.md | grep -c 'memory\\|메모리' | grep -v '^0$'"
    - "grep 'CLAUDE_CODE' .hxsk/adapters/hitl/_detect.sh | grep '#'"
    - "grep 'HXSK_PROJECT_DIR' .hxsk/scripts/hitl-ask.sh"

cross_phase_invariants:
  inherit:
    - "HITL 어댑터 규약: exit 0=응답, 1=skip, 2=timeout. stdout은 선택값 문자열"
    - "term-definition 스키마: canonical + context 조합이 고유 키 (중복 등록 시 충돌)"
    - "base.schema.json 수정 시 additionalProperties: true 유지 (기존 메모리 하위 호환)"
    - "GLOSSARY.md는 자동 생성 파일 — 직접 편집 금지, glossary-rebuild.sh로만 갱신"
    - ".glossary-candidates.tsv / .glossary-pending.tsv는 gitignore 대상 (세션 런타임 파일)"
    - "자동 학습은 aliases 추가만 허용 — canonical/context 변경은 항상 HITL"
    - "purge-log.tsv는 영구 git 추적 — 삭제된 메모리의 audit trail 보존"
    - "contradiction check는 scope-bounded ≤5 recall만 사용 (컨텍스트 비용 최소화)"
    - "HXSK_CONTRADICTION_CHECK=0 환경변수로 check 완전 우회 가능"
    - "GT authority: high > medium > low. contradicted_by 항목은 recall 후순위"
  new:
    - "HITL pending JSON은 반드시 JSON-safe 이스케이핑 후 기록 (특수문자 포함 질문 대응)"
    - "md-store-memory.sh contradiction check EXIST_COUNT는 compact 출력 패턴(^- **)으로 집계"
---

# Plan 11.3A: PR #160 리뷰 해소 — 보안·버그·문서 수정

<objective>
PR #160 리뷰에서 식별된 6개 항목(High 1, Medium 3, Nitpick 2)을 수정한다.
claude-code.sh JSON 인젝션 패치가 핵심이며, 나머지는 문서 정확성·로케일 안전성·코드 일관성 수정이다.
모든 수정은 기존 기능에 영향을 주지 않는 방어적 패치다.
</objective>

---

## Task 1: 보안·버그 수정 (High + Medium)

<files>
- .hxsk/adapters/hitl/claude-code.sh   (수정)
- .hxsk/scripts/hitl-ask.sh            (수정)
- .hxsk/hooks/md-store-memory.sh       (수정)
- .hxsk/hooks/glossary-detect.sh       (수정)
</files>

<action>
**claude-code.sh — JSON 이스케이핑 추가** (High 해소):
파일 상단(변수 선언 직후)에 JSON-safe 전처리 추가:
```bash
# JSON-safe 이스케이핑 (백슬래시 → \\, 쌍따옴표 → \")
json_safe() { printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
TERM_SAFE=$(json_safe "$TERM")
QUESTION_SAFE=$(json_safe "$QUESTION")
OPTIONS_SAFE=$(json_safe "$OPTIONS")
```
heredoc 내 변수 교체: `${TERM}` → `${TERM_SAFE}`, `${QUESTION}` → `${QUESTION_SAFE}`, `${OPTIONS}` → `${OPTIONS_SAFE}`.

AVOID: heredoc 구조 변경 금지 — 이스케이핑 전처리만 추가.
AVOID: python3/jq 의존 금지 — 순수 bash sed 패턴 사용.

**hitl-ask.sh — HXSK_PROJECT_DIR export 추가** (Nitpick 해소):
어댑터 실행 직전 export 블록에 추가:
```bash
export HXSK_PROJECT_DIR="${HXSK_PROJECT_DIR:-${CLAUDE_PROJECT_DIR:-.}}"
```
AVOID: 기존 export 블록 구조 변경 금지 — 한 줄 추가만.

**md-store-memory.sh — EXIST_COUNT grep 패턴 수정** (Medium 해소):
```bash
# 기존 (틀림)
EXIST_COUNT=$(echo "$EXISTING" | grep -c "^\[" 2>/dev/null || echo "?")
# 수정 (compact 출력 패턴 "- **Title**" 반영)
EXIST_COUNT=$(echo "$EXISTING" | grep -c "^- \*\*" 2>/dev/null || echo "?")
```
AVOID: contradiction check 블록의 다른 로직 변경 금지.

**glossary-detect.sh — UTF-8 로케일 설정** (Medium 해소):
`set -euo pipefail` 바로 다음 줄에 추가:
```bash
# 한글 정규식이 바이트 범위로 해석되지 않도록 UTF-8 강제
export LC_ALL=en_US.UTF-8 2>/dev/null || export LC_ALL=C.UTF-8 2>/dev/null || true
```
AVOID: locale 설정 실패 시 스크립트 중단 금지 — `|| true`로 폴백 보장.
</action>

<verify>
# JSON 인젝션 fix 검증: 쌍따옴표 포함 질문으로 pending 파일 생성 후 파싱
HXSK_HITL_QUESTION='Agent가 "Skill"을 래핑하는가?' HXSK_HITL_TERM="test" HXSK_HITL_OPTIONS="" \
  bash .hxsk/adapters/hitl/claude-code.sh && \
  python3 -c "import json; json.load(open('.hxsk/.hitl-pending.json')); print('JSON valid')"
# hitl-ask.sh export 확인
grep "HXSK_PROJECT_DIR" .hxsk/scripts/hitl-ask.sh
# EXIST_COUNT 패턴 확인
grep "grep -c" .hxsk/hooks/md-store-memory.sh | grep "EXIST_COUNT"
# 로케일 설정 확인
grep "LC_ALL" .hxsk/hooks/glossary-detect.sh
</verify>

<done>
- claude-code.sh: 쌍따옴표 포함 QUESTION으로 생성된 .hitl-pending.json이 python3 json.load() 통과
- hitl-ask.sh: "HXSK_PROJECT_DIR" grep 성공
- md-store-memory.sh: EXIST_COUNT 라인이 "^- \*\*" 패턴 사용
- glossary-detect.sh: "LC_ALL" grep 성공
</done>

---

## Task 2: 문서·Nitpick 수정

<files>
- .hxsk/SPEC.md                        (수정)
- .hxsk/adapters/hitl/_detect.sh       (수정)
</files>

<action>
**SPEC.md — 메모리 타입 수 갱신** (Medium 해소):
Goals 섹션: `14개 타입` → `16개 타입` (lessons-learned + term-definition 추가 반영)
Success Criteria: `14개 메모리 타입` → `16개 메모리 타입`
단순 수치 교체. 문장 구조 변경 금지.

**_detect.sh — CLAUDE_CODE 비표준 env var 주석** (Nitpick 해소):
```bash
# 2. Claude Desktop / Claude Code 시그니처
# NOTE: CLAUDE_CODE 는 비공식 env var — 향후 Claude Code 공식 변수 확정 시 교체 필요
if [[ -n "${CLAUDE_DESKTOP_APP:-}" ]] || [[ -n "${ANTHROPIC_API_KEY:-}" && -n "${CLAUDE_CODE:-}" ]]; then
```
AVOID: 조건 로직 변경 금지 — 주석 추가만.
</action>

<verify>
grep -c "16개" .hxsk/SPEC.md | grep -v "^0$"
grep "NOTE.*CLAUDE_CODE" .hxsk/adapters/hitl/_detect.sh
</verify>

<done>
- SPEC.md: "16개" 포함 줄이 2개 이상 (Goals + Success Criteria)
- _detect.sh: "NOTE.*CLAUDE_CODE" grep 성공
</done>
