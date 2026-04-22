---
phase: 7
plan: 5
wave: 3
depends_on: [7.3]
files_modified:
  - .hxsk/scripts/install.sh
  - .hxsk/scripts/hxsk-harness-sync.sh
autonomous: true
user_setup: []

must_haves:
  truths:
    - "install.sh --harness claude-code 실행 시 Claude Code 어댑터가 올바른 경로에 배치된다"
    - "install.sh --harness cursor 실행 시 .cursor/hooks.json 이 생성된다"
    - "hxsk-harness-sync.sh --check 실행 시 어댑터 버전 드리프트를 감지한다"
    - "DA-6 반영: Tier 1 (claude-code, cursor, copilot) 만으로 완전 동작"
  artifacts:
    - ".hxsk/scripts/install.sh 생성 (autoresearch scripts/install.sh 방식)"
    - ".hxsk/scripts/hxsk-harness-sync.sh 생성"

cross_phase_invariants:
  inherit:
    - "setup.md 필수 3단계(Step 1·4·6)와 선택 6단계가 레이블로 분리"
    - "setup.md Step 9는 Tier 1·2·3 구분 명시"
    - "install-hooks.sh --merge는 기존 커스텀 훅을 보존"
    - "bootstrap.sh는 .hxsk/logs/에 실행 로그 저장"
  new:
    - "install.sh는 --harness 플래그로 Tier 1 하네스(claude-code·cursor·copilot)를 완전 지원한다"
    - "install.sh는 외부 의존성 없이 순수 bash로 동작한다"
    - "hxsk-harness-sync.sh는 .hxsk/adapters/ 버전과 설치된 어댑터를 비교한다"
---

# Plan 7.5: scripts/install.sh — harness-agnostic 1-liner 설치

<objective>
Finding 8(어댑터 동기화 메커니즘 부재) + DA-6(Tier 1 집중) + H-06(범용 1-liner) 반영.
autoresearch의 scripts/install.sh 방식을 차용해 하네스별 어댑터 설치를 1-liner로 제공.
순수 bash, 외부 의존성 없음 (HXSK 설계 원칙 준수).

Purpose: 신규 사용자가 setup.md Step 9를 "bash .hxsk/scripts/install.sh --harness cursor" 한 줄로 완료
Output: install.sh + hxsk-harness-sync.sh (신규)
</objective>

<context>
Load for context:
- .hxsk/adapters/ (어댑터 파일 목록)
- .hxsk/adapters/README.md (하네스별 설치 경로)
- predict/260422-1407-deploy-research/findings.md (Finding 8)
- predict/260422-1407-deploy-research/overview.md (P2 범용 설치, DA-6)
</context>

<tasks>

<task type="auto">
  <name>install.sh 생성 — Tier 1 완전 지원 + Tier 2 부분 지원</name>
  <files>.hxsk/scripts/install.sh</files>
  <action>
    ```bash
    #!/usr/bin/env bash
    # HXSK Harness Installer — 순수 bash, 외부 의존성 없음
    set -euo pipefail

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ADAPTER_DIR="$SCRIPT_DIR/../adapters"
    HARNESS=""
    FORCE=0

    usage() { echo "Usage: $0 --harness <name> [--force]"; echo "Harnesses: claude-code cursor copilot gemini windsurf opencode codex git-hook"; }

    for arg in "$@"; do
        case "$arg" in
          --harness) shift; HARNESS="$1" ;;
          --force)   FORCE=1 ;;
          --help|-h) usage; exit 0 ;;
        esac
        shift 2>/dev/null || true
    done

    [[ -z "$HARNESS" ]] && { usage; exit 1; }

    install_harness() {
        local harness="$1"
        case "$harness" in
          claude-code)
            # Claude Code는 내장 통합 — install-hooks.sh 위임
            bash "$SCRIPT_DIR/install-hooks.sh" --merge
            echo "[OK] Claude Code: settings.json 훅 등록 완료" ;;
          cursor)
            # Tier 1
            mkdir -p .cursor
            cp "$ADAPTER_DIR/cursor-hooks.json" .cursor/hooks.json
            echo "[OK] Cursor: .cursor/hooks.json 설치 완료" ;;
          copilot)
            # Tier 1
            mkdir -p .copilot
            cp "$ADAPTER_DIR/copilot-hooks.json" .copilot/hooks.json
            echo "[OK] GitHub Copilot CLI: .copilot/hooks.json 설치 완료" ;;
          gemini)
            # Tier 2
            echo "[INFO] Gemini CLI: ~/.gemini/settings.json 또는 .gemini/settings.json 에 병합 필요"
            echo "       어댑터 위치: $ADAPTER_DIR/gemini-settings.json"
            echo "       수동 병합: cat $ADAPTER_DIR/gemini-settings.json" ;;
          windsurf)
            mkdir -p .windsurf
            cp "$ADAPTER_DIR/windsurf-hooks.json" .windsurf/hooks.json
            echo "[OK] Windsurf: .windsurf/hooks.json 설치 완료" ;;
          opencode)
            echo "[INFO] OpenCode: JS 래퍼 필요 — $ADAPTER_DIR/opencode-plugin.ts 참조" ;;
          codex)
            cp "$ADAPTER_DIR/codex-hooks.json" .codex/hooks.json 2>/dev/null || \
              { mkdir -p .codex; cp "$ADAPTER_DIR/codex-hooks.json" .codex/hooks.json; }
            echo "[OK] OpenAI Codex CLI: .codex/hooks.json 설치 완료" ;;
          git-hook)
            git config core.hooksPath .hxsk/githooks
            echo "[OK] git 훅 폴백: core.hooksPath .hxsk/githooks 설정 완료" ;;
          *) echo "[FAIL] 알 수 없는 하네스: $harness"; usage; exit 1 ;;
        esac
    }

    install_harness "$HARNESS"
    ```

    AVOID: 기존 파일 무조건 덮어쓰기 — --force 없으면 기존 파일 존재 시 경고 출력
  </action>
  <verify>
    bash .hxsk/scripts/install.sh --harness cursor
    ls .cursor/hooks.json
    bash .hxsk/scripts/install.sh --harness copilot
    ls .copilot/hooks.json
    bash .hxsk/scripts/install.sh --harness claude-code
  </verify>
  <done>
    - cursor: .cursor/hooks.json 생성
    - copilot: .copilot/hooks.json 생성
    - claude-code: settings.json 훅 등록
    - 미지원 하네스: 안내 메시지 출력 후 exit 0
  </done>
