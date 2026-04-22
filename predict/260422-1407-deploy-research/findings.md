# Findings — 배포 프로세스 개선 연구

> 8 페르소나 × 3 라운드 토론 기반. priority_score = severity×0.4 + confidence×0.2 + consensus_ratio×0.4

---

## Finding 1: 신뢰성 11건 — Silent Failure 패턴

**Severity:** CRITICAL
**Confidence:** HIGH
**Location:** `.hxsk/hooks/md-store-memory.sh`, `setup.md:Step 0`, `bootstrap.sh`
**Consensus:** 5/8 페르소나 (RE, SA, PE, UX, AR)
**priority_score:** 4×0.4 + 1.0×0.2 + 1.0×0.4 = **2.2 (최고)**

**Evidence:**
- `md-store-memory.sh`: TYPE_DIR 디렉토리 미존재 시 경고 없이 실패 → 메모리 유실
- `setup.md Step 0`: CORRUPTED 분기 문서에는 있으나 `bootstrap.sh`에 구현 없음 → FRESH 오분기 → SPEC.md 덮어쓰기
- `setup.md U6`: `git add -A` 대신 명시적 스테이징 권장 (이미 수정 완료)
- `md-recall-memory.sh`: 2-hop 범위 무한 확장 → 노이즈 검색 결과
- `prune-tick.sh`: stale lock(300s 미감지) → prune 영구 차단

**Recommendation:**
1. `bootstrap.sh`: `.bootstrap-version` 파싱 실패 시 `CORRUPTED` 모드 분기 추가
2. `md-store-memory.sh`: `mkdir -p "$TYPE_DIR"` + 실패 시 명확한 exit 1
3. `stop-context-save.sh`: `mv` 원자적 경쟁조건 → atomic flag 패턴 적용

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| RE | confirm | RE-1, RE-3b 직접 발견 |
| SA | confirm | SA-8 stale lock 포함 |
| PE | confirm | "silent failure = 30% 이탈" |
| UX | confirm | "복구 불가 = 이탈 주원인" |
| AR | confirm | "신뢰성이 Plugin보다 선행" |
| DE | confirm | "로그 없음 → 재현 불가" |
| OM | abstain | 범위 외 |
| DA | revise | "11건 중 C1, C3 최우선" |

---

## Finding 2: setup.md Step 6 — JSON 수동 편집

**Severity:** HIGH
**Confidence:** HIGH
**Location:** `setup.md:130-173 (Step 6)`
**Consensus:** 5/8 페르소나 (UX, PE, AR, RE, SA)
**priority_score:** 3×0.4 + 1.0×0.2 + 0.625×0.4 = **1.65**

**Evidence:**
- 172줄 JSON 블록(8 이벤트, 26 훅)을 사용자/에이전트가 수동 복사·편집
- `settings.json` 재설치 시 커스텀 훅 덮어쓰기 위험 (RE-6 발견)
- 훅 누락 시 `bootstrap.sh`가 감지 못함 (RE-5)
- 인지 부하: 설치 흐름의 25%를 JSON 편집이 차지 (UX-3)

**Recommendation:**
```bash
# .hxsk/scripts/install-hooks.sh 생성
bash .hxsk/scripts/install-hooks.sh --harness claude-code [--merge]
# 기존 settings.json 있으면 깊은 병합(deep merge), 없으면 새로 생성
```
- `--merge` 플래그: 기존 커스텀 훅 보존 + HXSK 훅 추가
- `bootstrap.sh VERIFY`: 훅 이벤트 수 자동 검증

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| UX | confirm | "인지 부하 극대화" |
| PE | confirm | "최대 마찰점" |
| AR | confirm | "자동화 설계 결함" |
| RE | confirm | "덮어쓰기 위험" |
| SA | confirm | "훅 파일 무결성 검증도 필요" |
| DE | confirm | "설치 자동화 가능" |
| OM | abstain | — |
| DA | revise | "병합 로직 없으면 역효과 가능" |

---

## Finding 3: setup.md — 선택/필수 단계 미분리

**Severity:** HIGH
**Confidence:** HIGH
**Location:** `setup.md:Step 0-9 전체`
**Consensus:** 5/8 페르소나 (DA, AR, PE, UX, RE)
**priority_score:** 3×0.4 + 1.0×0.2 + 0.625×0.4 = **1.65**

