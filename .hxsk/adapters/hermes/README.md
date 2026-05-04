# Hermes Agent Adapter

HXSK를 Hermes Agent에서 사용할 때의 **thin bridge** 문서입니다.

Hermes는 Claude Code처럼 HXSK 전용 lifecycle hook 묶음을 그대로 소비하지 않습니다. 따라서 Hermes 통합의 핵심은 **repo-local canonical surface를 먼저 읽게 하고**, Hermes의 memory / session_search / todo / delegation / cron 기능을 HXSK 규칙에 맞게 연결하는 것입니다.

## 1. Read Order (필수)

Hermes가 HXSK repo에 진입하면 아래 순서로 읽습니다.

1. `llms.txt`
2. `AGENTS.md`
3. `.hxsk/CURRENT.md`
4. `.hxsk/STATE.md`
5. `.hxsk/VERIFICATION.md`
6. 필요 시 `.hxsk/DECISIONS.md`, `.hxsk/PATTERNS.md`, `.hxsk/docs/plans/`, `.hxsk/memories/`

이 순서는 다음 원칙을 반영합니다.
- `llms.txt` = 진입 인덱스
- `AGENTS.md` = 하네스 공통 운영 규칙
- `CURRENT.md` = 현재 세션 서사
- `STATE.md` = 구조화된 현재 상태
- `VERIFICATION.md` = 검증 truth / evidence / verdict

## 2. Canonical Surface Mapping

| HXSK surface | 역할 | Hermes 대응 |
|---|---|---|
| `.hxsk/CURRENT.md` | 현재 세션 문맥 / narrative | 대화 시작 전 우선 읽기 |
| `.hxsk/STATE.md` | 현재 상태 / blockers / next checkpoint | 구조적 상태 복원 기준 |
| `.hxsk/SESSION_HANDOFF.md` | 다음 세션 재진입용 최소 handoff | `/resume` 전 빠른 진입점 |
| `.hxsk/VERIFICATION.md` | 검증 evidence / verdict | 완료 선언 전 최종 근거 |
| `.hxsk/DECISIONS.md` | 구조적 결정 기록 | 설계 변경 전 재확인 |
| `.hxsk/PATTERNS.md` | distilled learnings | 반복 실수 방지 |
| `.hxsk/TODO.md` | repo backlog | Hermes `todo`와 분리 운영 |
| `.hxsk/memories/` | canonical long-form memory | Hermes built-in memory 대신 repo SSOT |

## 3. Memory Split

### Hermes built-in memory에 저장할 것
- 사용자 선호
- 환경 사실
- stable conventions
- "이 repo의 canonical entrypoint는 llms.txt/AGENTS.md" 같은 짧은 포인터

### `.hxsk/memories/`에 저장할 것
- 세션 요약
- root cause
- lessons learned
- execution summary
- architecture / pattern / term-definition
- repo-specific 장기 판단

원칙:
- **Hermes memory = 짧은 포인터**
- **HXSK memory = repo canonical long-form store**

## 4. Recall Rules

### repo-local 판단 회수
우선:
```bash
rtk bash .hxsk/hooks/md-recall-memory.sh "<query>" "." 5 compact
```

### 과거 Hermes 대화 회수
보조:
- Hermes `session_search`

즉,
- **repo 사실 / 결정 / 패턴** → `.hxsk/memories/`
- **과거 Hermes 채팅 맥락** → `session_search`

## 5. Task Tracking Split

| 구분 | 용도 |
|---|---|
| Hermes `todo` | 현재 세션의 실행 큐 |
| `.hxsk/TODO.md` | repo backlog / follow-up |
| `.hxsk/STATE.md` | 현재 workstream 구조화 상태 |
| `.hxsk/SESSION_HANDOFF.md` | 다음 세션 재진입 메모 |

권장:
- 긴 구현 작업 중에는 Hermes `todo`를 사용
- 세션 종료 전 repo에 남길 가치가 있는 항목만 `.hxsk/TODO.md` 또는 관련 issue/plans로 승격

## 6. Delegation Rules

Hermes `delegate_task` 사용 시에도 HXSK의 다음 규칙을 유지합니다.

- PLAN 없이 EXECUTE 금지
- 파일 소유권 선언 없이 병렬 작업 금지
- repo-local verification command 우선
- 결과 요약보다 evidence/artifact 우선

실무 규칙:
1. 병렬 하위 작업 전 파일 범위를 분리
2. 하위 작업 결과는 `CURRENT.md`, `STATE.md`, `VERIFICATION.md`에 합류 가능한 형태로 수집
3. repo-local docs를 하위 세션에 직접 컨텍스트로 전달

## 7. Verification Discipline

Hermes에서 완료를 선언할 때도 HXSK acceptance는 변하지 않습니다.

- 실제 검증 명령을 실행
- 실패를 생략하지 않음
- `VERIFICATION.md` 또는 관련 artifact에 evidence 남김
- 필요 시 `SESSION_HANDOFF.md`에 다음 액션 기록

기본 검증 묶음:
```bash
bash .hxsk/scripts/local-verify.sh
```

더 좁은 문서 검증:
```bash
bash .hxsk/scripts/doc-lint.sh
bash .hxsk/hooks/check-consistency.sh
```

## 8. Recommended Closeout Pattern

세션 종료 전:
1. `.hxsk/CURRENT.md` 갱신
2. `.hxsk/STATE.md` 갱신
3. `.hxsk/SESSION_HANDOFF.md` 최소 요약 갱신
4. 필요 시 `.hxsk/VERIFICATION.md`에 evidence 추가
5. 재사용 가치가 있으면 `md-store-memory.sh`로 `.hxsk/memories/` 저장

## 9. Scope Boundary

이 문서는 Hermes를 HXSK에 맞춰 **읽고 운영하는 규칙**만 다룹니다.

다루지 않는 것:
- Hermes 글로벌 설치법
- Hermes provider/model 설정법
- Hermes 일반 기능 설명

그런 항목은 Hermes 쪽 문서/스킬에서 관리하고,
HXSK는 **repo-local source of truth**만 담당합니다.
