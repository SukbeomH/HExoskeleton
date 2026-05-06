# Testing & Validation Guide

> HExoskeleton은 전통적 unit test 프레임워크 대신 **empirical validation + doc-lint + consistency check** 3층 검증을 사용한다.

## 1. Testing Philosophy

HXSK의 산출물은 주로 **bash 스크립트 + 마크다운 문서**다. 두 가지는 전통적 단위 테스트가 어렵다:
- Bash 스크립트 → shell의 비결정성과 I/O 의존성
- 마크다운 → 의미론적 일관성이 핵심 (link·ref·count 무결성)

따라서 HXSK는 **3층 검증 모델**을 채택한다:

```
┌─────────────────────────────────────────────┐
│ Layer 3: Empirical Validation (에이전트)      │
│  - 명령 실행 결과로 증거 수집                   │
│  - empirical-validation skill 게이트         │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ Layer 2: Doc & Consistency Lint (스크립트)   │
│  - doc-lint.sh: 링크/인덱스/카운트/고아 파일   │
│  - check-consistency.sh: 교차 검증            │
└─────────────────────────────────────────────┘
┌─────────────────────────────────────────────┐
│ Layer 1: Code Quality (tools)                │
│  - shellcheck: bash 정적 분석                 │
│  - shfmt: 포맷 검증                           │
│  - qlty (선택): 통합 품질 플랫폼               │
└─────────────────────────────────────────────┘
```

## 2. Layer 1 — Code Quality

### 2.1 ShellCheck
모든 `.sh` 파일은 ShellCheck **CLEAN**이어야 한다.

```bash
# 단일 파일
shellcheck .hxsk/hooks/session-start.sh

# 모든 훅 + 스크립트 + githooks
shellcheck .hxsk/hooks/*.sh .hxsk/scripts/*.sh .hxsk/githooks/*
```

허용되는 예외:
- `SC2155` (declare + assign) — 명시적으로 의도한 경우 `# shellcheck disable=SC2155`
- `SC1091` (source not found) — source 경로가 런타임 상대 해결되는 경우

### 2.2 shfmt
일관된 포맷:
```bash
shfmt -d .hxsk/hooks/*.sh .hxsk/scripts/*.sh
# -d: diff만 출력. 적용은 -w
shfmt -w .hxsk/hooks/*.sh
```

### 2.3 `clean` skill
자동 수정:
```
/skill clean
# shellcheck 이슈 자동 수정 + shfmt 적용
```

### 2.4 `qlty` (선택)
```bash
make install-qlty
qlty check              # 통합 lint
qlty fmt                # 자동 포맷
```

## 3. Layer 2 — Doc & Consistency

### 3.1 doc-lint.sh

검증 규칙 (각 규칙은 독립 실행 가능):

| Rule | 검증 내용 |
|------|----------|
| **LINK-01** | Broken internal links — 존재하지 않는 파일로의 상대 경로 |
| **LINK-02** | Broken anchor links — 존재하지 않는 헤딩 앵커로의 링크 |
| **INDEX-01** | INDEX.md 카운트와 실제 파일 수 일치 |
| **INDEX-02** | INDEX.md 항목과 실제 파일 존재 대응 |
| **COUNT-01** | "17개 스킬" 같은 inline 카운트 자동 동기화 |
| **REF-01** | 중복 파일명 참조 모호성; 예상 중복 파일명은 DUP-01 목록에 등록 |
| **ORPHAN-01** | INDEX에 없는 .md 파일 (의도적 orphan 제외); `ORPHAN_EXCLUDE_DIRS`에 `./scenario ./predict ./.hxsk/docs ./.hxsk/phases` 포함 |

실행:
```bash
bash .hxsk/scripts/doc-lint.sh                # 전체
bash .hxsk/scripts/doc-lint.sh --rule LINK-01 # 특정 규칙만
bash .hxsk/scripts/doc-lint.sh --fix          # 자동 수정 (안전한 것만)
```

### 3.2 check-consistency.sh

Skills/Agents/Hooks INDEX 파일과 실제 파일 시스템 대조:

```bash
bash .hxsk/hooks/check-consistency.sh
```

