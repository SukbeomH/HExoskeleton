# HExoskeleton (HXSK) — 기여자 가이드

> HXSK **자체를 개발**할 때의 지침이다. HXSK를 다른 프로젝트에서 쓰는 방법은 [README.md](README.md).

## 저장소 구조

저장소 루트가 곧 Claude Code 플러그인 `hxsk`이자 마켓플레이스 `hexoskeleton`이다 (`.claude-plugin/`).

- `skills/` — Agent Skills. `.agents/skills`는 이 디렉터리를 가리키는 심볼릭 링크(Claude 외 하네스용)
- `agents/` — 서브에이전트 정의
- `hooks/` — `hooks.json` + 훅 스크립트 ([docs/HOOKS.md](docs/HOOKS.md))
- `hermes/` — Hermes Agent 플러그인: Hermes 도구 호출을 Claude 훅 JSON으로 바꿔 `hooks/` 스크립트를 실행한다 (README "Hermes Agent", `tests/hermes-plugin.py`)
- `scripts/` — `init-project.sh`(프로젝트 `.hxsk/` 생성), `verify.sh`(검증 단일 진입점) 등
- `templates/` — `.hxsk/` 스캐폴드 (PLAN·SUMMARY·DEBUG·RESEARCH 같은 작업 문서 형식은 그 문서를 쓰는 스킬의 `references/`에 있다)
- `tests/` — 회귀 테스트 (`verify.sh`가 전부 실행)
- `docs/` — 설계 철학, 훅, 게이트 관례

## 개발 흐름

1. `scripts/init-project.sh .` — 이 저장소용 로컬 작업 상태 `.hxsk/`를 만든다 (gitignore, 커밋하지 않음). 이 저장소 작업의 SPEC/STATE/SESSION_HANDOFF/VERIFICATION은 여기에 둔다.
2. `claude --plugin-dir .` — 작업 트리를 플러그인으로 로드해 스킬(`/hxsk:<skill>`)·에이전트·훅을 바로 시험한다.
3. SPEC → PLAN → EXECUTE → VERIFY. PLAN 없이 EXECUTE 하지 않는다 (작은 단일 수정은 응답 안의 짧은 계획으로 충분).
4. `bash scripts/verify.sh` — 커밋 전 전부 PASS. CI(`.github/workflows/pr-check.yml`)도 같은 스크립트를 실행한다.

세션 시작 시 `.hxsk/SESSION_HANDOFF.md`와 `.hxsk/STATE.md`가 있으면 먼저 읽는다 (Claude Code에서는 session-start 훅이 주입).

## 스킬·에이전트·훅 편집 규칙

- **frontmatter는 Agent Skills 스펙 키만**: `name`(= 디렉터리명, kebab-case, ≤64자), `description`(무엇을 하는지 + 언제 쓰는지, ≤1024자), `license`, `compatibility`, `metadata`, `allowed-tools`. Claude 전용 키는 쓰지 않는다. `scripts/check-skills.py`가 검사한다.
- **self-contained**: 스킬 안의 경로(`scripts/…`, `references/…`)는 그 스킬 디렉터리 기준 상대경로, 다른 스킬은 `../<skill>/…`. 저장소 루트 경로나 `.hxsk/` 안의 프레임워크 파일에 의존하지 않는다. 예외는 `hxsk-init`의 `${CLAUDE_PLUGIN_ROOT}` (비 Claude 폴백 포함).
- **길이**: SKILL.md ≤500줄(스펙). Quick Reference ≤5줄, 상세는 `references/`로 분리.
- **에이전트**: `agents/*.md`의 `skills:`는 접두어 없는 스킬 이름.
- **훅**: `.hxsk/` 상태를 읽거나 쓰는 훅은 `.hxsk/`가 없으면 아무것도 하지 않고 exit 0. 차단은 exit 2 + stderr. 변경 시 `tests/hooks-smoke.sh`에 `.hxsk/` 유무 두 경우를 넣는다.
- **런타임**: bash와 python3 표준 라이브러리만. 스크립트에서는 `python3`(not `python`).
- **문서**: 컴포넌트 개수·버전 번호를 본문에 쓰지 않는다. 파일시스템을 복제하는 목록을 만들지 않는다.
- **릴리스**: 버전은 `.claude-plugin/plugin.json`의 `version`(같은 값을 `hermes/plugin.yaml`에도, `tests/hermes-plugin.py`가 검사)과 `CHANGELOG.md`에만 둔다. `version`을 올려야 설치된 사용자가 업데이트를 받는다. `marketplace.json` 항목에는 `version`을 넣지 않는다.

## Validation

검증은 경험적 증거 기반이다. "잘 되는 것 같다"는 증거가 아니다.

### Iron Laws
- `NO EDIT WITHOUT READ FIRST` — 파일을 읽지 않고 수정하지 않는다
- `NO COMPLETION WITHOUT VERIFICATION` — 검증 증거 없이 완료를 선언하지 않는다
- `NO WRITE TO EXISTING FILES` — 기존 파일 수정은 Edit. Write는 새 파일 전용

- **결과 우선**: 기능 동작 확인 후 스타일 수정
- **실패 전수 보고**: 모든 실패를 모아 보고
- **조건부 성공**: 실제 결과를 확인한 뒤에만 성공을 출력
- **3-Strike Rule**: 같은 접근이 3회 연속 실패하면 접근을 바꾼다

## 커밋·브랜치

- [skills/commit/references/CONVENTIONS.md](skills/commit/references/CONVENTIONS.md)를 따른다. Conventional prefix + 한국어 설명.
- 태스크당 하나의 커밋(atomic). PR 없이 `master`에 직접 머지하지 않는다.
- 병렬 작업은 1 branch = 1 worktree = 1 active writer. 병렬화 전에 파일 소유권을 나눈다.

## 메모리

`.hxsk/memories/`에 타입별 마크다운으로 저장한다 (이 저장소에서는 로컬 전용). 상세: [skills/memory-protocol/SKILL.md](skills/memory-protocol/SKILL.md).

```bash
# 검색
bash skills/memory-protocol/scripts/md-recall-memory.sh "<query>" . 5 compact
# 저장 — type 은 skills/memory-protocol/references/type-relations.yaml 에 정의된 값만
bash skills/memory-protocol/scripts/md-store-memory.sh "<title>" "<content>" "<tag1,tag2>" <type>
```

저장 시점: 아키텍처 결정, 버그 근본 원인, 재사용 패턴, 세션 종료. PR 리뷰·실행 이탈에서 얻은 교훈은 `lessons-learned/<A-E 카테고리>` 타입(예: `lessons-learned/B-test-quality`).

## 게이트

이슈·PR 기반 큰 작업의 진입/완료 조건은 [docs/GATES.md](docs/GATES.md)의 관례를 따른다. 어떤 훅도 집행하지 않는다.

## Agent Boundaries

### Always
- 리팩터링·삭제 전 파일 검색 기반 영향 분석
- 구현 전 `.hxsk/SPEC.md` 확인
- 명령 실행 결과로 검증

### Ask First
- 외부 의존성 추가
- 태스크 범위 밖 파일 삭제
- 3개 이상 모듈에 영향을 주는 아키텍처 결정

### Never
- `.env`·자격 증명 파일 읽기/출력
- 하드코딩된 시크릿·API 키 커밋
- 실패하는 테스트를 "나중에 고치려고" 건너뛰기
- `/autoresearch`를 `Iterations: N` 없이 실행 (unbounded 루프 금지)
