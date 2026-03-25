# 플러그인 전환으로 덮어쓰기 문제 해소 가능 여부 분석

> **목적**: `RESEARCH-boilerplate-safe-apply.md`에서 식별한 기존 프로젝트 덮어쓰기 문제를 `RESEARCH-plugin-feasibility.md`의 플러그인 접근으로 해소할 수 있는지 교차 분석
> **날짜**: 2026-01-28

---

## 1. 파일별 충돌 해소 여부 매트릭스

안전 적용 보고서에서 식별한 12개 충돌 항목을 플러그인 전환 시 해소 여부로 평가한다.

### 1.1 해소되는 항목 (5/12)

| 파일 | 기존 위험도 | 플러그인 방식 | 해소 메커니즘 |
|------|-----------|-------------|-------------|
| `.claude/skills/` | LOW | `plugin/skills/` | 네임스페이스 격리 (`/gsd:commit`). 프로젝트의 `.claude/skills/`와 충돌 없음 |
| `.claude/agents/` | LOW | `plugin/agents/` | 네임스페이스 격리. 프로젝트의 에이전트와 공존 |
| `.agent/workflows/` | LOW | `plugin/commands/` | 네임스페이스 격리 (`/gsd:plan`). 프로젝트의 워크플로우와 충돌 없음 |
| `.claude/settings.json` | **MEDIUM** | `plugin/hooks/hooks.json` | 훅이 플러그인 내부에 캡슐화. 프로젝트의 `settings.json`을 건드리지 않음 |
| `.mcp.json` | **HIGH** | `plugin/.mcp.json` | 플러그인 시스템이 MCP 서버 설정을 **병합** 처리 (덮어쓰기 아님) |

### 1.2 해소되지 않는 항목 (7/12)

| 파일 | 기존 위험도 | 플러그인에서 불가능한 이유 | 여전히 필요한 대안 |
|------|-----------|------------------------|------------------|
| `pyproject.toml` | **HIGH** | 플러그인 시스템 범위 밖 (Python 프로젝트 설정) | Deep merge 또는 수동 병합 |
| `Makefile` | **HIGH** | 플러그인 시스템 범위 밖 (빌드 시스템) | `Makefile.boilerplate` + include 패턴 |
| `.gitignore` | **HIGH** | 플러그인 시스템 범위 밖 (Git 설정) | Append 병합 |
| `.github/workflows/ci.yml` | **HIGH** | 플러그인 시스템 범위 밖 (CI/CD) | 수동 병합 |
| `.vscode/settings.json` | **MEDIUM** | 플러그인 시스템 범위 밖 (IDE 설정) | 수동 병합 |
| `tests/conftest.py` | **MEDIUM** | 플러그인 시스템 범위 밖 (테스트 코드) | 수동 병합 |
| `.gsd/` 문서 체계 | LOW | 플러그인은 런타임 문서 생성/관리 불가 | scaffolding 커맨드 (`/gsd:init`) |

### 1.3 요약 스코어보드

```
HIGH 위험도 5개 중 해소: 1개 (.mcp.json)           → 해소율 20%
MEDIUM 위험도 3개 중 해소: 1개 (.claude/settings.json) → 해소율 33%
LOW 위험도 4개 중 해소: 3개                         → 해소율 75%

전체 12개 중 해소: 5개                              → 전체 해소율 42%
```

---

## 2. 플러그인이 해소하는 것의 의미

### 2.1 네임스페이스 격리 — 가장 큰 기여

플러그인의 핵심 가치는 **네임스페이스 격리**다. 기존 프로젝트가 자체 `.claude/skills/commit/`을 가지고 있어도, 플러그인의 `/gsd:commit`은 완전히 별도 공간에 존재한다.

```
기존 프로젝트                    플러그인 (캐시)
.claude/                        ~/.claude/plugins/gsd/
├── skills/commit/SKILL.md      ├── skills/commit/SKILL.md
├── agents/executor.md          ├── agents/executor.md
└── settings.json               └── hooks/hooks.json
     ↑ 독립                          ↑ 독립
```

이것은 **안전 적용 보고서의 LOW 위험도 항목들을 근본적으로 제거**한다. `rsync --ignore-existing` 같은 방어적 복사가 필요 없어진다.

### 2.2 MCP 서버 병합 — 유일하게 HIGH를 해소

`.mcp.json`은 플러그인 시스템이 프로젝트의 기존 MCP 설정에 플러그인의 서버를 **추가**하는 방식으로 동작한다. 기존 `graph-code` 서버가 있어도 플러그인 것과 공존한다.

단, **경로 문제**가 존재한다:

