# GATES.md — 작업 관리 게이트 조건

> 단일 진실 원천. GATES→Dispatcher→Sub-agent 멀티홉 워크플로우의 진입/완료 조건 정의.
> Claude Code: `gate-check.sh` 훅으로 자동 집행.
> 기타 하네스(opencode/Copilot/Antigravity): `AGENTS.md ## Task Management Gates` 참조.

---

## GATE-0: SPEC → PLAN 진입

진입 조건:
  - SPEC.md 존재
  - SPEC.md 내 `## Goals`, `## Scope` 섹션 포함

---

## GATE-P1: 계획 브랜치 생성 완료

완료 조건:
  - `feat/plan-{name}` 브랜치 존재 (`git branch --list feat/plan-*`)
  - STATE.md `## Active Gate` plan 필드에 브랜치명 기록

---

## GATE-P2: 부모 이슈 생성 완료

완료 조건:
  - STATE.md `## Active Gate` parent_issue 필드에 이슈 번호 기록
  - 이슈 존재 확인 (`gh issue view N` 또는 플랫폼 동등 명령)

---

## GATE-P3: 초안 분석 완료

완료 조건:
  - PLAN.md 태스크 분할 목록 존재 (`- [ ]` 형식, 최소 1개)
  - 각 태스크에 `files:` 필드로 파일 소유권 선언
  - 동일 파일을 2개 이상 태스크가 소유하지 않음
  - Lockfile/config 변경 태스크는 `parallel: false` 명시

---

## GATE-P4: 하위 이슈 생성 완료

완료 조건:
  - 각 태스크에 하위 이슈 번호 기록
  - STATE.md `## Active Gate` sub_issues 목록 업데이트

---

## GATE-E0: EXECUTE 진입 (Dispatcher 위임)

진입 조건:
  - GATE-P4 통과
  - 모든 태스크에 sub_issue 번호 기록
  - STATE.md `## Active Dispatcher` master 필드 설정

핸드오프 규칙 (토큰 최소화):
  - 전달: PLAN.md 경로 + 파일 소유권 맵 + 하위 이슈 번호 목록
  - 금지: 대화 내역, 이슈 내용 전문, SPEC 전문, 파일 내용

---

## GATE-E1: 태스크 PR 리뷰

진입 조건:
  - 태스크 구현 완료
  - 이슈 코멘트에 완료 내역 기록:
    ```
    STATUS: done
    COMMITS: {hash1}, {hash2}
    SELF_REVIEW: A:PASS B:PASS C:PASS D:N/A E:PASS
    DECISIONS: {내용 또는 none}
    ```

완료 조건:
  - PR approved
  - PR 본문에 `Closes #{sub-issue-number}` 포함
  - 리뷰 코멘트 전수 resolve (타당 → 적용, 불필요 → 반려 사유 코멘트)

---

## GATE-V0: VERIFY 진입

진입 조건:
  - 모든 하위 이슈 closed
  - 모든 `task/*` 브랜치 merged
  - STATE.md `## Active Dispatcher` status: done

---

## GATE-V1: 컨플릭트 해결 완료

완료 조건:
  - `feat/plan-{name}` 브랜치에서 컨플릭트 없음
  - 빌드/테스트 통과 (프로젝트 테스트 명령 기준)

---

## GATE-V2: 계획 의도 검증

완료 조건:
  - SPEC.md Goals 항목 전수 체크
  - 부모 이슈에 검증 결과 코멘트 작성
  - 미달 항목 존재 시 → 별도 이슈로 분리, 현재 플랜 종료 차단 안 함

---

## GATE-V3: 최종 리뷰

완료 조건:
  - 부모 PR approved
  - 리뷰 코멘트 전수 resolve

---

## GATE-D0: DONE 진입

진입 조건:
  - 부모 PR merged

완료 조건:
  - 결과 보고서 생성 (`.hxsk/docs/plans/{date}-{name}-result.md`)
  - 이슈 코멘트에서 핵심 결정 추출 → `md-store-memory.sh`로 저장
    ```bash
    bash .hxsk/hooks/md-store-memory.sh \
      "{플랜명} 결과" "{핵심 결정 요약}" \
      "execution,gates" "execution-summary"
    ```
  - 임시 워크트리 삭제 (`git worktree remove`)
  - `task/*` 브랜치 삭제
  - STATE.md `## Active Gate` 초기화
  - STATE.md `## Active Dispatcher` 초기화
