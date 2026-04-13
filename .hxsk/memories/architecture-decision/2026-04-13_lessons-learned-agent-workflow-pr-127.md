---
title: "lessons-learned 메모리 타입 통합 (agent-workflow PR #127)"
tags:
  - architecture-decision
  - agent-workflow
  - lessons-learned
  - pr-127
type: architecture-decision
created: 2026-04-13T07:59:53Z
contextual_description: "agent-workflow 통합: lessons-learned 메모리 타입 신규 도입, 5개 스킬 확장 (PR #127)"
keywords:
  - lessons-learned
  - cross_phase_invariants
  - agent-workflow
  - deviation
  - A-E-category
---

## lessons-learned 메모리 타입 통합 (agent-workflow PR #127)

## 결정
기존 HXSK 스킬 5개에 agent-workflow-template 4개 컴포넌트를 Approach C(신규 스크립트 없이)로 통합.
PR #127 머지 완료 (2026-04-13).

## 변경 내용
- .hxsk/memories/lessons-learned/{A~E}/ 디렉토리 신규 생성
- PLAN.md 템플릿에 cross_phase_invariants 필드 추가
- planner: Pre-Planning recall + invariants 체크리스트
- executor: Cross-Phase Invariants 파싱 + A/B/C/D/E deviation 분류
- create-pr: Pre-PR Self-Check A/B/C/D/E 블록
- pr-review: 리뷰 후 lessons-learned 저장 섹션
- dispatcher: LESSONS-LEARNED 참조 + Self-Review 표 + Ambiguity Log

## 코파일럿 리뷰 발견 (전원 타당, 수정 완료)
- md-recall-memory.sh 2번째 인자는 PROJECT_ROOT여야 함 (".") — 직접 메모리 경로 전달 시 경로 왜곡
- A/B/C/D/E 테이블 경로 lessons-learned/ prefix 누락 → general/ 폴백 위험