검증 항목:
- `.hxsk/skills/INDEX.md`에 등재된 스킬 == `.hxsk/skills/*/`의 실제 디렉토리
- `.hxsk/agents/INDEX.md`의 카운트 == 실제 파일 수
- 각 SKILL.md의 frontmatter `name` == 디렉토리명
- Agents가 참조한 스킬이 실제 존재

### 3.3 pre-commit-doc-lint.sh
Git 훅으로 자동 실행 (commit 거부):
```bash
git config core.hooksPath .hxsk/githooks
# 이후 commit 시 doc-lint.sh 자동 실행
```

### 3.4 pre-pr-check.sh
PR 생성 직전 종합 검증:
```bash
bash .hxsk/hooks/pre-pr-check.sh
```

검증:
- 버전 일관성 (llms.txt, .bootstrap-version, CHANGELOG.md 첫 버전)
- CHANGELOG 항목 존재 (현재 릴리스 설명)
- 릴리스 노트 완전성
- doc-lint 통과
- 브랜치명 규칙 (`feat/plan-*`, `fix/*` 등)

## 4. Layer 3 — Empirical Validation

### 4.1 `empirical-validation` Skill

이 스킬은 **"검증 없이 완료 주장 금지"** 게이트다. Iron Law 1.2를 강제.

호출 시점:
- 구현 완료 직전
- PR 생성 전
- "테스트 통과" 주장 시

```
/skill empirical-validation

# 에이전트가 다음을 수행:
# 1. 주장된 변경사항 식별
# 2. 각 주장에 대응하는 실행 가능 증거 요청
# 3. 명령 실행 → 출력 수집
# 4. 증거가 주장을 뒷받침하는지 판정
# 5. 부족하면 BLOCK
```

### 4.2 증거 타입

| 주장 | 허용되는 증거 |
|------|-------------|
| "테스트 통과" | `test` 명령 exit code 0 + 출력 요약 |
| "빌드 성공" | 빌드 명령 exit code 0 |
| "문서 업데이트" | `git diff --stat` 출력 |
| "훅 동작" | 실제 이벤트 트리거 후 로그 확인 |
| "메모리 저장" | `md-recall-memory.sh`로 회상 성공 |
| "lint 통과" | `shellcheck` / `doc-lint.sh` exit code 0 |

### 4.3 Anti-Rationalization (차단되는 표현 12종)

아래 문구가 증거로 제출되면 `empirical-validation`이 거부:

**False completion (5)**:
- "잘 동작할 것으로 보인다"
- "아마 통과할 것"
- "로직상 문제 없음"
- "이전에 테스트했으니 OK"
- "시간 없으니 다음에 검증"

**Skipped reads (4)**:
- "이 파일은 확인 안 했지만..."
- "맥락상 X 일 것"
- "파일명으로 추측"
- "비슷한 패턴이니까"

**File overwrites (3)**:
- "기존 내용 무시해도 OK"
- "Write로 덮어쓰면 더 간결"
- "어차피 재생성되는 파일"

상세: `.hxsk/skills/empirical-validation/SKILL.md`.

## 5. Skill Testing (TDD for Skills)

`skill-testing` skill은 스킬 자체를 TDD 사이클로 테스트:

```
RED   → 의도된 트리거가 있지만 스킬이 작동 안 하는 시나리오 작성
GREEN → 스킬이 기대 동작을 수행하도록 수정
REFACTOR → 중복 제거, 설명 압축
```

실행:
```
/skill skill-testing
# 대화형: 어떤 스킬을 테스트할지 질문
# → 시나리오 작성 → 실행 → 판정
```

## 6. Self-Configure Verification

### 6.1 verify-self-configure.sh

설치·업그레이드 후 환경 검증:
```bash
bash .hxsk/scripts/verify-self-configure.sh
```

검증 항목:
- [ ] 훅이 Claude Code 설정(`.claude/settings.json`)에 바인딩됨
- [ ] 현재 스키마/확장 표면에서 요구하는 메모리 타입 디렉토리가 모두 존재
- [ ] `.bootstrap-version`과 llms.txt 버전 일치
- [ ] 심볼릭 링크 정상 해결 (`.claude/skills/` → `.hxsk/skills/`)
- [ ] 필수 스킬 5개(bootstrap, planner, executor, verifier, memory-protocol) 존재
- [ ] doc-lint 기본 통과
- [ ] `gate-check.sh status` 실행 가능

