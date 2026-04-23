---
phase: 10
plan: "4A"
wave: 4
depends_on: ["10.3A"]
files_modified:
  - .hxsk/tools/skill-doc-optimizer/optimized_module.json
autonomous: true
user_setup: []

must_haves:
  truths:
    - "BootstrapFewShot이 18개 HIGH 스킬을 trainset으로 학습한다"
    - "Val score가 0.75 이상이다 (MEDIUM 4개 스킬로 평가)"
    - "optimized_module.json이 저장된다"
  artifacts:
    - ".hxsk/tools/skill-doc-optimizer/optimized_module.json 존재"
    - "Val score 수치 기록 (bootstrap 완료 출력)"
  key_links:
    - "optimized_module.json이 이후 optimize.py 실행 시 자동 로드 가능"

cross_phase_invariants:
  inherit:
    - "--apply 실행 전 반드시 dry-run 결과를 사용자가 확인 (NO APPLY WITHOUT REVIEW)"
    - "각 스킬 적용 후 /skill-testing 검증 없이 다음 스킬 진행 금지"
  new:
    - "Val score < 0.6이면 MIPROv2 전환을 사용자에게 보고 후 중단"
    - "Bootstrap 실행 시간이 30분 초과하면 trainset을 8→5개로 줄여 재시도"
---

# Plan 10.4A: BootstrapFewShot 실행 및 최적화 모듈 저장

<objective>
HIGH 18개 스킬을 few-shot 예시로 사용해 SkillDocOptimizer 모듈을 자동 최적화한다.
MEDIUM 4개 스킬(3A 적용 후)로 검증하여 Val score를 측정한다.

Purpose: 모델이 더 나은 SKILL.md를 생성하도록 프롬프트를 자동으로 개선한다.
Output: optimized_module.json + Val score ≥ 0.75.
</objective>

<context>
Load for context:
- .hxsk/tools/skill-doc-optimizer/optimize.py
- .hxsk/tools/skill-doc-optimizer/dataset.py (HIGH_QUALITY_SKILLS 목록)
</context>

<tasks>

<task type="auto">
  <name>BootstrapFewShot 실행 (27B, trainset 8개)</name>
  <files>.hxsk/tools/skill-doc-optimizer/optimized_module.json</files>
  <action>
    cd .hxsk/tools/skill-doc-optimizer && source .venv/bin/activate

    # Bootstrap 실행 (시간이 걸림 — 약 10~20분 예상)
    python3 optimize.py --bootstrap --model qwen-27b \
      2>&1 | tee /tmp/skill-opt-bootstrap-run.txt

    실행 후 확인:
    - "Bootstrap 완료" 메시지
    - "Val score: X.XXX" 출력
    - optimized_module.json 파일 생성

    AVOID: 실행 중 중단 금지 — BootstrapFewShot은 중간 저장이 없음
    AVOID: 122B로 bootstrap 실행 금지 (현재 단계) — 27B 결과를 베이스라인으로 확보 먼저
  </action>
  <verify>
    ls -la /Users/sukbeom/Desktop/Hexoskeleton/.hxsk/tools/skill-doc-optimizer/optimized_module.json
    grep "Val score" /tmp/skill-opt-bootstrap-run.txt
  </verify>
  <done>
    optimized_module.json 존재하고 크기 > 0.
    Val score ≥ 0.75 출력.

    Val score < 0.6 → checkpoint:decision (MIPROv2 전환 여부 사용자 결정)
    Val score 0.6~0.75 → 계속 진행하되 Phase 5에서 재평가
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] optimized_module.json 존재
- [ ] Val score 수치 확인
- [ ] /tmp/skill-opt-bootstrap-run.txt에 완료 로그
</verification>

<success_criteria>
- [ ] optimized_module.json 저장 완료
- [ ] Val score 기록됨 (목표 ≥ 0.75)
</success_criteria>
