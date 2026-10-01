# 합리화 테이블 갱신 가이드

> `.hxsk/.rationalization-patterns.log`에 수집된 패턴을 주기적으로 합리화 테이블에 반영하는 프로세스.

---

## 수집 경로

`collect-rationalization.sh` Stop 훅(Claude Code 플러그인, `.hxsk/`가 있는 프로젝트)이 매 턴 에이전트 출력을 스캔하여 기록:
- 합리화 시그널 패턴 감지 시 `DETECTED` 로그
- Iron Law 위반 시 `VIOLATION` 로그

## 갱신 주기

- **권장**: 세션 10회마다 또는 월 1회
- **트리거**: `.rationalization-patterns.log`가 20줄 이상일 때

## 갱신 프로세스

### 1. 로그 분석
```bash
# 빈도순 정렬
sort .hxsk/.rationalization-patterns.log | grep DETECTED | \
  sed 's/.*DETECTED: "//' | sed 's/"//' | sort | uniq -c | sort -rn
```

### 2. 신규 패턴 식별
로그에서 기존 합리화 테이블에 없는 패턴을 찾는다.

### 3. 테이블 갱신
설치된 스킬 파일은 직접 고치지 않는다 — 플러그인 설치에서는 플러그인 캐시에 있어 업데이트 때 덮어써진다.

- **일반 패턴**: HXSK 저장소에 PR로 제안한다 (`skills/empirical-validation/SKILL.md`의 합리화 테이블에 `| {새 변명} | {현실 대응} |` 행 추가).
- **이 프로젝트에만 해당하는 패턴**: `.hxsk/PATTERNS.md`의 `## Gotchas`에 `- "{변명}" → {현실 대응}` 한 줄로 기록한다.

### 4. 로그 아카이브
```bash
mv .hxsk/.rationalization-patterns.log \
   .hxsk/memories/pattern-discovery/rationalization-$(date +%Y%m%d).log
: > .hxsk/.rationalization-patterns.log
```

### 5. 스킬 TDD 재검증 (선택)
업스트림 PR이라면 `skill-testing` 스킬로 갱신된 합리화 테이블이 실제로 새 패턴을 차단하는지 검증.