### 6.2 setup-verify.sh — 설치 검증 (5 독립 조건)

```bash
bash .hxsk/scripts/setup-verify.sh
```

### 6.3 local-verify.sh — 로컬 종합 검증

변경 완료 전 권장 기본값:
```bash
bash .hxsk/scripts/local-verify.sh
```

이 번들은 `doc-lint.sh`, `check-consistency.sh`, 스킬 테스트 dry-run(시나리오가 있을 때), `pre-pr-check.sh`를 순서대로 실행한다. 네트워크 의존 검사는 기본 비활성화하고 로컬에서 먼저 실패하도록 설계되어 있다.

| 조건 | 확인 내용 |
|------|---------|
| 스킬 수 | `.claude/skills/` 내 스킬 디렉토리 ≥1 |
| 에이전트 수 | `.claude/agents/` 내 에이전트 파일 ≥1 |
| 훅 이벤트 | `.claude/settings.json`에 7개 이벤트 등록 확인 |
| 메모리 디렉토리 | `.hxsk/memories/` 하위 타입 디렉토리 존재 |
| bootstrap 버전 | `.hxsk/.bootstrap-version` 파싱 성공 |

### 6.4 Smoke Test

설치 직후 수동 확인:
```bash
# 1. 메모리 시스템
bash .hxsk/hooks/md-store-memory.sh general "smoke-test" "setup test" --keywords smoke
bash .hxsk/hooks/md-recall-memory.sh "smoke-test" "." 3
ls .hxsk/memories/general/ | grep smoke

# 2. 게이트 시스템
bash .hxsk/hooks/gate-check.sh status

# 3. Forge 감지
source .hxsk/scripts/forge-detect.sh
echo "Forge: $FORGE_CMD"

# 4. Consistency
bash .hxsk/hooks/check-consistency.sh
```

## 7. Running Tests in CI

### 7.1 GitHub Actions
```yaml
# .github/workflows/hxsk-ci.yml
name: HXSK CI
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck
      - name: ShellCheck
        run: shellcheck .hxsk/hooks/*.sh .hxsk/scripts/*.sh
      - name: Doc Lint
        run: bash .hxsk/scripts/doc-lint.sh
      - name: Consistency Check
        run: bash .hxsk/hooks/check-consistency.sh
      - name: Self-Configure Verify
        run: bash .hxsk/scripts/verify-self-configure.sh
```

### 7.2 GitLab CI
```yaml
hxsk-ci:
  image: ubuntu:latest
  script:
    - apt-get update && apt-get install -y bash git shellcheck
    - bash .hxsk/scripts/doc-lint.sh
    - bash .hxsk/hooks/check-consistency.sh
```

## 8. Pre-Commit Workflow

권장 pre-commit 파이프라인 (이미 `.hxsk/githooks/`에 구성):

```
git commit 시도
    ↓
1. pre-commit-doc-lint.sh
    └─ doc-lint.sh 실행 → 실패 시 commit 거부
    ↓
2. pre-commit-version-check.sh (21 lines)
    └─ llms.txt / .bootstrap-version / CHANGELOG 버전 sync 검증
    ↓
3. commit 완료
    ↓
4. post-commit (백그라운드)
    └─ prune-tick.sh → 60s 쿨다운으로 메모리 프룬
```

활성화:
```bash
git config core.hooksPath .hxsk/githooks
```

## 9. Debugging Failed Tests

### 9.1 doc-lint 실패
```bash
# 상세 출력
bash .hxsk/scripts/doc-lint.sh --verbose

# 특정 규칙만
bash .hxsk/scripts/doc-lint.sh --rule LINK-01

# 자동 수정 (안전한 경우에만)
bash .hxsk/scripts/doc-lint.sh --fix
```

### 9.2 check-consistency 실패
```bash
# 상세 diff
bash .hxsk/hooks/check-consistency.sh --verbose
# 보통 INDEX.md 업데이트 누락 → 수동 수정
```

