# Code Standards & Conventions

> HExoskeleton 리포의 코드·문서 작성 표준. 신규 컨트리뷰터는 이 문서를 먼저 읽는다.

## 1. Iron Laws (절대 원칙)

이 세 규칙은 `AGENTS.md`에 명시된 **bright-line rules**다. 에이전트든 인간이든 우회 불가.

### 1.1 NO EDIT WITHOUT READ FIRST
파일을 읽지 않고 수정하지 않는다. 추측 금지.
- Edit/Write 전 반드시 `Read` 도구로 파일 전체를 읽는다.
- 훅이 이를 강제한다 (`post-turn-verify.sh`).

### 1.2 NO COMPLETION WITHOUT VERIFICATION
검증 증거 없이 완료를 선언하지 않는다.
- "잘 되는 것 같다", "아마 동작할 것"은 증거가 아니다.
- 실제 명령 실행 결과 또는 테스트 통과만 증거로 인정한다.
- `empirical-validation` skill이 게이트 역할.

### 1.3 NO WRITE TO EXISTING FILES
기존 파일 수정은 `Edit` 도구를 사용한다. `Write`는 새 파일 전용.
- `Write`는 기존 파일을 완전히 덮어쓴다 → 의도치 않은 손실 위험.

## 2. Agent Boundaries

### 2.1 Always
- 변경 전 **파일 검색 기반 impact analysis**
- **SPEC.md 읽고** 구현 시작
- **경험적으로 검증** — 명령 실행 결과로 증명

### 2.2 Ask First
- 외부 종속성 추가
- 태스크 범위 외 파일 삭제
- 3+ 모듈에 영향을 미치는 아키텍처 결정

### 2.3 Never
- `.env` 또는 자격증명 파일 읽기/출력
- 하드코딩된 시크릿/API 키 커밋
- `--dangerously-skip-permissions` 사용 (Claude Code 전용)
- 실패 테스트를 "나중에 고치기"로 건너뛰기

## 3. Execution Constraints

### 3.1 3-Strike Rule
동일 접근이 3회 연속 실패 시 **반드시** 전환한다.
- `context-health-monitor`, `debugger` skill이 이를 추적.
- 3회 실패 시: STOP → 상태 덤프 → 새 세션 재시작 권장.

### 3.2 Atomic Commit
태스크당 하나의 커밋. 논리적 단위 유지.
- `commit` skill이 diff를 분석하여 자동 분리.
- 커밋 메시지 형식: `<type>(<scope>): <subject>` (아래 4.2절 참조).

### 3.3 No PLAN, No EXECUTE
PLAN.md 없이 구현 시작 금지.
- `plan-checker` skill이 6차원 검증 통과 후에만 `executor` 진입.

### 3.4 No Parallel Without Ownership
파일 소유권 선언 없이 병렬 작업 금지.
- PLAN.md 각 task는 `files:` 필드 필수.
- 같은 wave 태스크는 파일 중복 불가.

## 4. Commit Message Convention

