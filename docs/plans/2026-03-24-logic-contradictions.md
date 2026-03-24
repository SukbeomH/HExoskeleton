# 로직 모순 + 잔여 기술 부채 전체 해소 계획

> **Status:** ✅ 실행 완료 (2026-03-24)
> **Deviations:** opencode Commands count 20→19 보정 (실측 기반), T3 dispatcher.md merge 충돌 수동 해소

**Goal:** 코드베이스 분석에서 발견된 16건의 모순점과 6건의 잔여 기술 부채를 wave 기반 병렬 실행으로 전부 해소한다.

**Architecture:** 문제를 파일 소유권별로 그룹화하여 3개 wave로 분할. 각 wave 내 태스크는 서로 다른 파일을 수정하므로 `isolation: "worktree"` subagent로 병렬 실행 가능. 문서 수정(CLAUDE.md, PATTERNS.md)은 줄 수 한도를 엄수한다.

**Tech Stack:** Bash 5.x, awk, sed — 외부 종속성 없음

---

## 문제 → 태스크 매핑

```
Wave 1 (독립 — 병렬 가능, 8개):
  T1: executor.md         ← M2 (Agent 도구 미선언), M4 일부
  T2: planner.md          ← M9 (Bash 도구 미선언)
  T3: dispatcher.md       ← M10 (Agent Boundaries 미적용)
  T4: empirical-valid     ← M3 (존재하지 않는 파일/도구 참조)
  T5: build-plugin.sh     ← M4 (expected counts)
  T6: build-antigravity.sh← M4, M7 (counts, 훅 선택적 복사 문서화), M15
  T7: build-opencode.sh   ← M4 (counts)
  T8: stop-context-save.sh← M11 (pattern-discovery 죽은 코드), M16 (로그 무한증가)

Wave 2 (독립 — 병렬 가능, 4개):
  T9:  release-plugin.yml  ← M14 (CI 경로 트리거)
  T10: memory-protocol     ← M13 (미사용 type relations 정리)
  T11: scripts/ 중복 정리   ← M5 (5개 중복 스크립트 canonical 지정)
  T12: CLAUDE.md + PATTERNS ← M8 (Discovery Level 명확화), M12 (줄 수)

Wave 3 (검증):
  T13: 통합 빌드 검증 + 문서 최종 갱신
```

---

## Wave 1: 컴포넌트 수정 (8개 병렬)

### Task T1: `executor.md` — Agent 도구 선언 수정

**Addresses:** M2 (Agent 도구 미선언)
**Files:**
- Modify: `.claude/agents/executor.md:4`

**Step 1: tools에 Agent 추가**

```yaml
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent"]
```

Pattern D(병렬 wave 실행)에 `Agent(isolation: "worktree")`가 필요하므로 추가.

**Step 2: 검증**

Run: `grep 'tools:' .claude/agents/executor.md`
Expected: `tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Agent"]`

**Step 3: Commit**

```bash
git add .claude/agents/executor.md
git commit -m "fix(executor): Agent 도구 선언 추가 — Pattern D 실행 가능"
```

---

### Task T2: `planner.md` — Bash 도구 선언 수정

**Addresses:** M9 (Bash 도구 미선언)
**Files:**
- Modify: `.claude/agents/planner.md:4`

**Step 1: tools에 Bash 추가**

```yaml
tools: ["Read", "Grep", "Glob", "Bash"]
```

메모리 검색(`md-recall-memory.sh`)에 Bash가 필요하므로 추가.

**Step 2: 검증**

Run: `grep 'tools:' .claude/agents/planner.md`
Expected: `tools: ["Read", "Grep", "Glob", "Bash"]`

**Step 3: Commit**

```bash
git add .claude/agents/planner.md
git commit -m "fix(planner): Bash 도구 선언 추가 — 메모리 검색 가능"
```

---

### Task T3: `dispatcher.md` — Agent Boundaries 적용

**Addresses:** M10 (Agent Boundaries 미적용)
**Files:**
- Modify: `.claude/agents/dispatcher.md`

**Step 1: Agent Boundaries 참조 추가**

기존 `Key constraints:` 섹션 뒤에 추가:

```markdown

Agent Boundaries (CLAUDE.md 준수):
- Always: merge 전 각 worktree의 변경사항 리뷰
- Ask First: 3+ 모듈 영향 시 사용자 확인 요청
- Never: 사용자 승인 없이 master 브랜치 직접 push
```

