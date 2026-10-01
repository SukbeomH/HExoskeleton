# 합리화 테이블 갱신 가이드

> `.hxsk/.rationalization-patterns.log`에 수집된 패턴을 주기적으로 합리화 테이블에 반영하는 프로세스.

---

## 수집 경로

`collect-rationalization.sh` Stop 훅이 매 턴 에이전트 출력을 스캔하여 기록:
- 합리화 시그널 (15개 패턴) 감지 시 `DETECTED` 로그
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
`empirical-validation/SKILL.md`의 합리화 테이블에 추가:
```markdown
| {새 변명} | {현실 대응} |
```

### 4. 로그 아카이브
```bash
mv .hxsk/.rationalization-patterns.log \
   .hxsk/memories/pattern-discovery/rationalization-$(date +%Y%m%d).log
: > .hxsk/.rationalization-patterns.log
```

### 5. 스킬 TDD 재검증 (선택)
`skill-testing` 스킬로 갱신된 합리화 테이블이 실제로 새 패턴을 차단하는지 검증.
