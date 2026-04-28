---
phase: 11
plan: "1A"
wave: 1
depends_on: []
files_modified:
  - .hxsk/memories/_schema/term-definition.schema.json
  - .hxsk/memories/_schema/base.schema.json
  - .hxsk/memories/_schema/type-relations.yaml
  - .hxsk/adapters/hitl/_detect.sh
  - .hxsk/adapters/hitl/claude-code.sh
  - .hxsk/adapters/hitl/opencode.sh
  - .hxsk/adapters/hitl/antigravity.sh
  - .hxsk/scripts/hitl-ask.sh
autonomous: true
user_setup: []

must_haves:
  truths:
    - "term-definition.schema.json이 canonical/context/aliases/disambiguates_from/learned/provenance 필드를 정의한다"
    - "base.schema.json에 provenance 선택 필드(source/authority/derived_at/verified_at/contradicted_by)가 추가된다"
    - "type-relations.yaml에 term-definition 타입이 15번째로 추가된다"
    - "hitl-ask.sh가 하네스 감지 후 적절한 어댑터를 호출하고 stdout으로 사용자 응답을 반환한다"
    - "모든 어댑터가 exit 0(응답), 1(skip), 2(timeout) 규약을 준수한다"
  artifacts:
    - ".hxsk/memories/_schema/term-definition.schema.json 파일 존재"
    - "bash .hxsk/scripts/hitl-ask.sh 'term=Test' 'question=테스트' 'options=A|B|Skip' 실행 시 exit 0-2 반환"
    - "cat .hxsk/memories/_schema/type-relations.yaml | grep term-definition"
  key_links:
    - "hitl-ask.sh → _detect.sh → {claude-code|opencode|antigravity}.sh 라우팅"
    - "base.schema.json provenance.authority는 enum: [high, medium, low]"

cross_phase_invariants:
  inherit: []
  new:
    - "HITL 어댑터 규약: exit 0=응답, 1=skip, 2=timeout. stdout은 선택값 문자열"
    - "term-definition 스키마: canonical + context 조합이 고유 키 (중복 등록 시 충돌)"
    - "base.schema.json 수정 시 additionalProperties: true 유지 (기존 메모리 하위 호환)"
---

# Plan 11.1A: 공유 인프라 — 스키마 확장 + HITL 어댑터

<objective>
ADR-006(조작적 정의)과 ADR-007(오염 정화) 두 시스템이 공유하는 인프라를 먼저 구축한다.
메모리 스키마에 term-definition 타입과 provenance 필드를 추가하고,
하네스 비종속 HITL 어댑터 패턴을 구현한다.

Purpose: Wave 2 두 plan(2A, 2B)이 이 인프라에 의존한다. Wave 1 완료 없이 Wave 2 진입 불가.
Output: 스키마 3종 갱신 + 어댑터 4종 + hitl-ask.sh 라우터.
</objective>

---

## Task 1: 메모리 스키마 확장

<files>
- .hxsk/memories/_schema/term-definition.schema.json  (신규)
- .hxsk/memories/_schema/base.schema.json             (수정)
- .hxsk/memories/_schema/type-relations.yaml          (수정)
</files>

<action>
**term-definition.schema.json 신규 작성**:
base.schema.json을 $ref로 상속. 추가 required: [canonical, context, definition].
필드:
- canonical: string (정규 용어명, maxLength: 100)
- context: string (추천: hxsk|domain|library, 자유 문자열)
- aliases: array of string (동의어·이형, minItems: 0)
- disambiguates_from: array of {canonical: string, context: string} (동음이의 명시)
- definition: string (1-3줄 정의, maxLength: 500)
- examples: array of string (사용 예, 선택)
- sources: array of string (출처 파일·URL, 선택)
- learned: boolean (default: false. 자동 학습된 항목이면 true)
- provenance: 아래 base 필드와 동일 구조 재사용

**base.schema.json 수정**:
기존 파일 읽고 properties에 provenance 선택 객체 추가:
```
provenance:
  type: object
  properties:
    source: {type: string}
    authority: {type: string, enum: [high, medium, low]}
    derived_at: {type: string, format: date}
    verified_at: {type: string, format: date}
    contradicted_by: {type: array, items: {type: string}}
  required: []
```
additionalProperties: true 반드시 유지 (기존 14타입 하위 호환).

