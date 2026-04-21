# HXSK Setup E2E — Use Cases (Formal)

**Format**: Actor + Precondition + Steps + Expected outcome  
**Derived from**: 25-iteration scenario exploration  
**Grouped by**: Severity

---

## UC-CRITICAL-01: bootstrap-version 손상 감지 및 안전 중단

**Actor**: Claude Code 에이전트  
**Precondition**: `.hxsk/.bootstrap-version` 파일이 존재하지만 `version:` 필드가 없거나 내용이 손상됨  
**Steps**:
1. Step 0 상태 감지 스크립트 실행
2. 파일 존재 확인: `test -f .hxsk/.bootstrap-version` → true
3. 버전 추출: `grep '^version:'` → 빈 문자열
4. `CORRUPTED` 분기 진입 (현재: 잘못된 `FRESH` 분기)
5. 사용자에게 수동 확인 요청: "`.bootstrap-version` 내용을 직접 확인하세요"

**Expected outcome**: 파일 손상 시 기존 파일을 덮어쓰지 않고 사용자 개입 요청  
**Failure scenario**: 현재 → FRESH로 진행 → SPEC.md/memories 덮어쓰기 → 프로젝트 데이터 손실

---

## UC-CRITICAL-02: md-store-memory.sh 디렉토리 자동 생성

**Actor**: Claude Code 에이전트  
**Precondition**: `.hxsk/memories/` 존재, 타입 서브디렉토리 없음  
**Steps**:
1. `md-store-memory.sh "제목" "내용" "태그" "architecture-decision"` 실행
2. 스크립트 내 `TARGET_DIR=".hxsk/memories/architecture-decision"` 설정
3. `mkdir -p "$TARGET_DIR"` 자동 실행 (현재: 없으면 실패)
4. 파일 생성 성공
5. exit code 0 반환

**Expected outcome**: 타입 디렉토리 없어도 자동 생성 후 저장 성공  
**Failure scenario**: 현재 → 조용한 exit 1 → 에이전트가 저장됐다 가정 → 중요 결정/패턴 유실

---

## UC-CRITICAL-03: U6 커밋 시 명시적 파일 스테이징

**Actor**: 업그레이드 사용자  
**Precondition**: U3 동기화 완료, 프로젝트에 `.env` 또는 민감 파일 존재 가능  
**Steps**:
1. U6 커밋 전 `git status` 출력 확인
2. `git add .hxsk/ CLAUDE.md AGENTS.md GEMINI.md .claude/settings.json` (명시적)
3. 민감 파일이 스테이징 목록에 없음을 확인
4. `git commit -m "chore(hxsk): v... → v... 프레임워크 동기화"`

**Expected outcome**: 프레임워크 파일만 커밋, `.env` 등 프로젝트 파일 미포함  
**Failure scenario**: `git add -A` 사용 시 `.gitignore` 미설정된 `.env` 커밋 → 시크릿 유출

---

## UC-HIGH-01: bootstrap.sh FAIL 시 setup.md 참조 안내

**Actor**: 신규 사용자  
**Precondition**: FRESH 상태, setup 건너뛰고 `/bootstrap` 직접 실행  
**Steps**:
1. `/bootstrap` 실행 → `SPEC.md not found`
2. 에러 메시지: "HXSK 초기 설정이 필요합니다. `.hxsk/prompts/setup.md`를 먼저 실행하세요."
3. 사용자가 setup.md로 이동

**Expected outcome**: 에러 메시지에 다음 단계 명시  
**Failure scenario**: 현재 → `[FAIL] SPEC.md not found` 만 출력 → 사용자 이탈

---

## UC-HIGH-02: 완료 체크리스트 — 검증 명령 포함

**Actor**: 신규 사용자  
**Precondition**: 설치 단계 완료 후 체크리스트 검토  
**Steps**:
1. "필수 스킬 5개 배치됨" → `ls .claude/skills/ | wc -l` 출력이 5 이상 확인
2. "훅 8개 이벤트 등록됨" → `cat .claude/settings.json | grep -c '"type": "command"'` ≥ 8 확인
3. "메모리 명령어 동작 확인" → `bash .hxsk/hooks/md-store-memory.sh "test" "test" "test" "test"` exit 0 확인
4. 모든 항목 실제 실행 후 체크

**Expected outcome**: 체크리스트 통과 = 실제 작동 보장  
**Failure scenario**: 현재 → 시각적 체크 → 실제 미작동 상태로 `/bootstrap` 실행

---

## UC-HIGH-03: settings.json 훅 이벤트 수 검증