### 9.3 ShellCheck 실패
```bash
# 특정 check ID 추가 정보
shellcheck --wiki-link-count=100 .hxsk/hooks/foo.sh
# https://www.shellcheck.net/wiki/SC{id}
```

### 9.4 verify-self-configure 실패
```bash
bash .hxsk/scripts/verify-self-configure.sh 2>&1 | tee /tmp/verify.log
# 각 체크별 에러 메시지 확인 → 해당 Step 재실행
```

## 10. Memory-Level Testing

메모리 저장/회상이 올바르게 동작하는지 확인:

```bash
# 1. 저장
bash .hxsk/hooks/md-store-memory.sh root-cause "test-bug" "테스트용 근본 원인" \
    --keywords "test,mock" \
    --contextual-description "이것은 테스트 엔트리입니다"

# 2. 1-hop 회상
bash .hxsk/hooks/md-recall-memory.sh "test-bug" "." 5

# 3. 2-hop 회상 (related 필드 추적)
bash .hxsk/hooks/md-recall-memory.sh "test-bug" "." 5 compact
# related: [...] 필드가 있으면 관련 메모리도 함께 반환

# 4. 프룬 동작
bash .hxsk/scripts/prune-memories.sh --dry-run
# 프룬 대상 목록만 출력 (실제 삭제 없음)
```

## 11. Test Coverage Overview

| 영역 | 검증 방법 | 자동화 |
|------|----------|-------|
| bash 스크립트 구문 | shellcheck | CI + pre-commit |
| bash 스크립트 포맷 | shfmt | CI (optional) |
| 문서 링크 무결성 | doc-lint.sh LINK-01/02 | pre-commit |
| 문서 인덱스 sync | doc-lint.sh INDEX-01/02 | pre-commit |
| 스킬/에이전트/훅 교차 | check-consistency.sh | 수동 + CI |
| 버전 일관성 | pre-commit-version-check.sh | pre-commit |
| 설치 무결성 | verify-self-configure.sh | 설치 직후 수동 |
| 게이트 조건 | gate-check.sh | PLAN/EXECUTE 진입 시 |
| 메모리 동작 | smoke test (6.2) | 수동 |
| 스킬 동작 (TDD) | skill-testing skill | 에이전트 주도 |
| 에이전트 완료 주장 | empirical-validation skill | 완료 선언 게이트 |
| **신뢰성 회귀 감지** | **check-reliability.sh** | **수동 (릴리스 전)** |

### 11.1 check-reliability.sh

14개 패턴 신뢰성 이슈 카운터 (기존 11개 → SA-7·RE-5·H-05 추가):
```bash
bash .hxsk/scripts/check-reliability.sh
# → ISSUE COUNT: N
```

**목표**: `ISSUE COUNT: 0`

감지 패턴 예시:
- `set -e` 누락 스크립트
- TYPE_DIR 자동 생성 없는 메모리 저장
- YAML frontmatter에 비안전 문자열 삽입
- `.hxsk/` 존재 검증 누락
- stale lock 미감지
- 2-hop related 파싱이 frontmatter 외부로 누출
- `.prune-config` 소싱 전 권한 검증 누락

신규 검사 (Phase 7):

| 검사 ID | 검증 내용 |
|---------|---------|
| SA-7 | `stop-context-save.sh` 원자적 mv 패턴 (`CLAIMED_FLAG="${FLAG_FILE}.$"`) 존재 검증 |
| RE-5 | `md-store-memory.sh` yaml_safe() 태그 루프 항목 전수 적용 검증 |
| H-05 | `setup.md` U2 섹션 SHA256 검증 스니펫 존재 검증 |

## See Also

- [Code Standards](code-standards.md) — Iron Laws 및 컨벤션
- [Configuration Guide](configuration-guide.md) — CI 환경 변수
- `.hxsk/VERIFICATION.md` — 내부 검증 상세
- `.hxsk/skills/empirical-validation/SKILL.md` — 검증 게이트 상세
- `.hxsk/skills/skill-testing/SKILL.md` — 스킬 TDD 프로토콜
- `.hxsk/docs/LINTING.md` — lint 심화