**Evidence:**
- 9단계 중 실제 필수: Step 1(llms.txt), 4(스킬 설치), 6(훅 설치) = 3단계
- 선택: Step 2(에이전트 지침), 3(디렉토리), 5(진입점 연결), 7(메모리), 8(뱃지), 9(멀티 하네스) = 6단계
- 현행: 모든 단계가 동등하게 표시 → 신규 사용자 "9단계를 전부 해야 하나?" 혼란
- DA 토론 결과: "단계 수"가 아닌 "선택/필수 불명확"이 실제 진입 장벽

**Recommendation:**
```markdown
## 초기 설치 (필수 3단계 — 약 5분)

### [필수] Step 1: 진입점 읽기
### [필수] Step 4: 스킬/에이전트 설치
### [필수] Step 6: 훅 설치

## 확장 설정 (선택 — 필요 시 적용)

### [선택] Step 2: 에이전트 지침 파일
### [선택] Step 5: 자동 로드 경로
...
```

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| DA | confirm | "3(필수)+6(선택) 구조 명시 시 진입장벽 50% 감소" |
| AR | confirm | "의존성 맵도 함께 필요" |
| PE | confirm | "신규 사용자 5분 경로 가시화" |
| UX | confirm | "결정 마비 제거" |
| RE | confirm | "필수 3단계에 검증 집중 가능" |
| SA | abstain | — |
| OM | confirm | "빠른 시작 시나리오 문서화로 연결" |
| DE | abstain | — |

---

## Finding 4: SHA256 검증 없는 tarball 다운로드

**Severity:** HIGH
**Confidence:** HIGH
**Location:** `setup.md:U2 (라인 257~284)`
**Consensus:** 4/8 페르소나 (SA, DE, AR, PE) — DA 토론 후 동의
**priority_score:** 3×0.4 + 1.0×0.2 + 0.5×0.4 = **1.60**

**Evidence:**
```bash
# setup.md U2 현행
curl -sL "https://github.com/.../setup-v$TARGET_VERSION.tar.gz" \
    | tar xz -C "$HX_SRC" --strip-components=1
# SHA256 검증 없음 — 다운로드 완결성·무결성 보장 불가
```
- GitHub Releases에 체크섬 미첨부
- 부분 다운로드·네트워크 중단 시 불완전 추출 → U3 rsync 오염
- 공급망 공격(GitHub 계정 탈취, Release 변조) 시나리오 무방비

**Recommendation:**
```bash
# .hxsk/scripts/pre-release-check.sh 에 추가
sha256sum ".hxsk/cache/setup-v$TARGET_VERSION.tar.gz" > ".hxsk/cache/sha256.txt"
# GitHub Releases에 sha256sums 파일 첨부 (릴리스 체크리스트)
```

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| SA | confirm | "공급망 CRITICAL" |
| DE | confirm | "릴리스 자동화와 연계" |
| AR | confirm | "신뢰 체인 끊김" |
| PE | confirm | "다운로드 실패 감지 포함" |
| DA | revise | "HTTPS 신뢰 + SHA = 합리적 tradeoff, CRITICAL→HIGH 완화" |
| RE | confirm | "부분 다운로드 시나리오 포함" |
| UX | abstain | — |
| OM | abstain | — |

---

## Finding 5: 발견 가능성 부재 — 플러그인 마켓 미등록

**Severity:** HIGH
**Confidence:** MEDIUM
**Location:** `README.md`, `llms.txt`, GitHub repo 외부
**Consensus:** 4/8 페르소나 (OM, AR, PE, DE)
**priority_score:** 3×0.4 + 0.6×0.2 + 0.5×0.4 = **1.52**

**Evidence:**
- claudemarketplaces.com: 105K 월간 방문, 87~103 플러그인 등록 — HXSK 없음
- Claude Code Plugin System 미사용 → `/plugin marketplace` 검색 불가
- llms.txt 전체 웹 채택률 10.13% → 진입 경로 의존도 과다
- autoresearch: GitHub 공개 저장소 + 마켓플레이스 → 자연 발견