**type-relations.yaml 수정**:
기존 파일 읽고 types 섹션에 term-definition 추가:
```yaml
term-definition:
  description: "조작적 정의 — 용어 SSOT (canonical/context/aliases)"
  primary_tags: [glossary, term, definition]
  relations:
    informs: [pattern-discovery, architecture-decision]
    validated_by: [session-summary]
```
types 총 15개로 업데이트 (헤더 주석 있으면 함께 갱신).

AVOID: $schema URL 변경 금지 (기존 "https://json-schema.org/draft/2020-12/schema" 유지).
AVOID: 기존 14개 타입의 enum 제거 또는 순서 변경 금지.
</action>

<verify>
grep -c "term-definition" .hxsk/memories/_schema/type-relations.yaml
grep "provenance" .hxsk/memories/_schema/base.schema.json
cat .hxsk/memories/_schema/term-definition.schema.json | python3 -c "import sys,json; json.load(sys.stdin); print('valid JSON')"
</verify>

<done>
- term-definition.schema.json: 유효한 JSON, canonical/context/definition required
- base.schema.json: provenance 블록 존재, additionalProperties: true 유지
- type-relations.yaml: term-definition 항목 존재 (grep 1 이상)
</done>

---

## Task 2: HITL 어댑터 + 라우터

<files>
- .hxsk/adapters/hitl/_detect.sh      (신규)
- .hxsk/adapters/hitl/claude-code.sh  (신규)
- .hxsk/adapters/hitl/opencode.sh     (신규)
- .hxsk/adapters/hitl/antigravity.sh  (신규)
- .hxsk/scripts/hitl-ask.sh           (신규)
</files>

<action>
**디렉토리**: .hxsk/adapters/hitl/ 생성. 이미 .hxsk/adapters/가 존재하므로 하위 디렉토리만 추가.

**_detect.sh**: 환경변수·파일 존재 기반 하네스 감지.
감지 순서: HXSK_HARNESS 환경변수 → CLAUDE_DESKTOP_APP → .opencode 존재 → antigravity → default(claude-code).
stdout: "claude-code" | "opencode" | "antigravity"

**claude-code.sh**: Claude Code HITL 어댑터.
Claude Code에서 bash 훅은 동기적으로 사용자 응답을 받을 수 없으므로:
1. .hxsk/.hitl-pending.json에 질문 기록 (term, question, options, timestamp)
2. exit 0으로 리턴 (Claude가 다음 턴에 AskUserQuestion으로 처리)
stdout: "pending" (Claude가 다음 턴에 응답 처리함을 알림)

**opencode.sh / antigravity.sh**: stdout 프롬프트 출력 + read로 stdin 대기.
```
echo "❓ HITL: $QUESTION"
echo "   옵션: $OPTIONS"
printf "선택 > "; read -r answer
echo "$answer"
```
exit 0으로 리턴.

**hitl-ask.sh**: 라우터. 인터페이스:
```bash
# 사용법
bash .hxsk/scripts/hitl-ask.sh "term=X" "question=Y?" "options=A|B|Skip"
```
1. _detect.sh 호출 → 하네스 판별
2. 해당 어댑터에 TERM/QUESTION/OPTIONS 환경변수로 전달 후 실행
3. 어댑터 exit code·stdout을 그대로 propagate

모든 스크립트 첫 줄: #!/usr/bin/env bash + set -euo pipefail.
AVOID: 하드코딩된 하네스명 hitl-ask.sh 내부에 직접 분기 금지 (_detect.sh 위임 필수).
AVOID: stdin 대기 로직을 claude-code.sh에 넣으면 훅 타임아웃 발생 — pending 파일 방식 유지.
</action>

<verify>
bash .hxsk/scripts/hitl-ask.sh --help 2>&1 || bash .hxsk/scripts/hitl-ask.sh "term=Test" "question=테스트?" "options=A|B|Skip"; echo "exit: $?"
bash .hxsk/adapters/hitl/_detect.sh
shellcheck .hxsk/scripts/hitl-ask.sh .hxsk/adapters/hitl/_detect.sh 2>/dev/null || echo "shellcheck not installed"
</verify>

<done>
- hitl-ask.sh 실행 시 exit 0-2 중 하나로 종료
- _detect.sh가 "claude-code" | "opencode" | "antigravity" 중 하나를 stdout으로 출력
- 4개 어댑터 파일 모두 존재 + 실행 권한 (+x)
</done>
