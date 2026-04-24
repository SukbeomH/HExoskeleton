---
phase: 2
plan: R1
wave: 1
depends_on: []
files_modified:
  - .hxsk/scripts/bench-recall.sh
  - .hxsk/research/benchmark/2026-04-24-recall-benchmark.md
autonomous: true
user_setup: []

must_haves:
  truths:
    - "md-recall-memory.sh hop=1 vs hop=2 레이턴시 수치 존재"
    - "각 쿼리 top-1 결과 파일명 기록"
    - "2-hop이 정확도를 향상시키는지 yes/no 판정"
  artifacts:
    - .hxsk/scripts/bench-recall.sh
    - .hxsk/research/benchmark/2026-04-24-recall-benchmark.md

cross_phase_invariants:
  inherit: []
  new:
    - "벤치마크 스크립트는 외부 의존성 없이 순수 bash + 기존 md-recall-memory.sh만 사용"
---

# Plan 2.R1: 메모리 2-hop 검색 벤치마크

<objective>
md-recall-memory.sh의 hop=1(직접 검색) vs hop=2(related 추적) 성능을 측정하고
레이턴시·정확도 비교 결과를 기록한다.

Purpose: 2-hop 검색이 실제로 추가 컨텍스트를 제공하는지, 비용(레이턴시) 대비 효과가 있는지 판단
Output: bench-recall.sh 스크립트 + 벤치마크 결과 리포트
</objective>

<context>
Load for context:
- .hxsk/hooks/md-recall-memory.sh
- .hxsk/memories/ (기존 메모리 디렉토리 구조)
- .hxsk/PATTERNS.md (Memory System 섹션)
</context>

<tasks>

<task type="auto">
  <name>벤치마크 스크립트 작성</name>
  <files>.hxsk/scripts/bench-recall.sh</files>
  <action>
    다음 구조로 스크립트를 작성한다:
    1. 5개 기준 쿼리 정의 (실제 memories에 존재하는 topic 사용):
       - "gate-check pass 서브커맨드"
       - "CSO skill description optimize"
       - "SubagentStop false positive"
       - "dispatcher worktree parallel"
       - "hallucination risk Watson"
    2. 각 쿼리를 hop=1, hop=2로 실행 — POSIX `time` 대신 `date +%s%N`으로 나노초 측정
    3. top-1 결과 파일명 추출 (첫 번째 출력 행)
    4. 결과를 TSV 형식으로 stdout 출력: query | hop | latency_ms | top1_file
    5. 스크립트 끝에 요약 출력 (total queries, avg latency hop1 vs hop2)

    AVOID: `python3` 또는 외부 바이너리 사용 — 순수 bash만 사용
    AVOID: md-recall-memory.sh 내부 수정 — 호출만 할 것
    AVOID: `set -e` 전역 설정 — grep 0건 시 abort 방지 (|| true 패드 사용)
  </action>
  <verify>bash .hxsk/scripts/bench-recall.sh | head -5 && echo "exit:$?"</verify>
  <done>
    - 스크립트가 exit 0으로 완료
    - TSV 출력에 hop=1, hop=2 행 모두 존재
    - latency_ms 값이 숫자 (0 이상)
  </done>
</task>

<task type="auto">
  <name>벤치마크 실행 + 결과 리포트 작성</name>
  <files>.hxsk/research/benchmark/2026-04-24-recall-benchmark.md</files>
  <action>
    1. `mkdir -p .hxsk/research/benchmark/` 생성
    2. `bash .hxsk/scripts/bench-recall.sh` 실행하여 결과 수집
    3. 결과를 markdown 파일로 작성:
       - ## Summary: 실행 날짜, hop=1 avg, hop=2 avg, 레이턴시 overhead(%)
       - ## Results Table: query × hop × latency_ms × top1_file
       - ## Accuracy: 각 쿼리에서 top1 결과가 기대 토픽과 관련 있는지 수동 판정 (yes/no)
       - ## Findings: 2-hop 권장 여부 결론 (비용 vs 정확도)
       - ## Recommendation: hop=1/2 기본값 적합성 판단

    AVOID: 결과 없이 임의 수치 작성 — 실제 스크립트 출력 기반으로만 작성
  </action>
  <verify>grep -q "## Summary\|## Results\|## Findings" .hxsk/research/benchmark/2026-04-24-recall-benchmark.md</verify>
  <done>
    - 결과 파일에 Summary / Results Table / Findings 섹션 완비
    - hop=1 vs hop=2 레이턴시 비교 수치 기록
    - 2-hop 권장 여부 결론 명시
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] bench-recall.sh exits 0
- [ ] 결과 리포트에 hop=1/hop=2 비교 수치 존재
- [ ] 2-hop 권장 여부 결론 명시
</verification>

<success_criteria>
- [ ] 모든 태스크 검증 통과
- [ ] must-haves 충족: 레이턴시 수치, top-1 파일, 판정
</success_criteria>