**Recommendation:**
1. **즉시**: claudemarketplaces.com에 HXSK 등록 (PR 제출)
2. **단기**: `plugin.json` + `marketplace.json` 생성 → Claude Code Plugin으로 패키징
3. **선택**: Everything-Claude-Code 등 커뮤니티 마켓에 추가

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| OM | confirm | "발견 가능성 = 커뮤니티 성장의 전제" |
| AR | confirm | "Plugin 패키징은 P2지만 등록은 P1" |
| PE | confirm | "신규 사용자 유입 경로 다양화" |
| DE | confirm | "릴리스 자동화와 묶어서 진행 가능" |
| DA | dispute | "발견해도 설치 신뢰성 없으면 이탈 반복" |
| RE | abstain | — |
| SA | abstain | — |
| UX | revise | "마켓 등록보다 README Quick Start가 선행" |

---

## Finding 6: bootstrap.sh 실행 로그 미저장

**Severity:** MEDIUM
**Confidence:** HIGH
**Location:** `.hxsk/scripts/bootstrap.sh`
**Consensus:** 3/8 (DE, DA, RE)
**priority_score:** 2×0.4 + 1.0×0.2 + 0.375×0.4 = **1.15**

**Evidence:**
- bootstrap.sh 실행 결과가 터미널에만 출력, 파일 저장 없음
- 설치 실패 시 재현 불가 → GitHub Issues 신고 어려움
- 업그레이드 후 "무엇이 바뀌었나" 추적 불가

**Recommendation:**
```bash
LOG_FILE=".hxsk/logs/bootstrap-$(date +%Y%m%d-%H%M%S).log"
mkdir -p ".hxsk/logs"
bootstrap_main 2>&1 | tee "$LOG_FILE"
```

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| DE | confirm | "디버깅 가능성" |
| DA | confirm | "신뢰도 향상 직결" |
| RE | confirm | "재현 가능성" |
| 기타 5 | abstain | — |

---

## Finding 7: Windows 심볼릭 링크 실패 → 조용한 실패

**Severity:** HIGH
**Confidence:** HIGH
**Location:** `setup.md:Step 4 (라인 89-104)`
**Consensus:** 2/8 (RE, AR) — 소수 의견
**priority_score:** 3×0.4 + 1.0×0.2 + 0.25×0.4 = **1.50**

**Evidence:**
- Windows Developer Mode OFF → `ln -sfn` 실패 (권한 오류)
- set -e 없으면 에러 무시 후 계속 진행 → `.claude/skills/` 빈 상태로 "설치 완료"

**Recommendation:**
```bash
if ! ln -sfn "../../.hxsk/skills/$skill_name" ".claude/skills/$skill_name" 2>/dev/null; then
    echo "[WARN] symlink failed, copying instead"
    cp -r ".hxsk/skills/$skill_name" ".claude/skills/$skill_name"
fi
```

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| RE | confirm | "Windows 환경 무음 실패" |
| AR | confirm | "플랫폼 호환성 결함" |
| 기타 6 | abstain | "Windows 사용자 비율 불명확" |

---

## Finding 8: 멀티 하네스 어댑터 동기화 메커니즘 부재

**Severity:** MEDIUM
**Confidence:** MEDIUM
**Location:** `.hxsk/adapters/`, `setup.md:부록 A`
**Consensus:** 3/8 (AR, DE, OM)
**priority_score:** 2×0.4 + 0.6×0.2 + 0.375×0.4 = **1.07**

**Evidence:**
- 8개 어댑터 파일이 각각 `.cursor/`, `.gemini/` 등에 수동 복사
- HXSK 업그레이드 시 복사본이 구버전으로 방치 → 동작 불일치
- `bootstrap.sh VERIFY` 모드가 어댑터 버전 확인 안 함

**Recommendation:**
```bash
# .hxsk/scripts/hxsk-harness-sync.sh
bash .hxsk/scripts/hxsk-harness-sync.sh --check   # 드리프트 감지
bash .hxsk/scripts/hxsk-harness-sync.sh --sync     # 자동 업데이트
```

**Persona Votes:**

| Persona | Vote | Note |
|---------|------|------|
| AR | confirm | "분산 배포 취약점" |
| DE | confirm | "자동화 대상" |
| OM | confirm | "유지보수 부담" |
| DA | dispute | "9개 하네스 중 실제 사용 3개 추정 — Pareto" |
| 기타 4 | abstain | — |
