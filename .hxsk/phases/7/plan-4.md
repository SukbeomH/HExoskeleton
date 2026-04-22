---
phase: 7
plan: 4
wave: 2
depends_on: [7.1]
files_modified:
  - .hxsk/scripts/install-hooks.sh
autonomous: true
user_setup: []

must_haves:
  truths:
    - "install-hooks.sh --merge 실행 시 기존 커스텀 훅을 보존하면서 HXSK 훅을 추가한다"
    - "install-hooks.sh --harness claude-code 실행 시 settings.json 전체가 올바른 JSON으로 생성된다"
    - "install-hooks.sh가 없어도 기존 setup.md Step 6 방식이 여전히 유효하다"
  artifacts:
    - ".hxsk/scripts/install-hooks.sh 생성"
  key_links:
    - "install-hooks.sh → .claude/settings.json 병합 또는 신규 생성"

cross_phase_invariants:
  inherit:
    - "setup.md Step 0은 CORRUPTED 분기로 진입"
    - "setup.md U6은 명시적 스테이징만 사용"
    - "bootstrap.sh는 .hxsk/logs/에 실행 로그 저장"
    - "setup.md 필수 3단계(Step 1·4·6)와 선택 6단계가 레이블로 분리"
    - "setup.md Step 4는 symlink 실패 시 cp -r 폴백"
    - "setup.md Step 9는 Tier 1·2·3 구분 명시"
  new:
    - "install-hooks.sh --merge는 기존 커스텀 훅을 보존한다"
    - "install-hooks.sh로 생성된 settings.json은 항상 유효한 JSON이다"
---

# Plan 7.4: install-hooks.sh — Step 6 자동화 스크립트

<objective>
Finding 2(Step 6 JSON 수동 편집)의 핵심 해결책.
기존 setup.md Step 6의 172줄 JSON 복사를 대체하는 자동화 스크립트.
--merge 플래그로 기존 커스텀 훅 보존, 없으면 신규 생성.

Purpose: Step 6의 인지 부하 제거 — "bash .hxsk/scripts/install-hooks.sh" 한 줄로 완료
Output: .hxsk/scripts/install-hooks.sh (신규)
</objective>

<context>
Load for context:
- .claude/settings.json (현재 구조 파악)
- .hxsk/prompts/setup.md Step 6 (현재 JSON 블록)
- predict/260422-1407-deploy-research/findings.md (Finding 2)
</context>

<tasks>

<task type="auto">
  <name>install-hooks.sh 생성 — --merge 지원 JSON 병합 스크립트</name>
  <files>.hxsk/scripts/install-hooks.sh</files>
  <action>
    스크립트 구조:
    ```bash
    #!/usr/bin/env bash
    set -euo pipefail

    SETTINGS=".claude/settings.json"
    MERGE=0
    for arg in "$@"; do [[ "$arg" == "--merge" ]] && MERGE=1; done

    # HXSK 훅 정의 (현재 settings.json의 hooks 섹션 그대로)
    HXSK_HOOKS=$(cat <<'HXSK_JSON'
    { ... hooks 블록 ... }
    HXSK_JSON
    )

    if [[ -f "$SETTINGS" && "$MERGE" -eq 1 ]]; then
        # 깊은 병합: 기존 hooks 유지 + HXSK hooks 추가
        # python3 -c "import json,sys; ..." 으로 병합
        python3 -c "
    import json, sys
    existing = json.load(open('$SETTINGS'))
    hxsk = json.loads(sys.argv[1])
    # hooks 키만 병합 — 나머지는 기존 유지
    existing.setdefault('hooks', {}).update(hxsk.get('hooks', {}))
    print(json.dumps(existing, indent=2, ensure_ascii=False))
    " "$HXSK_HOOKS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
        echo "[OK] 기존 settings.json에 HXSK 훅 병합 완료"
    else
        # 신규 생성 (기존 파일 백업)
        [[ -f "$SETTINGS" ]] && cp "$SETTINGS" "$SETTINGS.before-hxsk.bak"
        echo "$HXSK_HOOKS" > "$SETTINGS"
        echo "[OK] settings.json 생성 완료"
    fi

    # 검증
    python3 -c "import json; json.load(open('$SETTINGS'))" && echo "[OK] JSON 유효"
    ```

    HXSK 훅 정의는 현재 .claude/settings.json의 hooks 섹션에서 추출.
    AVOID: enabledPlugins 등 훅 외 설정 덮어쓰기 금지 — hooks 키만 병합
    AVOID: jq 의존 금지 (외부 의존성 없음 원칙) — python3 사용
  </action>
  <verify>
    bash .hxsk/scripts/install-hooks.sh --merge
    python3 -c "import json; json.load(open('.claude/settings.json'))" && echo "JSON OK"
    grep '"Stop"' .claude/settings.json
  </verify>
  <done>
    - install-hooks.sh 실행 → "JSON 유효" 출력
    - .claude/settings.json에 Stop/PreCompact 등 훅 이벤트 존재
    - --merge 시 enabledPlugins 등 기존 설정 유지
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] bash .hxsk/scripts/install-hooks.sh → "[OK] JSON 유효" 출력
- [ ] bash .hxsk/scripts/install-hooks.sh --merge → 기존 enabledPlugins 보존
- [ ] bash .hxsk/scripts/setup-verify.sh → 훅 이벤트 7개 PASS
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
</verification>

<success_criteria>
- [ ] install-hooks.sh 한 줄로 Step 6 완료 가능
- [ ] --merge 후 기존 커스텀 설정 보존 확인
- [ ] 생성된 settings.json이 유효한 JSON
</success_criteria>