</task>

<task type="auto">
  <name>hxsk-harness-sync.sh 생성 — 어댑터 드리프트 감지</name>
  <files>.hxsk/scripts/hxsk-harness-sync.sh</files>
  <action>
    ```bash
    #!/usr/bin/env bash
    # 설치된 어댑터 파일과 .hxsk/adapters/ 원본 비교
    set -euo pipefail

    ADAPTER_DIR=".hxsk/adapters"
    MODE="${1:---check}"

    declare -A HARNESS_MAP=(
        ["cursor"]="$ADAPTER_DIR/cursor-hooks.json:.cursor/hooks.json"
        ["copilot"]="$ADAPTER_DIR/copilot-hooks.json:.copilot/hooks.json"
        ["windsurf"]="$ADAPTER_DIR/windsurf-hooks.json:.windsurf/hooks.json"
        ["codex"]="$ADAPTER_DIR/codex-hooks.json:.codex/hooks.json"
    )

    DRIFT=0
    for harness in "${!HARNESS_MAP[@]}"; do
        IFS=: read -r src dst <<< "${HARNESS_MAP[$harness]}"
        [[ ! -f "$dst" ]] && continue  # 미설치는 스킵
        if ! diff -q "$src" "$dst" >/dev/null 2>&1; then
            echo "[DRIFT] $harness: $dst 가 $src 와 다름"
            DRIFT=1
            [[ "$MODE" == "--sync" ]] && cp "$src" "$dst" && echo "  → 동기화 완료"
        else
            echo "[OK]    $harness: 최신 상태"
        fi
    done

    [[ "$DRIFT" -eq 0 ]] && echo "모든 어댑터 최신 상태" || \
        [[ "$MODE" == "--check" ]] && echo "드리프트 발견 — '--sync' 옵션으로 동기화하세요"
    ```

    AVOID: 비교 대상이 설치되지 않은 하네스는 스킵 (경고 아님)
  </action>
  <verify>
    bash .hxsk/scripts/hxsk-harness-sync.sh --check
  </verify>
  <done>
    - 설치된 어댑터에 대해 [OK] 또는 [DRIFT] 출력
    - --sync 시 자동 동기화
  </done>
</task>

</tasks>

<verification>
After all tasks, verify:
- [ ] bash .hxsk/scripts/install.sh --harness cursor → .cursor/hooks.json 생성
- [ ] bash .hxsk/scripts/install.sh --harness copilot → .copilot/hooks.json 생성
- [ ] bash .hxsk/scripts/hxsk-harness-sync.sh --check → 각 하네스 [OK]/[DRIFT] 출력
- [ ] bash .hxsk/scripts/check-reliability.sh → ISSUE COUNT: 0
</verification>

<success_criteria>
- [ ] Tier 1 하네스(claude-code·cursor·copilot) 1-liner 설치 완료
- [ ] hxsk-harness-sync.sh 드리프트 감지 동작
- [ ] 순수 bash, 외부 의존성 없음
</success_criteria>
