# RESEARCH: LLM 에이전트에게 제공할 Bash CLI 도구 조사

> **Date**: 2026-01-30
> **Purpose**: LLM 에이전트가 bash 환경에서 활용할 수 있는 CLI 도구를 조사하고, 현재 프로젝트에 적용 가능한 도구를 선별

---

## 1. 핵심 인사이트: 왜 Bash 도구인가?

LLM은 `grep`, `cat`, `find`, `awk` 등을 인간보다 훨씬 많이 학습했다. Unix 도구는 **텍스트 입력 → 텍스트 출력** 패턴이라 LLM과 궁합이 좋고, 별도 tool schema 정의 없이도 bash 하나로 수백 개 도구에 접근 가능하다.

- Vercel은 복잡한 커스텀 도구를 bash+filesystem으로 교체한 결과 **비용 75% 절감 + 품질 향상** 달성
- MCP 서버가 많아지면 tool 정의만으로 컨텍스트 윈도우를 소모하는 문제 발생
- Unix 도구는 battle-tested — `git`, `grep`, `curl`, `jq`는 수십 년간 프로덕션에서 검증됨

---

## 2. 카테고리별 도구 목록

### 2.1 파일 탐색 & 검색

| 도구 | 대체 대상 | LLM 제공 이유 | 설치 |
|------|-----------|---------------|------|
| **ripgrep (`rg`)** | `grep` | `.gitignore` 자동 인식, `--json` 구조화 출력, grep 대비 10x 빠름. Claude Code 내부에서도 사용 | `brew install ripgrep` |
| **fd** | `find` | 직관적 문법, `.gitignore` 인식, `--json` 출력 지원 | `brew install fd` |
| **tree** | `ls -R` | 프로젝트 구조를 한눈에 파악. `-L` depth 제한으로 토큰 절약 | `brew install tree` |
| **fzf** | 수동 필터링 | 파이프라인에서 대량 결과 필터링. `--filter` 모드로 비대화형 사용 가능 | `brew install fzf` |

### 2.2 구조화 데이터 처리

| 도구 | 대상 포맷 | LLM 제공 이유 | 설치 |
|------|-----------|---------------|------|
| **jq** | JSON | API 응답, 설정 파일, MCP 메시지 처리에 필수. LLM이 jq 쿼리 생성에 능숙 | `brew install jq` |
| **yq** | YAML/XML | jq 문법으로 YAML 조작. CI/CD 설정, k8s manifest 편집 | `brew install yq` |
| **dasel** | JSON/YAML/TOML/CSV/XML | 하나의 문법으로 다양한 포맷 통합 처리. `pyproject.toml` 편집에 유용 | `brew install dasel` |
| **csvkit** | CSV | `csvgrep`, `csvjoin`, `csvsql` 등 CSV 전용 도구 세트 | `brew install csvkit` |

### 2.3 텍스트 변환 & 처리

| 도구 | 용도 | LLM 제공 이유 | 설치 |
|------|------|---------------|------|
| **sed** | 스트림 편집 | 파일 내용 치환/삭제. LLM 학습 데이터에 풍부 | 내장 |
| **awk** | 패턴 기반 텍스트 처리 | 컬럼 추출, 집계, 포맷 변환. 구조화 텍스트에 강력 | 내장 |
| **bat** | 파일 읽기 (구문 강조) | 줄번호 포함 출력으로 위치 기반 편집 지시에 유용 | `brew install bat` |
| **delta** | 변경 비교 | 구문 인식 diff. Git pager 설정 가능 | `brew install git-delta` |
| **envsubst** | 템플릿 변수 치환 | 환경 변수 기반 설정 파일 생성 | `brew install gettext` |

### 2.4 Git 작업

| 도구 | 용도 | LLM 제공 이유 | 설치 |
|------|------|---------------|------|
| **git** | 버전 관리 전체 | `diff`, `log`, `blame`, `show` 등으로 코드 히스토리/컨텍스트 파악 | 내장 |
| **gh** | GitHub API | PR/이슈 생성, CI 상태 확인, 코드 리뷰. REST API 대체 | `brew install gh` |
| **git-cliff** | 체인지로그 생성 | conventional commit에서 자동 CHANGELOG 생성 | `brew install git-cliff` |

### 2.5 HTTP & API 통신