```json
// 플러그인의 .mcp.json
"graph-code": { "args": ["-y", "@er77/code-graph-rag-mcp", "."] }
//                                                          ↑ 이 "."는 어디?
```

플러그인이 캐시에 설치되면 `"."`는 캐시 디렉토리를 가리킨다. `graph-code`는 **프로젝트 루트**를 인덱싱해야 하므로 `${CLAUDE_PROJECT_DIR:-.}`로 변경 필요. 이 문제는 플러그인 보고서 Section 5.4에서도 식별되어 있다.

### 2.3 훅 캡슐화

기존 방식에서는 `.claude/settings.json`에 훅을 직접 작성해야 하므로, 프로젝트가 이미 자체 훅을 가지고 있으면 **병합 충돌**이 발생했다. 플러그인은 `hooks/hooks.json`이 독립적으로 로드되므로 이 문제가 사라진다.

---

## 3. 플러그인이 해소하지 못하는 것의 심각성

### 3.1 HIGH 위험도 4개가 그대로 남음

플러그인 전환의 가장 큰 한계는 **프로젝트 인프라 파일**을 건드릴 수 없다는 것이다:

| 파일 | 왜 플러그인으로 불가능한가 | 영향 |
|------|------------------------|------|
| `pyproject.toml` | Python 빌드 시스템이 인식하는 프로젝트 설정. 플러그인 시스템과 무관 | ruff/mypy/pytest 규칙을 수동으로 추가해야 함 |
| `Makefile` | OS 레벨 빌드 시스템. 플러그인 시스템과 무관 | `make setup`, `make index` 등 20+ 타겟 수동 통합 |
| `.gitignore` | Git 설정. 플러그인 시스템과 무관 | `.code-graph-rag/`, `vectors.db` 등 패턴 수동 추가 |
| `ci.yml` | GitHub Actions. 플러그인 시스템과 무관 | CI 파이프라인 수동 통합 |

이 4개 파일이 안전 적용 보고서에서 **가장 파괴적인 충돌 원인**이었고, 플러그인 전환으로도 해결되지 않는다.

### 3.2 .gsd/ 문서 체계 — 구조적 한계

보일러플레이트의 핵심 가치 중 하나인 GSD 문서 체계(SPEC.md, PLAN.md, STATE.md, templates/)는 플러그인에 포함할 수 없다. 29개 워크플로우가 `.gsd/` 파일을 직접 참조하기 때문에:

```markdown
<!-- .agent/workflows/plan.md 내부 -->
Read `.gsd/SPEC.md` and create a phased plan in `.gsd/PLAN.md`
```

플러그인 커맨드(`/gsd:plan`)가 실행될 때 프로젝트에 `.gsd/SPEC.md`가 없으면 실패한다. 이를 해결하려면 `/gsd:init` 커맨드로 **사전 scaffolding**이 필수인데, 이것 자체가 파일을 프로젝트에 생성하는 행위이므로 **덮어쓰기 문제가 다시 발생**한다.

---

## 4. 플러그인 전환이 새로 만드는 문제

안전 적용 보고서에는 없었지만, 플러그인 전환 시 **새롭게 발생**하는 문제들:

### 4.1 네임스페이스 사용성 저하

```
Standalone:  /commit, /plan, /verify, /clean
Plugin:      /gsd:commit, /gsd:plan, /gsd:verify, /gsd:clean
```

매일 사용하는 커맨드에 접두사가 붙는다. 이름을 `gsd`로 줄여도 타이핑량이 증가한다.

### 4.2 MCP 서버 경로 문제 (신규 HIGH 리스크)

`graph-code`와 `memorygraph`는 **프로젝트 디렉토리의 데이터**에 접근해야 한다:
- `graph-code`: 프로젝트 코드를 AST 파싱하여 `.code-graph-rag/` SQLite에 저장
- `memorygraph`: `vectors.db`를 프로젝트 루트에 생성

플러그인은 캐시에 복사되므로, 이 서버들이 올바른 프로젝트 경로를 참조하도록 `${CLAUDE_PROJECT_DIR}` 환경 변수에 의존해야 한다. 이 변수가 지원되지 않는 환경에서는 동작하지 않는다.

### 4.3 이중 유지보수 부담

Standalone과 Plugin을 병행하면 ~90개 파일의 동기화가 필요하다. 심볼릭 링크나 빌드 스크립트로 완화할 수 있지만, 본질적으로 두 배의 유지보수 비용이 발생한다.

### 4.4 Permission 설정 미포함

`.claude/settings.local.json`의 `permissions` 블록은 플러그인에서 제어 불가. 사용자가 매번 권한을 수동으로 승인하거나 별도 설정해야 한다.

---