### 4.1 형식
```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

### 4.2 Type
| type | 용도 | 이모지 |
|------|------|--------|
| `feat` | 신규 기능 | ✨ |
| `fix` | 버그 수정 | 🐛 |
| `docs` | 문서만 변경 | 📝 |
| `refactor` | 기능 변화 없는 구조 개선 | ♻️ |
| `chore` | 빌드·의존성·설정 | 🔧 |
| `test` | 테스트 추가/수정 | ✅ |
| `perf` | 성능 개선 | ⚡ |
| `revert` | 이전 커밋 되돌리기 | ⏪ |

### 4.3 Scope
- 모듈명, 스킬명, 훅명 등
- 예: `feat(skill/executor): ...`, `fix(hooks): ...`, `docs(setup): ...`

### 4.4 Atomic Commit 예시 (HXSK 실제 히스토리):
```
0fff8d7 docs(setup): 3분기 감지 + 업그레이드 섹션 + 하네스 부록 (v5.5.0 정렬) (#135)
9318dc2 feat(memory): 하네스 독립 prune + 임계치 5 + 전 local-tier cap (v5.5.0) (#134)
eef848e chore(release): v5.4.0 — Git Forge + lessons-learned + 메모리 티어 최적화 (#133)
```

## 5. Document Hierarchy

3-tier 계층이 토큰 예산을 최적화한다:

| Level | 파일 | 크기 제약 | 로드 시점 |
|-------|------|---------|---------|
| **L1** | `CLAUDE.md`, `AGENTS.md`, `GEMINI.md` | ≤120 lines | 항상 로드 |
| **L2** | `.hxsk/skills/*/SKILL.md`, `.hxsk/docs/*.md` | 100~300 lines | 스킬 로드/참조 |
| **L3** | `.hxsk/research/*/RESEARCH-*.md` | 제한 없음 | On-demand 참조만 |

### 5.1 L1 규칙
- 포함: 검색 순서, 트리거, 제약
- 제외: 예시, 포맷, 스키마
- ≤120 lines 강제

### 5.2 Skill/Agent 규칙
- Agent body ≤ 20-30 lines — 상세는 Skill 위임
- Skill Quick Reference ≤ 5 lines
- 기존 패턴 참조 (DRY)

### 5.3 PATTERNS.md 규칙
- ≤ 2KB / 20 items
- 초과 시 `compact-context.sh`가 오래된 항목을 프룬

## 6. Shell Script Standards

### 6.1 Shebang + 호환성
```bash
#!/usr/bin/env bash
# bash ≥3.2 호환 (macOS 기본 bash 포함)
# ⚠️ #!/bin/bash 사용 금지 — env를 통한 경로 독립 shebang이 표준
```
- **`[[ ]]` OK**, but **`declare -g` 금지** (bash 4+ 전용)
- **associative arrays 금지** (bash 4+)
- **POSIX 호환 우선**, bash 확장은 필요 시에만

### 6.2 Error Handling
```bash
set -eu
set -o pipefail       # pipe 체인 에러 전파
```

### 6.3 Linting
- **shellcheck** CLEAN 상태 유지 (`make check` 또는 `clean` skill)
- **shfmt** 포맷 적용
- `qlty` 설치 시 통합 실행

### 6.4 Path Handling
- **절대 경로**: `${CLAUDE_PROJECT_DIR:-.}`로 시작
- **심볼릭 링크**: `scripts/md-*.sh`는 `.hxsk/hooks/`의 링크 (빌드 시 치환)
- **never hardcode `.hxsk/hooks/` in build scripts** — 플러그인 배포 시 경로 다름

### 6.5 JSON 파싱
```bash
source "${DIR}/_json_parse.sh"
# jq → python3 → node 폴백 체인
```

### 6.6 YAML Injection 방지 (`yaml_safe()` 패턴)
YAML frontmatter에 사용자 제공 값을 삽입할 때는 반드시 `yaml_safe()`로 sanitize한다:
```bash
yaml_safe() {
    # 줄바꿈/CR 제거, 큰따옴표 이스케이프
    printf '%s' "$1" | tr -d '\n\r' | sed 's/"/\\"/g'
}
# 사용 예
title=$(yaml_safe "$raw_title")
printf 'title: "%s"\n' "$title" >> "$MEMORY_FILE"
```
- YAML 스칼라 값은 삽입 전 newline·CR 제거 필수
- `"` 문자는 `\"` 이스케이프 필수
- `md-store-memory.sh`의 구현을 참조

### 6.7 Atomic Flag Claim (race condition 방지)
두 프로세스가 동일한 플래그 파일을 경쟁할 수 있는 경우 `mv` atomic rename을 사용:
```bash
# ❌ Wrong — TOCTOU race condition
if [ -f "$FLAG_FILE" ]; then
    rm "$FLAG_FILE"
    # do work
fi

# ✅ Correct — atomic claim
CLAIMED="$FLAG_FILE.$$"
if mv "$FLAG_FILE" "$CLAIMED" 2>/dev/null; then
    rm -f "$CLAIMED"
    # do work (이 프로세스만 진입)
fi
```

### 6.8 Shell-Executable Config 소싱 보안
외부 config 파일을 `source`(`.`)로 실행할 때는 반드시 소유권과 권한을 검증한다:
```bash
# .prune-config 등 shell-sourceable config 소싱 전 검증
if [ -f "$CONFIG" ]; then
    # 소유자 검증: 현재 사용자 소유가 아니면 거부
    if ! [ -O "$CONFIG" ]; then
        echo "WARN: $CONFIG not owned by current user — skipping" >&2
    # 권한 검증: 그룹/월드 쓰기 가능이면 거부
    elif [ $(( $(stat -c '%a' "$CONFIG" 2>/dev/null || stat -f '%OLp' "$CONFIG") & 022 )) -ne 0 ]; then
        echo "WARN: $CONFIG is group/world-writable — skipping" >&2
    else
        # shellcheck source=/dev/null
        source "$CONFIG"
    fi
fi
```

## 7. Markdown Standards

### 7.1 Frontmatter (YAML)
메모리, 스킬, 템플릿 모두 YAML frontmatter 사용:
```yaml
---
name: skill-name
description: "CSO-optimized trigger text"
trigger: "한글 트리거 + English trigger"
allowed-tools: [Read, Write, Edit, Bash, Grep, Glob, Agent]
version: 1.0.0
---
```

### 7.2 CSO (Claude Search Optimization)
Skill description은 **트리거 조건만** 담는다:
- ✅ "Use when storing or retrieving project knowledge, after architecture decisions"
- ❌ "This skill helps you manage memory through a workflow of storing and retrieving..." (워크플로우 요약 금지)

이유: Claude가 description을 읽고 스킬을 선택하면 body를 건너뛸 수 있음.

### 7.3 Link Conventions
- 상대 링크만 사용: `[System Architecture](system-architecture.md)`
- 섹션 앵커: `[See 3.4](#34-no-parallel-without-ownership)`
- 외부 링크: 웹뷰어가 여는 GitHub/MDN URL만

### 7.4 doc-lint 규칙
`doc-lint.sh`가 다음을 검증:
- **LINK-01**: Broken internal links
- **LINK-02**: Broken anchor links
- **INDEX-01**: INDEX.md와 실제 파일 카운트 일치
- **REF-01**: 중복 파일명 참조
- **ORPHAN-01**: INDEX에 없는 .md 파일

## 8. Issue & PR Conventions

### 8.1 Issue 번호 규칙
- 파일 기반 이슈: `.hxsk/issues/MASTER-NNN.md` (부모) + `WORK-NNN.md` (하위)
- GitHub 이슈: 자동 번호 (`gh issue create`)

### 8.2 PR 제목
```
<type>(<scope>): <subject>

예:
feat(skill/dispatcher): 서브에이전트 프롬프트 외부 펜스 4-backtick
fix(agent-workflow): 코드 리뷰 반영 — recall 인자 오류, 테이블 prefix 누락
```

### 8.3 PR 본문 필수 섹션
- **Summary**: 1-3 bullet
- **Test plan**: 체크리스트
- **Closes**: `Closes #N`

### 8.4 Pre-PR Check
`pre-pr-check.sh`가 검증:
- 버전 일관성 (llms.txt, .bootstrap-version, CHANGELOG)
- CHANGELOG 업데이트 확인
- doc-lint 통과
- 릴리스 노트 완전성

## 9. Memory Storage Conventions

### 9.1 언제 저장하는가 (Storage Triggers)
- 아키텍처 결정 시 → `architecture-decision` 타입
- 버그 근본 원인 발견 → `root-cause`
- 반복 패턴 발견 → `pattern-discovery`
- 실행 완료 → `execution-summary`
- 세션 종료 → `session-summary` (자동, Stop 훅)
- PR 리뷰 이탈 발견 → `lessons-learned/{A|B|C|D|E}` 카테고리

### 9.2 A-Mem 필드 필수
```yaml
---
name: concise-title
type: root-cause
keywords: [specific, terms, for-grep]
contextual_description: "이 메모리가 언제 유용한지 ≤200자"
related: [relevant-slug-1, relevant-slug-2]
tags: [value-tag-if-important]   # decision, root-cause, incident 등
---
```

### 9.3 Nemori Dedup
동일 title/slug는 자동 스킵. 업데이트하려면 명시적 조정 필요.

### 9.4 lessons-learned 카테고리 (A-E)
PR/실행 이탈 시 분류:
- **A**: SPEC/PLAN 누락
- **B**: 검증 건너뜀
- **C**: 의사소통/핸드오프 문제
- **D**: 기술 선택 오판
- **E**: 프로세스 역행

## 10. Forge Platform Abstraction

GitHub에 국한되지 않도록 모든 Git 워크플로우 스크립트는 `forge-detect.sh`를 source 한다:

```bash
source .hxsk/scripts/forge-detect.sh
# FORGE_CMD가 gh / glab / tea 중 하나로 자동 설정됨
```

지원 플랫폼:
- GitHub → `gh` CLI
- GitLab → `glab` CLI
- Gitea/Forgejo → `tea` CLI

## 11. Python Script Standards (훅 전용)

Python은 **시스템 내장 `python3`만 사용**. pip 의존성 추가 금지.

```python
#!/usr/bin/env python3
# Standard library only. No `pip install`.
```

적용 파일:
- `.hxsk/hooks/_json_parse.sh` 폴백 (python3 -c '...')
- 기타 JSON 파싱/검증 유틸

## 12. Sizing Budget Summary

| 아티팩트 | 최대 크기 | 근거 |
|---------|---------|------|
| CLAUDE.md | 120 lines | L1 경량 |
| GEMINI.md | 120 lines | L1 경량 |
| AGENTS.md | 120 lines | 하네스 공용 |
| Skill Quick Reference | 5 lines | Description에서 본문 진입 유도 |
| Skill body | 100~300 lines | CSO + 프로시저 |
| Agent | 20~30 lines | When/With What만 |
| PATTERNS.md | 2KB / 20 items | 핵심 휴리스틱만 |
| contextual_description | 200 chars | 메모리 요약 |
| Commit message subject | 72 chars | Git 관례 |

## 13. Review Checklists

### Pre-Commit
- [ ] 파일을 Read 후 Edit 했는가?
- [ ] 검증 명령을 실행했는가? 통과했는가?
- [ ] 커밋 단위가 원자적인가? (단일 논리 변경)
- [ ] 시크릿/자격증명이 없는가?
- [ ] doc-lint 통과하는가?

### Pre-PR
- [ ] `pre-pr-check.sh` 통과?
- [ ] 버전 sync (llms.txt, bootstrap-version, CHANGELOG)?
- [ ] Self-review 완료?
- [ ] A-Mem 메모리 저장 필요 항목 처리?

### Pre-Merge
- [ ] `verifier` skill로 SPEC.md 대조 검증?
- [ ] 모든 sub-issue closed?
- [ ] CI 녹색?

## See Also

- [Project Overview](project-overview-pdr.md)
- [System Architecture](system-architecture.md)
- [Testing Guide](testing-guide.md) — lint/검증 상세
- [Configuration Guide](configuration-guide.md) — 설정 키
- `.hxsk/docs/CONVENTIONS.md` — 내부 심화 컨벤션
- `.hxsk/docs/DESIGN-PHILOSOPHY.md` — 9원칙 상세