| 도구 | 용도 | LLM 제공 이유 | 설치 |
|------|------|---------------|------|
| **curl** | HTTP 요청 | 범용 API 호출. LLM 학습 데이터에 가장 풍부 | 내장 |
| **httpie (`http`)** | 가독성 높은 HTTP | 출력 자동 포매팅, 직관적 문법 | `brew install httpie` |
| **xh** | httpie 호환 (Rust) | httpie와 같은 문법, 더 빠른 실행 | `brew install xh` |

### 2.6 시스템 & 프로세스

| 도구 | 용도 | LLM 제공 이유 | 설치 |
|------|------|---------------|------|
| **ps** / **procs** | 프로세스 확인 | 실행 중인 서비스 확인, 포트 충돌 진단 | 내장 / `brew install procs` |
| **lsof** | 열린 파일/포트 확인 | 포트 사용 확인, 파일 잠금 진단 | 내장 |
| **watch** | 주기적 명령 실행 | 빌드/테스트 상태 모니터링 | 내장 |
| **hyperfine** | 벤치마크 | 성능 비교를 통계적으로 검증. 경험적 증거 제공 | `brew install hyperfine` |

---

## 3. 도구 오케스트레이션 프레임워크

### 3.1 llm-functions (sigoden)

Bash 함수를 LLM tool로 자동 변환하는 프레임워크.

- **GitHub**: https://github.com/sigoden/llm-functions
- `@describe` 주석 기반으로 JSON tool schema 자동 생성
- MCP 서버/브릿지 지원 — 기존 도구를 MCP로 노출 가능
- AIChat CLI와 통합

```bash
# @describe 프로젝트의 TODO 항목을 검색합니다
# @option --pattern! 검색할 패턴
# @option --path 검색 경로 (기본: .)
search_todos() {
    rg --json "${argc_pattern}" "${argc_path:-.}" \
        --glob '!node_modules' --glob '!.git'
}
```

### 3.2 aichat (sigoden)

- **GitHub**: https://github.com/sigoden/aichat
- Rust 기반 올인원 LLM CLI
- Shell Assistant, RAG, Tool Calling, Agent 모드 통합
- llm-functions와 연동하여 커스텀 bash 도구를 LLM에 제공

### 3.3 Vercel bash-tool

- **Blog**: https://vercel.com/blog/how-to-build-agents-with-filesystems-and-bash
- 에이전트용 bash 실행기, 샌드박스 내 filesystem + bash로 커스텀 도구 대체
- 패턴: 파일시스템을 컨텍스트 저장소로, bash를 검색/조작 도구로 사용
- 2026-01 오픈소스 공개

### 3.4 Claude API Bash Tool

- **Docs**: https://platform.claude.com/docs/en/agents-and-tools/tool-use/bash-tool
- Claude 내장 bash 도구. 영속적 bash 세션에서 명령 실행, 상태 유지
- 샌드박스: macOS Seatbelt / Linux bubblewrap

---

## 4. 도구 제공 시 설계 원칙

### 4.1 최소 도구, 최대 조합성

커스텀 MCP 도구 100개보다 **bash + jq + rg + fd + git** 5개가 더 효과적. MCP 서버가 많아지면 tool 정의만으로 컨텍스트 윈도우를 소모한다.

### 4.2 구조화 출력 우선

`--json` 플래그 지원 도구 우선 선택 (rg, fd, gh, jq). LLM이 파싱하기 쉬운 출력 → 후속 작업 정확도 향상.

### 4.3 토큰 효율성

- `tree -L 2`로 깊이 제한
- `rg --max-count 5`로 결과 수 제한
- `bat -r 10:20 file.py`로 범위 지정 읽기

### 4.4 샌드박스 필수

- 파일시스템 격리: 작업 디렉토리만 접근 허용
- 네트워크 격리: 필요 시에만 허용
- Claude Code는 macOS Seatbelt / Linux bubblewrap 사용
- Anthropic 내부 테스트에서 샌드박스가 권한 프롬프트를 84% 감소시킴

### 4.5 Bash 함수 → Tool 변환 패턴 (llm-functions)

주석 기반으로 JSON tool schema를 자동 생성하므로, 기존 bash 스크립트를 최소 수정으로 LLM tool로 전환 가능.

---

## 5. 프로젝트 코드 대조 분석

> 총 ~3,500줄의 bash/스크립트를 분석. ~800-1,000줄(23-29%) 제거 가능.