**Actor**: Claude Code 에이전트  
**Precondition**: Step 6 settings.json 작성 완료  
**Steps**:
1. `check-consistency.sh` 또는 `bootstrap.sh` 실행
2. settings.json에서 훅 이벤트 키 수 검사: SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SubagentStop, SessionEnd = 7개 이벤트
3. 누락 이벤트 목록 출력
4. 모두 있으면 `[OK] hooks: 7/7 events registered`

**Expected outcome**: 훅 이벤트 수 자동 검증  
**Failure scenario**: 현재 → 누락 이벤트 미감지 → PreCompact 미등록 → 컨텍스트 압축 시 메모리 손실

---

## UC-HIGH-04: 부분 설치 상태 감지 및 안전 재설치

**Actor**: 신규 사용자 (이전 실패 후 재시도)  
**Precondition**: `.hxsk/` 존재, `.claude/settings.json` 커스텀 훅 포함  
**Steps**:
1. Step 0: `FRESH` 감지 (`.bootstrap-version` 없음)
2. 에이전트: "기존 `.hxsk/` 디렉토리 감지. 기존 파일 보존 여부 확인"
3. 사용자 확인: "기존 SPEC.md, settings.json 유지"
4. 기존 파일은 덮어쓰지 않고 누락된 파일만 생성

**Expected outcome**: 재설치 시 기존 커스텀 설정 보존  
**Failure scenario**: 현재 → settings.json 무조건 덮어쓰기 → 커스텀 훅 소실

---

## UC-HIGH-05: Windows 환경 symlink 폴백

**Actor**: 신규 사용자 (Windows Git Bash / Developer Mode OFF)  
**Precondition**: Windows 환경, `ln` 명령 제한적  
**Steps**:
1. Step 4에서 `ln -sfn` 실패 감지 (exit code 1)
2. 폴백 자동 전환: `cp -r .hxsk/skills/. .claude/skills/`
3. 경고: "심볼릭 링크 미지원 — 복사본 사용. `.hxsk/skills/` 수정 시 Step 4 재실행 필요"
4. 설치 계속 진행

**Expected outcome**: Windows에서도 설치 완료 가능  
**Failure scenario**: 현재 → 조용한 실패 → 스킬 미로드

---

## UC-HIGH-06: U1 결정 트리에 판별 기준 예시 추가

**Actor**: 업그레이드 사용자  
**Precondition**: U1에서 수정된 `.hxsk/skills/executor/SKILL.md` 감지  
**Steps**:
1. U1 출력: `modified: .hxsk/skills/executor/SKILL.md`
2. 판별 기준 확인:
   - 프로젝트 고유 로직 추가 → `skills-custom/` 이동
   - 프레임워크 버그 수정 → 상위 PR 반영 후 받기
   - 실험적 변경 → `git stash` 후 cherry-pick
3. 사용자가 명확한 기준으로 결정

**Expected outcome**: 오판으로 인한 커스텀 수정 손실 방지  
**Failure scenario**: 현재 → 기준 없이 3가지 옵션만 → 오판 → U3 rsync로 소실

---

## UC-MEDIUM-01: U2에 로컬 파일 3번째 옵션 추가

**Actor**: 업그레이드 사용자 (GitHub 차단 환경)  
**Precondition**: 회사 프록시로 GitHub HTTPS 차단  
**Steps**:
1. 옵션 A (git clone) 실패
2. 옵션 B (curl tarball) 실패
3. 옵션 C (로컬 파일): "로컬에 다운로드한 HXSK 아카이브 경로 지정: `HX_SRC=/path/to/local/hxsk`"
4. 로컬 경로로 U3 진행

**Expected outcome**: 오프라인/차단 환경에서도 업그레이드 가능

---

## UC-MEDIUM-02: doc-lint ORPHAN_EXCLUDE_DIRS 기본 확장

**Actor**: Claude Code 에이전트 (autoresearch, learn, reason 커맨드 사용 후)  
**Precondition**: `scenario/`, `learn/`, `reason/` 신규 디렉토리 생성  
**Steps**:
1. doc-lint.sh의 `ORPHAN_EXCLUDE_DIRS`에 기본 포함:
   - `./.hxsk/memories ./.hxsk/templates ./.hxsk/archive ./.hxsk/issues ./.hxsk/examples ./docs/plans ./.hxsk/docs/plans ./.hxsk/reports ./.hxsk/research ./learn ./reason ./scenario`
2. 신규 작업 디렉토리 생성 시 doc-lint 자동 통과

**Expected outcome**: autoresearch 등 산출물 디렉토리에서 불필요한 ORPHAN-01 실패 없음