**Step 2: 검증**

Run: `grep -c 'Ask First' .claude/agents/dispatcher.md`
Expected: `1`

**Step 3: Commit**

```bash
git add .claude/agents/dispatcher.md
git commit -m "fix(dispatcher): Agent Boundaries 프로토콜 적용"
```

---

### Task T4: `empirical-validation/SKILL.md` — 존재하지 않는 참조 제거

**Addresses:** M3 (`.gemini/GEMINI.md`, `browser_subagent`, `run_command` 참조)
**Files:**
- Modify: `.claude/skills/empirical-validation/SKILL.md`

**Step 1: Quick Reference의 도구 참조를 Claude Code 네이티브 도구로 교체**

변경 전:
```markdown
- **UI**: Screenshot으로 시각 상태 확인 (`browser_subagent`)
- **API**: `curl` 명령으로 응답 확인 (`run_command`)
- **Build/Test**: 성공 출력 캡처 (`run_command`)
```

변경 후:
```markdown
- **UI**: Screenshot으로 시각 상태 확인 (Bash: `screenshot` 또는 브라우저 MCP)
- **API**: `curl` 명령으로 응답 확인 (Bash)
- **Build/Test**: 성공 출력 캡처 (Bash)
```

**Step 2: 본문의 Validation Methods 테이블 교체**

변경 전:
```
| **UI Changes** | Screenshot showing expected visual state | `browser_subagent` |
| **API Endpoints** | Command showing correct response | `run_command` |
| **Build/Config** | Successful build or test output | `run_command` |
```

변경 후:
```
| **UI Changes** | Screenshot showing expected visual state | `Bash` (screenshot tool or browser MCP) |
| **API Endpoints** | Command showing correct response | `Bash` (curl/httpie) |
| **Build/Config** | Successful build or test output | `Bash` |
```

**Step 3: Integration 섹션의 `.gemini/GEMINI.md` 참조 제거**

변경 전:
```markdown
- `.gemini/GEMINI.md` Rule 4 (Empirical Validation) — Every change MUST be verified with empirical evidence (screenshot, command output, test result) before marking complete
```

변경 후:
```markdown
- `CLAUDE.md` Validation 섹션 — 경험적 증거 기반 검증 원칙
```

**Step 4: 검증**

Run: `grep -cE 'browser_subagent|run_command|\.gemini' .claude/skills/empirical-validation/SKILL.md`
Expected: `0`

**Step 5: Commit**

```bash
git add .claude/skills/empirical-validation/SKILL.md
git commit -m "fix(empirical-validation): 존재하지 않는 도구/파일 참조 제거"
```

---

### Task T5: `build-plugin.sh` — expected counts 갱신

**Addresses:** M4 (빌드 검증 카운트 불일치)
**Files:**
- Modify: `scripts/build-plugin.sh:629-632`

**Step 1: expected counts 수정**

```bash
verify_count "Skills" "$skill_count" 19
verify_count "Agents" "$agent_count" 17
verify_count "Scripts" "$script_count" 17
verify_count "Templates" "$template_count" 24
```

**Step 2: 빌드 검증**

Run: `make build-plugin 2>&1 | grep -E 'WARN|expected'`
Expected: WARN 없음

**Step 3: Commit**

```bash
git add scripts/build-plugin.sh
git commit -m "fix(build): plugin 빌드 expected counts 갱신 (19 skills, 17 agents, 24 templates)"
```

---

### Task T6: `build-antigravity.sh` — counts + 훅 복사 문서화

**Addresses:** M4 (counts), M7 (5/17 훅만 복사하는 이유 문서화), M15 (JSON 검증 누락)
**Files:**
- Modify: `scripts/build-antigravity.sh:493-506,720-722`

**Step 1: 훅 선택적 복사에 주석 추가 (line 493 부근)**

```bash
# Copy memory scripts + security guard scripts ONLY
# Antigravity IDE는 event hooks를 지원하지 않으므로 (rules/security-guard.md로 대체)
# 실행 가능한 유틸리티 스크립트만 복사한다 (5개: 메모리2 + 보안2 + 파서1)
```

**Step 2: expected counts 수정 (line 720-722)**

```bash
verify_count "Skills" "$skill_count" 19
verify_count "Workflows" "$workflow_count" 17
verify_count "Rules" "$rules_count" 6
```

**Step 3: JSON 검증 추가 — verification 섹션 끝에**