### 5.1 HIGH PRIORITY — CLI 도구로 대체 시 즉시 효과가 큰 항목

#### `_json_parse.sh` (106줄 → ~10줄) — jq 필수화

현재 jq → python3 → node 3단 폴백 구조. jq를 필수 의존성으로 지정하면 96줄 제거.

```
현재: jq 없으면 Python으로 JSON 파싱, 그것도 없으면 Node.js
개선: jq 필수. 없으면 에러 + 설치 안내
```

#### `load-config.sh` (118줄 → ~20줄) — yq로 YAML 파싱

현재 PyYAML + grep/sed 폴백으로 YAML 파싱. yq 하나로 전체 대체.

```
현재: Python PyYAML 스크립트 40줄 + grep/sed 폴백
개선: export PROJECT_NAME=$(yq '.project.name' "$config_file")
```

#### `build-*.sh` 3개 파일 — Python JSON 조작을 jq로 대체

`build-plugin.sh`(766줄), `build-antigravity.sh`(642줄), `build-opencode.sh`(627줄)에서 Python 인라인 스크립트로 JSON 조작. 총 ~300줄 이상의 Python JSON 코드를 jq로 대체 가능.

```
현재: python3 -c "import json; ..." (10-30줄 인라인 Python)
개선: jq '.key | map(.value)' file.json
```

#### `detect-language.sh` (216줄 → ~80줄) — dasel/toml-cli로 TOML 파싱

grep으로 TOML/JSON/YAML을 파싱하는 취약한 패턴.

```
현재: grep -q "\[tool.pytest" pyproject.toml
개선: dasel -f pyproject.toml 'tool.pytest' 2>/dev/null
```

### 5.2 MEDIUM PRIORITY — 유의미한 개선

| 파일 | 현재 | 개선 | 도구 |
|------|------|------|------|
| `clean/run_quality_checks.sh` (197줄) | Python으로 JSON 결과 파싱 | `jq '.issues \| length'` | **jq** |
| `save-session-changes.sh` (141줄) | Python으로 파일 삽입, grep으로 패턴 추출 | jq + sed 단순화 | **jq** |
| `compact-context.sh` (222줄) | jq 선택적 사용 + grep/sed | jq 필수화로 통일 | **jq** |
| `bash-guard.py` (141줄) | Python에서 YAML 파싱 | yq 호출 또는 bash 전환 | **yq** |
| 다수 hooks | `_json_parse.sh` 경유 JSON 파싱 | jq 필수화로 자동 해결 | **jq** |

### 5.3 LOW PRIORITY — 있으면 좋은 개선

| 파일 | 현재 | 개선 | 도구 |
|------|------|------|------|
| `post-turn-verify.sh` | `file + grep "CRLF"` + sed 변환 | `dos2unix` 명령 하나로 | **dos2unix** |
| `organize-docs.sh` | `for file in *.md` + `ls -1 \| wc -l` | fd 패턴 매칭 | **fd** |
| `Makefile` | `grep -A2 + grep + sed` YAML 파싱 | yq 쿼리 | **yq** |

### 5.4 추가 분석: jq/yq/dasel/fd/dos2unix 외 도구

프로젝트 코드를 구체적으로 대조하여 실제 사용처가 있는 것만 선별.

#### `hyperfine` — 벤치마크 [권장]

프로젝트 검증 원칙("경험적 증거 기반")과 직접 부합.

- `run_quality_checks.sh`에서 Qlty vs Ruff 폴백 경로 성능 비교
- `make index` (code-graph-rag 인덱싱) 성능 추적
- `bootstrap.sh`의 22개 사전 검사 총 소요 측정

```bash
hyperfine --warmup 2 \
  'qlty check' \
  'uv run ruff check . && uv run mypy .'
```

#### `git-cliff` — CHANGELOG 자동 생성 [선택]

- 현재 `save-session-changes.sh`(141줄)에서 수동으로 `.gsd/CHANGELOG.md`에 엔트리 삽입
- conventional commit을 이미 사용 중이므로 릴리스 체인지로그 자동 생성 가능
- 세션 훅의 수동 요약은 유지, 릴리스용 CHANGELOG는 자동화

```bash
git-cliff --tag-pattern 'v[0-9]*' --output .gsd/CHANGELOG.md
```

#### `procs` — 프로세스 진단 [선택]

