# Predict Analysis — 배포 프로세스 개선 연구

**Date:** 2026-04-22 14:07
**Scope:** HXSK 전체 배포 파일 + autoresearch 플러그인 + 웹 리서치
**Personas:** 8 (AR · SA · PE · RE · OM · DE · UX · DA)
**Debate Rounds:** 3
**Commit Hash:** 10f52791e66abef574dee28dd0d135e46e196394
**Anti-Herd Status:** ✅ PASSED (DA가 다수 의견의 50%+ 반박, 소수 의견 2개 보존)

---

## Summary

- **Total Findings:** 8
  - Confirmed (≥3/8): 8 | Probable (2/8): 2 | Minority (1-2/8): 1
- **Severity Breakdown:** Critical: 1 | High: 5 | Medium: 2 | Low: 0
- **Composite Score:** 156 (Excellent)
- **핵심 발견:** HXSK의 배포 개선 우선순위는 Plugin 시스템 전환(P3)이 아닌 **신뢰성 패치(P0) → 설치 자동화(P1) → 발견 가능성(P2)** 순서다

---

## Top Findings

1. [신뢰성 11건 — Silent Failure 패턴](./findings.md#finding-1) — CRITICAL | 6/8 consensus
2. [Step 6 JSON 수동 편집](./findings.md#finding-2) — HIGH | 5/8 consensus
3. [setup.md 선택/필수 단계 미분리](./findings.md#finding-3) — HIGH | 5/8 consensus
4. [SHA256 검증 없는 tarball 다운로드](./findings.md#finding-4) — HIGH | 4/8 consensus
5. [발견 가능성 부재](./findings.md#finding-5) — HIGH | 4/8 consensus

---

## autoresearch vs HXSK 배포 격차 요약

| 항목 | autoresearch | HXSK 현황 | 격차 |
|------|-------------|---------|------|
| 설치 명령 수 | 2 | 9단계 (3 필수) | 높음 |
| 설치 자동화 | 완전 자동 | Step 6 수동 JSON | 높음 |
| 업그레이드 | `/plugin marketplace update` | U1~U6 수동 | 중간 |
| 발견 가능성 | 마켓 + GitHub | llms.txt 의존 | 높음 |
| SHA 검증 | 플러그인 시스템 내장 | 없음 | 중간 |
| 로그/감사 | 플러그인 시스템 | bootstrap.sh 미저장 | 낮음 |
| 멀티 플랫폼 | scripts/install.sh | 수동 복사 | 중간 |

---

## 개선 로드맵

### Phase 0 (즉시, ~1주): 신뢰성 패치
- H-01: `bootstrap.sh` CORRUPTED 분기
- H-02: `md-store-memory.sh` mkdir -p
- H-05 일부: 릴리스 체크리스트 + SHA 생성 스크립트
- H-07: bootstrap 로그 저장

### Phase 1 (2주): 설치 자동화
- H-03: `setup.md` 필수/선택 레이블
- H-04: `install-hooks.sh --merge` 스크립트
- H-08: symlink 폴백 (cp -r)

### Phase 2 (1개월): 범용 설치 경험 개선
> HXSK는 하네스 비종속 범용 방법론 — Claude Code 전용 마켓 등록은 설계 의도에 어긋남

- H-09: `hxsk-harness-sync.sh` — 모든 하네스 어댑터 자동 감지·배포·동기화
- H-10: `scripts/install.sh` 구현 (autoresearch 방식) — `--harness cursor|gemini|copilot|...` 플래그로 **하네스별 어댑터 1-liner 설치**
- `llms.txt` 개선: 하네스별 진입 경로 명확화 (`## Claude Code`, `## Gemini CLI` 섹션 분리)
- README: 하네스 선택 Quick Decision Tree (어떤 AI 에이전트를 쓰는가? → 진입 경로)

### Phase 3 (검토): 범용 발견 가능성
> Claude Code 마켓이 아닌 **하네스 비종속 경로** 우선

- GitHub Topics 태그 (`llms-txt`, `ai-agent-framework`, `coding-agent`)
- `llms.txt` 표준 기반 — AI 에이전트가 프로젝트를 읽을 때 자동 발견
- 각 하네스별 커뮤니티(Cursor Forum, Copilot Discussions 등)에 소개
- Claude Code 플러그인은 **선택적 배포 채널** 중 하나로만 위치 (강제 아님)

---

## 소수 의견 (보존)

**DA-7**: "진짜 문제는 단계 수가 아니라 오류 처리 부재. 자동화 전에 각 단계 실패 시 복구 경로를 명시하라."
**DA-6**: "9개 하네스 지원 = Pareto 원칙 위반. 실사용 3개(Claude Code, Cursor, Copilot)에 집중하고 나머지는 커뮤니티 기여로 전환하라."

---

## Files in This Report

- [Findings](./findings.md) — 8개 우선순위 정렬
- [Hypothesis Queue](./hypothesis-queue.md) — 10개 검증 가능 가설
- [Persona Debates](./persona-debates.md) — 토론 전문
- [Codebase Analysis](./codebase-analysis.md) — 배포 파일 인벤토리
- [Dependency Map](./dependency-map.md) — 설치 플로우
- [Component Clusters](./component-clusters.md) — 클러스터 + 격차 분석
- [Handoff](./handoff.json) — 체인 핸드오프용