GEMINI.md가 JSON이 아니므로 JSON 검증 대상은 없지만, 구조 검증 주석을 추가:

```bash
# [JSON Validity] — Antigravity uses markdown rules, no JSON config files
echo ""
echo "[Content Validity]"
if [ -f "$ANTIGRAVITY/GEMINI.md" ] && [ -s "$ANTIGRAVITY/GEMINI.md" ]; then
    echo "  [OK] GEMINI.md non-empty ($(wc -c < "$ANTIGRAVITY/GEMINI.md" | tr -d ' ') chars)"
else
    echo "  [FAIL] GEMINI.md empty or missing"
    BUILD_ERRORS=$((BUILD_ERRORS + 1))
fi
```

**Step 4: 빌드 검증**

Run: `make build-antigravity 2>&1 | grep -E 'WARN|expected|Content'`
Expected: WARN 없음, `[OK] GEMINI.md`

**Step 5: Commit**

```bash
git add scripts/build-antigravity.sh
git commit -m "fix(build): antigravity counts 갱신, 훅 선택 복사 의도 문서화, 콘텐츠 검증 추가"
```

---

### Task T7: `build-opencode.sh` — expected counts 갱신

**Addresses:** M4 (빌드 검증 카운트 불일치)
**Files:**
- Modify: `scripts/build-opencode.sh:649-651`

**Step 1: expected counts 수정**

```bash
verify_count "Agents" "$agent_count" 17
verify_count "Commands" "$command_count" 20
verify_count "Skills" "$skill_count" 19
```

**Step 2: 빌드 검증**

Run: `make build-opencode 2>&1 | grep -E 'WARN|expected'`
Expected: WARN 없음

**Step 3: Commit**

```bash
git add scripts/build-opencode.sh
git commit -m "fix(build): opencode 빌드 expected counts 갱신"
```

---

### Task T8: `stop-context-save.sh` — 죽은 코드 제거 + 로그 로테이션

**Addresses:** M11 (pattern-discovery 죽은 코드), M16 (.context-save.log 무한 증가)
**Files:**
- Modify: `.claude/hooks/stop-context-save.sh`

**Step 1: pattern-discovery 스캔 코드 제거 (line 118-136)**

현재 `# ── 3. ACE Reflector` 블록 전체를 제거. 이 코드는 pattern-discovery 타입 메모리를 스캔하지만, 아무 것도 이 타입으로 저장하지 않으므로 사실상 죽은 코드.

**Step 2: .context-save.log 로테이션 추가**

백그라운드 프로세스 내, `.track-modifications.log` 삭제 직전에 추가:

```bash
    # ── 3. .context-save.log 로테이션 (1MB 초과 시) ──
    if [[ -f "$LOG_FILE" ]]; then
        LOG_SIZE=$(wc -c < "$LOG_FILE" | tr -d ' ')
        if [[ "$LOG_SIZE" -gt 1048576 ]]; then
            mv "$LOG_FILE" "${LOG_FILE%.log}-$(date '+%Y%m').log"
        fi
    fi
```

**Step 3: 검증**

Run: `bash -c 'grep -c "ACE Reflector\|pattern-discovery" .claude/hooks/stop-context-save.sh'`
Expected: `0`

Run: `grep -c 'LOG_SIZE' .claude/hooks/stop-context-save.sh`
Expected: `1`

**Step 4: Commit**

```bash
git add .claude/hooks/stop-context-save.sh
git commit -m "fix(hooks): pattern-discovery 죽은 코드 제거, context-save.log 로테이션 추가"
```

---

## Wave 2: 인프라 + 문서 정리 (4개 병렬)

### Task T9: `release-plugin.yml` — CI 경로 트리거 확대

**Addresses:** M14 (plugin 소스만 감시)
**Files:**
- Modify: `.github/workflows/release-plugin.yml:6-14`

**Step 1: paths에 누락된 경로 추가**

```yaml
    paths:
      - '.claude/**'
      - '.agent/**'
      - '.hxsk/templates/**'
      - '.hxsk/examples/**'
      - 'scripts/**'
      - 'Makefile'
      - 'CLAUDE.md'
      - 'release-please-config.json'
      - '.release-please-manifest.json'
```

기존 `scripts/build-*.sh`를 `scripts/**`로 확대하여 모든 스크립트 변경 시 빌드 트리거.

**Step 2: 검증**

Run: `grep -c 'scripts/\*\*' .github/workflows/release-plugin.yml`
Expected: `1`