## 5. 정량 비교: 플러그인 vs 안전 적용 스크립트

| 평가 기준 | 플러그인 | 안전 적용 스크립트 (`apply-boilerplate.sh`) |
|----------|---------|---------------------------------------|
| **HIGH 위험도 해소** | 1/5 (20%) | 5/5 (100% — 수동+자동 병합) |
| **MEDIUM 위험도 해소** | 1/3 (33%) | 3/3 (100%) |
| **LOW 위험도 해소** | 3/4 (75%) | 4/4 (100%) |
| **전체 해소율** | **42%** | **100%** (단, 수동 개입 필요) |
| **설치 편의성** | `claude plugin install` (1 커맨드) | 스크립트 실행 + 수동 병합 |
| **업데이트** | `/plugin update` (자동) | git pull + 재실행 (수동) |
| **프로젝트 파일 오염** | 없음 (캐시 격리) | 있음 (파일 수정) |
| **네임스페이스 충돌** | 없음 (격리) | 가능 (동일 경로) |
| **GSD 문서 체계** | 별도 scaffolding 필요 | 직접 설치 |
| **MCP 경로 안정성** | 환경 변수 의존 (리스크) | 직접 참조 (안정) |
| **초기 구축 비용** | ~90파일 변환 (높음) | ~1 스크립트 작성 (낮음) |
| **유지보수 비용** | 이중 유지보수 (높음) | 단일 소스 (낮음) |

---

## 6. 결론

### 6.1 핵심 판정

> **플러그인 전환만으로는 덮어쓰기 문제의 42%만 해소된다.**
> 가장 파괴적인 HIGH 위험도 파일 5개 중 4개(`pyproject.toml`, `Makefile`, `.gitignore`, `ci.yml`)는 플러그인 시스템의 범위 밖이므로 여전히 별도 병합 전략이 필요하다.

### 6.2 플러그인이 효과적인 영역

플러그인은 **Claude Code 내부 컴포넌트**(Skills, Agents, Hooks, MCP, Commands)의 충돌을 근본적으로 제거한다. 이것은 네임스페이스 격리라는 구조적 해결이므로, 셸 스크립트의 방어적 복사(`rsync --ignore-existing`)보다 안전하다.

### 6.3 플러그인이 무력한 영역

프로젝트 인프라 파일(`pyproject.toml`, `Makefile`, `.gitignore`, CI, IDE 설정, 테스트)은 플러그인 시스템과 완전히 독립적인 영역이다. 이 파일들은 어떤 방식이든 **프로젝트 측에서 직접 처리**해야 한다.

### 6.4 권장 전략: 하이브리드

**Plugin + Scaffolding 이원 구조**가 가장 현실적이다:

```
┌─────────────────────────────────────────────────────────────┐
│                    사용자 프로젝트                            │
│                                                             │
│  ┌──── 플러그인이 담당 (42%) ──────────────────────┐        │
│  │ Skills (14), Agents (13), Hooks (4+)           │        │
│  │ MCP Servers (3), Commands (29)                 │        │
│  │ → `claude plugin install gsd`                  │        │
│  └────────────────────────────────────────────────┘        │
│                                                             │
│  ┌──── Scaffolding이 담당 (58%) ──────────────────┐        │
│  │ pyproject.toml → deep merge                    │        │
│  │ Makefile       → include 패턴                   │        │
│  │ .gitignore     → append                        │        │
│  │ .gsd/          → /gsd:init 커맨드               │        │
│  │ ci.yml         → 수동 병합 가이드               │        │
│  │ .vscode/       → 수동 병합 가이드               │        │
│  │ tests/         → 수동 병합 가이드               │        │
│  │ → `apply-boilerplate.sh` 또는 Copier           │        │
│  └────────────────────────────────────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**실행 순서:**
1. `claude plugin install gsd` — Claude Code 컴포넌트 설치 (충돌 0%)
2. `/gsd:init` — `.gsd/` 문서 체계 scaffolding (신규 생성, 충돌 없음)
3. `apply-boilerplate.sh` — 인프라 파일 안전 병합 (충돌 시 가이드 출력)

이 순서로 진행하면:
- Step 1에서 Skills/Agents/Hooks/MCP/Commands는 네임스페이스 격리로 충돌 0
- Step 2에서 `.gsd/`는 신규 디렉토리이므로 대부분 충돌 없음
- Step 3에서 남은 인프라 파일만 선택적으로 병합

**단일 접근법의 해소율 42%를 하이브리드로 ~95%까지 끌어올릴 수 있다.** 나머지 5%는 `ci.yml`, `.vscode/settings.json` 등 프로젝트별 편차가 큰 파일의 수동 병합이다.
