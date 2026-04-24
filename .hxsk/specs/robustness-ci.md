# Robustness CI — SPEC

## Goals
- 스킬 강인성을 CI에서 자동으로 검증
- RED(위반 관찰) → GREEN(준수 확인) 사이클 자동 실행
- 합리화 탐지율 측정 및 추적

## Scope
포함: 22개 스킬 대상 압박 시나리오 라이브러리, skill-testing SKILL.md의 4가지 시나리오 타입, 자동 RED/GREEN 판정, 결과 리포트
제외: 직접 LLM API 호출, 스킬 내용 자동 수정

### 압박 시나리오 타입 (4가지)
1. 시간 압박 (time pressure)
2. 매몰 비용 (sunk cost)
3. 모호한 완료 기준 (ambiguous completion)
4. 복합 압박 (3+ 조합)

## Done Criteria
- [ ] `bash .hxsk/scripts/run-skill-test.sh <skill>` → RED/GREEN 출력
- [ ] 결과 `.hxsk/reports/skill-test-YYYY-MM-DD.md` 저장
- [ ] GitHub Actions `.github/workflows/skill-test.yml` 실행 가능
- [ ] 22개 스킬 중 최소 5개 시나리오 라이브러리 완비

## Constraints
- 외부 LLM API 직접 호출 금지 (Claude Code 서브에이전트 경유만)
- 스킬당 테스트 실행 30초 이내
- .hxsk/skills/ 파일 직접 수정 금지

## Open Questions
- CI 환경에서 서브에이전트 headless 실행 가능 여부
- RED 판정: 패턴 매칭 vs LLM 판정 방식 선택