**Step 3: Commit**

```bash
git add .github/workflows/release-plugin.yml
git commit -m "fix(ci): 빌드 트리거 경로 확대 — scripts/**, .hxsk/examples/** 추가"
```

---

### Task T10: `memory-protocol/SKILL.md` — 미사용 type relations 주석 처리

**Addresses:** M13 (정의됐지만 사용되지 않는 검색 체인)
**Files:**
- Modify: `.claude/skills/memory-protocol/SKILL.md`

**Step 1: type relations 섹션에 미구현 상태 명시**

해당 섹션(약 line 207-223)의 시작 부분에 추가:

```markdown
> **Note:** 아래 검색 체인은 설계 레퍼런스이며, 현재 자동 구현되지 않음.
> `md-recall-memory.sh`의 2-hop 검색은 `related` 필드 기반이며, 체인 자동 순회는 미구현.
```

**Step 2: 검증**

Run: `grep -c '설계 레퍼런스' .claude/skills/memory-protocol/SKILL.md`
Expected: `1`

**Step 3: Commit**

```bash
git add .claude/skills/memory-protocol/SKILL.md
git commit -m "docs(memory-protocol): type relations 미구현 상태 명시"
```

---

### Task T11: `scripts/` 중복 스크립트 정리 — canonical 지정

**Addresses:** M5 (5개 중복 스크립트)
**Files:**
- Modify: `scripts/_json_parse.sh`, `scripts/compact-context.sh`, `scripts/md-recall-memory.sh`, `scripts/md-store-memory.sh`, `scripts/organize-docs.sh` (5개 모두)

**Step 1: `.claude/hooks/`를 canonical로 지정**

`.claude/hooks/`가 canonical인 이유:
- 빌드 스크립트(build-plugin, antigravity, opencode)가 모두 `.claude/hooks/`에서 복사
- 훅 설정(settings.json)이 `.claude/hooks/` 경로 참조
- `scripts/`의 파일은 사실상 사용되지 않음 (CLAUDE.md에서 참조하지만 실제 호출은 hooks/)

각 `scripts/` 파일을 1줄 래퍼로 교체:

```bash
#!/usr/bin/env bash
# Canonical location: .claude/hooks/$(basename "$0")
# This wrapper delegates to the canonical copy.
exec "$(cd "$(dirname "$0")/../.claude/hooks" && pwd)/$(basename "$0")" "$@"
```

**Step 2: 5개 파일 모두 래퍼로 교체**

각 파일에 대해 동일한 패턴:
- `scripts/_json_parse.sh` → `.claude/hooks/_json_parse.sh`로 위임
- `scripts/compact-context.sh` → `.claude/hooks/compact-context.sh`로 위임
- `scripts/md-recall-memory.sh` → `.claude/hooks/md-recall-memory.sh`로 위임
- `scripts/md-store-memory.sh` → `.claude/hooks/md-store-memory.sh`로 위임
- `scripts/organize-docs.sh` → `.claude/hooks/organize-docs.sh`로 위임

**Step 3: 검증**

Run: `bash scripts/md-recall-memory.sh --help 2>&1 | head -1`
Expected: 에러가 아닌 정상 출력 (래퍼가 canonical로 위임)

**Step 4: Commit**

```bash
git add scripts/_json_parse.sh scripts/compact-context.sh scripts/md-recall-memory.sh scripts/md-store-memory.sh scripts/organize-docs.sh
git commit -m "refactor(scripts): 5개 중복 스크립트를 .claude/hooks/ canonical 위임 래퍼로 교체"
```

---

### Task T12: `CLAUDE.md` + `PATTERNS.md` — Discovery Level 명확화

**Addresses:** M8 (Discovery Level 이름 충돌), M12 (줄 수 한도)
**Files:**
- Modify: `CLAUDE.md`
- Modify: `.hxsk/PATTERNS.md`

**Step 1: CLAUDE.md Discovery Level 용어 명확화**

현재 (line 79):
```
- **Discovery Levels**: L1=CLAUDE.md (요약) → L2=skills/SKILL.md (상세) → L3=.hxsk/research/ (출처/벤치마크)
```

변경:
```
- **문서 계층**: L1=CLAUDE.md (요약) → L2=skills/SKILL.md (상세) → L3=.hxsk/research/ (출처)
```

"Discovery Levels"를 "문서 계층"으로 변경하여 planner의 "Discovery Levels"(L0-L3 연구 깊이)와 구분.