- `collect_diagnostics.sh`가 현재 Docker 컨테이너만 확인 (77-80줄)
- 로컬 dev 서버, 포트 충돌, 행 프로세스 진단 누락
- debugger 스킬 강화에 직접 기여

```bash
# collect_diagnostics.sh에 추가
procs --tree --or python node uv npm
```

#### `delta` — 구문 인식 diff [선택]

- `extract_pr_diff.sh`에서 PR diff 출력 시 구문 강조
- `build-plugin.sh`의 인프라 비교(`diff -u "$proj_path" "$ref_path"`)
- git pager 설정 한 줄로 전체 git diff 경험 개선

```bash
git config --global core.pager delta
```

### 5.5 조사했으나 불필요한 도구

| 도구 | 조사 결과 | 이유 |
|------|-----------|------|
| **xh / httpie** | `curl` 사용이 `bootstrap.sh`에 1건(설치 스크립트)뿐 | API 호출은 `gh` CLI가 담당 |
| **envsubst** | heredoc 9개 파일에서 사용 | 현재 인라인 heredoc 패턴이 빌드 스크립트에 더 적합 |
| **gum / rich-cli** | `bootstrap.sh`에서 `printf "%-20s"` 포매팅 | 현재 출력이 충분히 명확 |
| **fswatch / watchman** | 파일 감시 패턴 없음 | 테스트 러너가 이미 담당 |
| **csvkit** | CSV 데이터 없음 | JSON/YAML/TOML만 사용 |
| **Nushell** | 구조화 쉘 | 학습 곡선 대비 기존 도구 조합이 충분 |

---

## 6. 필요 도구 영향도 요약

| 순위 | 도구 | 우선도 | 영향 범위 | 핵심 근거 |
|------|------|--------|-----------|-----------|
| 1 | **jq** | 필수 | 12+ 파일, ~500줄 제거 | JSON 파싱 통일, 3단 폴백 제거 |
| 2 | **yq** | 필수 | 4-5 파일, ~100줄 제거 | YAML 파싱 통일, Python 의존 제거 |
| 3 | **dasel** | 권장 | 2-3 파일, ~50줄 제거 | TOML(pyproject.toml) 파싱 |
| 4 | **fd** | 권장 | 3-4 파일, ~20줄 제거 | 파일 탐색 개선 |
| 5 | **hyperfine** | 권장 | 품질 검사/인덱싱 벤치마크 | 검증 원칙("경험적 증거")과 직접 부합 |
| 6 | **git-cliff** | 선택 | CHANGELOG 자동화 | conventional commit 활용 |
| 7 | **procs** | 선택 | 디버거 진단 강화 | 프로세스 모니터링 보완 |
| 8 | **dos2unix** | 선택 | 1 파일, ~10줄 제거 | CRLF 처리 단순화 |
| 9 | **delta** | 선택 | diff 가독성 | git pager 설정 1줄 |

---

## 7. Sources

- [sigoden/llm-functions - Bash로 LLM 도구 생성](https://github.com/sigoden/llm-functions)
- [sigoden/aichat - 올인원 LLM CLI](https://github.com/sigoden/aichat)
- [Vercel - How to build agents with filesystems and bash](https://vercel.com/blog/how-to-build-agents-with-filesystems-and-bash)
- [Vercel Open-Sources Bash Tool (InfoQ)](https://www.infoq.com/news/2026/01/vercel-bash-tool/)
- [Claude API Bash Tool](https://platform.claude.com/docs/en/agents-and-tools/tool-use/bash-tool)
- [Anthropic - Claude Code Sandboxing](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Anthropic - Claude Code Best Practices](https://www.anthropic.com/engineering/claude-code-best-practices)
- [Why Your AI Agents Need a Shell](https://dev.to/salahpichen/why-your-ai-agents-need-a-shell-and-how-to-give-them-one-safely-3jj8)
- [AI Agents with Filesystems and Bash](https://supergok.com/ai-agents-with-filesystems-and-bash/)
- [dbohdan/structured-text-tools](https://github.com/dbohdan/structured-text-tools)
- [LLM 0.26 - Tools in your terminal](https://simonwillison.net/2025/May/27/llm-tools/)
- [12 CLI Tools That Are Redefining Developer Workflows](https://www.qodo.ai/blog/best-cli-tools/)
- [Rust CLI Tools Curated List](https://github.com/sts10/rust-command-line-utilities)
