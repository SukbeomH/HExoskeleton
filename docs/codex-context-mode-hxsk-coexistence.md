# Codex + context-mode + HXSK 공존 가이드

이 문서는 **전역 Codex 설정에 context-mode를 붙인 상태**에서, **repo-local HExoskeleton(HXSK)** 을 함께 운영할 때의 우선순위와 병합 규칙을 정리합니다.

## 1. 문제 정의

Codex에는 이미 다음 두 층이 동시에 존재할 수 있습니다.

1. **전역 Codex 층**
   - `~/.codex/config.toml`
   - `~/.codex/hooks.json`
   - `~/.codex/AGENTS.md`
   - context-mode MCP / hook / compaction continuity

2. **repo-local HXSK 층**
   - `AGENTS.md`
   - `llms.txt`
   - `.hxsk/`
   - `.hxsk/githooks/`
   - `.hxsk/adapters/codex-hooks.json`

둘을 아무 기준 없이 섞으면 다음 문제가 생깁니다.
- 전역 hooks와 repo-local hooks가 서로 덮어씀
- 세션 continuity는 전역에서 관리되는데, repo 검증/기억 규칙은 로컬에 있어 소스 오브 트루스가 갈라짐
- Codex가 context-mode 규칙은 읽지만 HXSK current/state/verification surface는 놓침

따라서 **전역은 context plumbing**, **repo-local은 작업 의미와 검증 규칙**으로 분리하는 것이 핵심입니다.

## 2. 권장 책임 분리

### 전역 Codex / context-mode가 담당할 것
- MCP 등록
- 세션 continuity / compaction continuity
- Codex 전반 공통 hook 라우팅
- repo 비특화 AGENTS include

### HXSK repo-local이 담당할 것
- read order
- canonical active-state surface
- file ownership discipline
- verification command
- repo-specific memory / pattern / decisions
- git-hook fallback

한 줄 원칙:
- **context-mode = 전역 인프라 계층**
- **HXSK = repo 의미 계층**

## 3. 우선순위

실제 운영 우선순위는 아래와 같습니다.

1. **repo-local source of truth**
   - `llms.txt`
   - `AGENTS.md`
   - `.hxsk/CURRENT.md`
   - `.hxsk/STATE.md`
   - `.hxsk/VERIFICATION.md`

2. **repo-local verification / git-hook fallback**
   - `.hxsk/scripts/*`
   - `.hxsk/githooks/*`
   - `.hxsk/adapters/codex-hooks.json`

3. **전역 Codex context plumbing**
   - `~/.codex/config.toml`
   - `~/.codex/hooks.json`
   - `~/.codex/context-mode.AGENTS.md`

의미:
- 작업 방식, 파일 해석, 완료 판정은 repo-local 규칙이 우선
- context-mode는 그 작업을 더 오래, 더 안정적으로 이어 주는 하부 계층

## 4. Read Order

Codex가 HXSK repo에 진입하면 다음 순서로 읽는 것을 권장합니다.

1. `llms.txt`
2. `AGENTS.md`
3. `.hxsk/CURRENT.md`
4. `.hxsk/STATE.md`
5. `.hxsk/VERIFICATION.md`
6. 필요 시 `.hxsk/DECISIONS.md`, `.hxsk/PATTERNS.md`, `.hxsk/docs/plans/`

이 순서를 전역 context-mode AGENTS보다 **의미 계층에서 우선**합니다.

## 5. Hook Coexistence Rules

## 기본 원칙
- 전역 `~/.codex/hooks.json`은 유지
- repo-local HXSK는 문서 surface + git-hook fallback 우선
- repo-local hook이 꼭 필요할 때만 Stop 단계에 병합
- 어느 한쪽을 지우고 대체하지 말고 **chain/merge** 를 기본으로 함

## 권장 패턴 A — 가장 단순한 운영
- 전역: `context-mode` hook 유지
- 로컬: `AGENTS.md`, `.hxsk/`, `.hxsk/githooks/pre-push`
- 추가 로컬 Codex Stop hook 없음

언제 쓰나:
- repo-local verify는 수동 실행 또는 git hook으로 충분할 때

장점:
- 충돌 최소
- 전역 설정 단순

## 권장 패턴 B — Stop hook 병합
전역 Stop hook 뒤에 HXSK prune/verify를 체인으로 연결합니다.

예시 개념:
```bash
context-mode hook codex stop && bash .hxsk/scripts/prune-memories.sh --auto
```

또는 더 엄격하게:
```bash
context-mode hook codex stop \
  && bash .hxsk/scripts/prune-memories.sh --auto \
  && bash .hxsk/scripts/doc-lint.sh
```

언제 쓰나:
- 세션 종료 시 HXSK side-effect를 자동으로 남기고 싶을 때

주의:
- Stop hook에서 무거운 검증을 너무 많이 걸면 종료 지연이 커질 수 있음
- 로컬 훅은 repo 존재를 전제로 하므로 전역 훅에서 cwd 안전성 확인 필요

## 6. Memory Split

### context-mode / Codex 쪽에 기대하는 것
- 긴 세션 continuity
- compact 후 이어가기
- 툴 출력 관리

### HXSK 쪽에 남겨야 하는 것
- repo-specific decisions
- root cause
- lessons learned
- verification evidence
- reusable patterns

즉,
- **세션 지속성은 context-mode가 돕고**
- **프로젝트 지식의 SSOT는 HXSK가 가진다**

## 7. Verification Discipline

context-mode가 잘 붙어 있어도 완료 판정은 바뀌지 않습니다.

반드시 repo-local 기준으로 검증합니다.

우선 후보:
```bash
bash .hxsk/scripts/local-verify.sh
```

문서 중심 변경이면:
```bash
bash .hxsk/scripts/doc-lint.sh
bash .hxsk/hooks/check-consistency.sh
```

원칙:
- context-mode 성공 ≠ 작업 완료
- HXSK verification evidence 확보 = 완료 판정 근거

## 8. 추천 운영 레시피

### 일상 운영
1. 전역 Codex는 context-mode 유지
2. repo 진입 시 `llms.txt` / `AGENTS.md` / `CURRENT.md` / `STATE.md` / `VERIFICATION.md` 읽기
3. 구현 중 repo-local plans / decisions / patterns 우선
4. 완료 전 HXSK verify 실행
5. 필요 시 Stop hook 또는 git hook으로 후처리

### 안전한 기본값
- 전역 `context-mode` 유지
- HXSK는 문서 + git hook fallback 중심
- repo-local Codex hooks는 최소화

## 9. Anti-Patterns

피해야 할 것:
- 전역 `hooks.json`을 repo마다 통째로 덮어쓰기
- repo-local verification 없이 context-mode continuity만 믿고 완료 선언
- `CURRENT.md` / `STATE.md` / `VERIFICATION.md`를 건너뛰고 바로 구현
- repo-specific memory를 전역 Codex/Hermes 메모리에만 남기기

## 10. 요약

가장 중요한 규칙은 하나입니다.

> **context-mode는 Codex 세션을 오래 안정적으로 유지하는 전역 인프라이고, HXSK는 해당 repo의 작업 의미·검증·기억 표면을 정의하는 로컬 운영 체계입니다.**

따라서 둘은 경쟁 관계가 아니라 계층 분리 관계로 운영해야 합니다.