**Step 2: 줄 수 검증**

Run: `wc -l CLAUDE.md`
Expected: ≤120줄

**Step 3: PATTERNS.md에 용어 정리 패턴 추가**

Conventions 섹션에:
```
- **Discovery Level** vs **문서 계층**: Discovery Level(L0-L3)은 planner의 연구 깊이, 문서 계층(L1-L3)은 프롬프트 문서 레이어
```

items 카운트 갱신: `17/20`

**Step 4: 검증**

Run: `wc -l CLAUDE.md && wc -l .hxsk/PATTERNS.md`
Expected: CLAUDE.md ≤120, PATTERNS.md 합리적 크기

**Step 5: Commit**

```bash
git add CLAUDE.md .hxsk/PATTERNS.md
git commit -m "docs: Discovery Level vs 문서 계층 용어 명확화, PATTERNS.md 갱신"
```

---

## Wave 3: 통합 검증 (순차)

### Task T13: 전체 빌드 검증 + ARCHITECTURE.md 최종 갱신

**Files:**
- Verify: 3개 빌드 타겟
- Modify: `.hxsk/ARCHITECTURE.md`

**Step 1: 전체 빌드**

Run: `make clean && make build 2>&1 | grep -E 'WARN|FAIL|SUCCESSFUL'`
Expected: 3개 모두 `BUILD SUCCESSFUL`, WARN 0건

**Step 2: 잔여 모순 확인**

Run: `grep -cE 'browser_subagent|run_command|\.gemini' .claude/skills/empirical-validation/SKILL.md`
Expected: `0`

Run: `grep 'tools:' .claude/agents/executor.md .claude/agents/planner.md .claude/agents/dispatcher.md`
Expected: executor에 Agent, planner에 Bash, dispatcher에 Agent Boundaries 포함

Run: `grep -c 'pattern-discovery' .claude/hooks/stop-context-save.sh`
Expected: `0`

**Step 3: ARCHITECTURE.md 기술 부채 섹션 최종 갱신**

```markdown
## Technical Debt

**해소 완료 (2026-03-24, 1차):**
- [x] 빌드 스크립트 python3 의존성
- [x] CLAUDE.md docs/ 미반영
- [x] bootstrap.sh python3 필수 요구
- [x] SessionStart hook 토큰 과다

**해소 완료 (2026-03-24, 2차):**
- [x] Agent 도구 선언 불일치 (executor, planner)
- [x] empirical-validation 존재하지 않는 참조
- [x] 빌드 expected counts 불일치 (3개 타겟)
- [x] pattern-discovery 죽은 코드
- [x] scripts/ ↔ .claude/hooks/ 중복 (canonical 위임)
- [x] CI 경로 트리거 확대
- [x] Discovery Level 용어 충돌

**잔여:**
- [ ] `detect-language.sh` 빌드 타겟 미포함 (executor/handoff에서 텍스트 참조만)
- [ ] build-opencode.sh에 `python3 convert-hooks-to-plugins.py` 잔존 (OpenCode TS 플러그인 변환용)
```

**Step 4: Commit**

```bash
git add .hxsk/ARCHITECTURE.md
git commit -m "docs: 2차 기술 부채 해소 완료 반영"
```

---

## 실행 요약

```
Wave 1 (8개 병렬):
  T1: executor.md          — Agent 도구 추가
  T2: planner.md           — Bash 도구 추가
  T3: dispatcher.md        — Agent Boundaries 적용
  T4: empirical-validation — 존재하지 않는 참조 제거
  T5: build-plugin.sh      — expected counts
  T6: build-antigravity.sh — counts + 문서화 + 검증
  T7: build-opencode.sh    — expected counts
  T8: stop-context-save.sh — 죽은 코드 + 로그 로테이션

Wave 2 (4개 병렬):
  T9:  release-plugin.yml  — CI 트리거 확대
  T10: memory-protocol     — type relations 미구현 명시
  T11: scripts/ 중복 정리   — canonical 위임 래퍼
  T12: CLAUDE.md + PATTERNS — 용어 명확화

Wave 3 (순차):
  T13: 통합 빌드 검증 + 문서 갱신

해소 대상: M1~M16 + 잔여 부채 6건 중 4건 = 총 20건
잔여 (의도적 보류): 2건 (detect-language.sh, convert-hooks-to-plugins.py)
총 커밋: 13개
```
