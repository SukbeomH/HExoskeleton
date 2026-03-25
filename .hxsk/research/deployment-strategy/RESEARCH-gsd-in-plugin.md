# .gsd/ 문서 체계의 플러그인 내장 가능성 분석

> **출처**: https://code.claude.com/docs/ko/plugins, /plugins-reference, /skills, /hooks
> **날짜**: 2026-01-28

---

## 1. 결론 요약

| 항목 | 판정 |
|------|------|
| .gsd/ **템플릿**을 플러그인에 내장 | **가능** — 플러그인 캐시에 포함되어 `${CLAUDE_PLUGIN_ROOT}`로 접근 |
| .gsd/ **작업 문서**를 플러그인 내부에서 운용 | **불가** — 워크플로우가 참조하는 `.gsd/SPEC.md` 등은 프로젝트 루트에 있어야 함 |
| 플러그인이 프로젝트에 .gsd/ 자동 생성 | **가능** — 스킬/커맨드/훅을 통해 프로젝트 디렉토리에 파일 생성 가능 |
| 설치 시 자동으로 .gsd/ 배포 | **불가** — 설치 후 라이프사이클 훅이 없음. SessionStart 훅으로 대체 가능 |

**핵심**: 플러그인은 .gsd/ 템플릿의 **운반체(carrier)** 역할을 할 수 있고, 스킬/훅을 통해 프로젝트에 **자동 배포**할 수 있다. 다만 "설치만 하면 끝"이 아니라 **한 번의 초기화 동작**이 필요하다.

---

## 2. 공식 문서에서 확인된 핵심 사실

### 2.1 플러그인 캐싱 메커니즘

> "플러그인을 설치하면 Claude Code는 플러그인 파일을 캐시 디렉토리에 복사합니다."
> — plugins-reference#플러그인-캐싱-및-파일-해석

플러그인 디렉토리 전체가 재귀적으로 캐시에 복사된다. 즉 **임의의 파일/디렉토리도 포함 가능**하다. 표준 레이아웃에서 명시된 디렉토리(`commands/`, `agents/`, `skills/`, `hooks/`, `scripts/`) 외에도 추가 디렉토리를 포함할 수 있다.

```
gsd-plugin/
├── .claude-plugin/plugin.json
├── skills/
├── commands/
├── templates/              ← 비표준이지만 캐시에 포함됨
│   ├── gsd/
│   │   ├── spec.md
│   │   ├── plan.md
│   │   ├── state.md
│   │   ├── decisions.md
│   │   └── ...
│   ├── CLAUDE.md.template
│   └── Makefile.template
└── scripts/
```

### 2.2 환경 변수

| 변수 | 의미 | 사용 가능한 곳 |
|------|------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | 플러그인 캐시 디렉토리의 절대 경로 | hooks, MCP 서버, scripts |
| `${CLAUDE_PROJECT_DIR}` | 프로젝트 루트 디렉토리의 절대 경로 | hooks, scripts |
| `${CLAUDE_SESSION_ID}` | 현재 세션 ID | 스킬 콘텐츠 내 |

**두 변수의 조합**으로 "플러그인 내부 템플릿 → 프로젝트 디렉토리"로의 파일 복사가 가능하다.

### 2.3 스킬의 파일 접근 능력

> "스킬은 디렉토리에 여러 파일을 포함할 수 있습니다."
> — skills#지원-파일-추가

```
my-skill/
├── SKILL.md           # 주요 지침 (필수)
├── template.md        # Claude가 작성할 템플릿
├── examples/
│   └── sample.md      # 예상 형식을 보여주는 예제 출력
└── scripts/
    └── validate.sh    # Claude가 실행할 수 있는 스크립트
```

스킬은 `allowed-tools` 필드로 `Read`, `Write`, `Bash`, `Glob`, `Grep` 등 파일시스템 도구를 사용할 수 있다. 즉 **스킬이 프로젝트 디렉토리에 파일을 생성할 수 있다**.

### 2.4 동적 컨텍스트 주입

> "`!`command`` 구문은 기술 콘텐츠를 Claude에게 보내기 전에 셸 명령어를 실행합니다."
> — skills#동적-컨텍스트-주입

이를 활용하면 스킬 실행 시 프로젝트의 `.gsd/` 존재 여부를 사전 확인할 수 있다.

### 2.5 SessionStart 훅

> "기존 문제나 코드베이스의 최근 변경 사항과 같은 개발 컨텍스트를 로드하거나, 종속성을 설치하거나, 환경 변수를 설정하는 데 유용합니다."
> — hooks#sessionstart

SessionStart 훅은 셸 커맨드를 실행할 수 있으므로 `.gsd/` 디렉토리의 존재를 확인하고 없으면 경고 또는 자동 생성이 가능하다.

### 2.6 경로 순회 제한

> "플러그인은 복사된 디렉토리 구조 외부의 파일을 참조할 수 없습니다."
> — plugins-reference#경로-순회-제한

플러그인 내부에서 `../` 경로는 동작하지 않는다. 단, **훅과 스킬에서 실행되는 셸 명령이나 Claude의 도구 사용은 프로젝트 디렉토리에 접근 가능**하다 (이것은 플러그인 파일 참조가 아니라 런타임 도구 실행이므로).

---

## 3. .gsd/ 내장 설계

### 3.1 플러그인 내부 구조

```
gsd-plugin/
├── .claude-plugin/
│   └── plugin.json
├── commands/
│   ├── init.md                    ← /gsd:init — .gsd/ scaffolding
│   ├── plan.md                    ← /gsd:plan
│   ├── execute.md                 ← /gsd:execute
│   ├── verify.md                  ← /gsd:verify
│   └── ... (29개)
├── skills/
│   ├── bootstrap/
│   │   ├── SKILL.md               ← 프로젝트 초기화 로직
│   │   └── scripts/
│   │       └── scaffold-gsd.sh    ← .gsd/ 생성 스크립트
│   ├── planner/SKILL.md
│   ├── executor/SKILL.md
│   └── ... (14개)
├── agents/                        ← 13개 에이전트
├── hooks/
│   └── hooks.json                 ← SessionStart에서 .gsd/ 확인
├── templates/                     ← .gsd/ 템플릿 원본
│   ├── gsd/
│   │   ├── SPEC.md
│   │   ├── PLAN.md
│   │   ├── DECISIONS.md
│   │   ├── STATE.md
│   │   ├── JOURNAL.md
│   │   └── templates/             ← 30+ 문서 템플릿
│   │       ├── spec.md
│   │       ├── plan.md
│   │       ├── architecture.md
│   │       └── ...
│   ├── CLAUDE.md.template
│   ├── Makefile.boilerplate
│   └── .gitignore.append
├── .mcp.json
└── scripts/
    ├── scaffold-gsd.sh            ← .gsd/ 배포 스크립트
    ├── check-gsd.sh               ← .gsd/ 존재 확인
    └── ...
```

### 3.2 자동 배포 메커니즘 (3가지 경로)

#### 경로 A: `/gsd:init` 커맨드 (수동, 1회)

사용자가 명시적으로 실행하는 초기화 커맨드.

```yaml
# commands/init.md
---
description: 프로젝트에 GSD 문서 체계를 초기화합니다
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob
---

# GSD 프로젝트 초기화

프로젝트에 .gsd/ 문서 체계를 설정합니다.

## 사전 확인
- !`ls -d "$CLAUDE_PROJECT_DIR/.gsd" 2>/dev/null && echo "EXISTS" || echo "NOT_FOUND"`

## 작업

1. "$CLAUDE_PROJECT_DIR/.gsd/" 디렉토리가 이미 존재하는지 확인
2. 존재하지 않으면 아래 템플릿 구조를 생성:
   - 템플릿 원본: 이 플러그인의 templates/gsd/ 디렉토리 참조
   - Read 도구로 "${CLAUDE_PLUGIN_ROOT}/templates/gsd/" 내 파일들을 읽기
   - Write 도구로 "$CLAUDE_PROJECT_DIR/.gsd/"에 복사
3. 이미 존재하면 누락된 파일만 보충 (기존 파일 덮어쓰지 않음)
4. SPEC.md가 비어있으면 프로젝트 정보를 질문하여 초기 내용 작성

## 템플릿 위치
- GSD 문서: [templates/gsd/](${CLAUDE_PLUGIN_ROOT}/templates/gsd/) 참조
- CLAUDE.md 템플릿: [CLAUDE.md.template](${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template) 참조
```

#### 경로 B: SessionStart 훅 (자동 확인)

세션 시작 시 `.gsd/` 존재를 확인하고, 없으면 안내 메시지를 컨텍스트에 주입.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-gsd.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

```bash
#!/bin/bash
# scripts/check-gsd.sh
# SessionStart 훅 — .gsd/ 존재 확인 및 컨텍스트 주입

GSD_DIR="$CLAUDE_PROJECT_DIR/.gsd"

if [ ! -d "$GSD_DIR" ]; then
    echo "[GSD] .gsd/ 디렉토리가 없습니다. /gsd:init 을 실행하여 GSD 문서 체계를 초기화하세요."
    exit 0
fi

if [ ! -f "$GSD_DIR/SPEC.md" ]; then
    echo "[GSD] .gsd/SPEC.md가 없습니다. /gsd:init 을 실행하세요."
    exit 0
fi

# 정상 — STATE.md 요약을 컨텍스트에 주입
if [ -f "$GSD_DIR/STATE.md" ]; then
    echo "[GSD] 프로젝트 상태:"
    head -20 "$GSD_DIR/STATE.md"
fi

exit 0
```

SessionStart 훅의 stdout은 Claude의 컨텍스트에 추가되므로, `.gsd/STATE.md`의 요약이 세션 시작 시 자동으로 로드된다.

#### 경로 C: bootstrap 스킬 (자동, Claude 판단)

Claude가 GSD 관련 작업을 시작할 때 자동으로 `.gsd/` 존재를 확인하는 스킬.

```yaml
# skills/bootstrap/SKILL.md
---
name: gsd-bootstrap
description: >
  GSD 문서 체계의 존재를 확인하고 초기화합니다.
  프로젝트 계획, SPEC 작성, 마일스톤 관리 등 GSD 워크플로우를
  시작할 때 자동으로 사용합니다.
allowed-tools: Read, Write, Bash, Glob
---

# GSD Bootstrap

## 사전 확인
- !`test -d "$CLAUDE_PROJECT_DIR/.gsd" && echo "GSD_EXISTS" || echo "GSD_MISSING"`

## .gsd/가 없는 경우
1. 사용자에게 GSD 문서 체계 초기화를 제안
2. 동의하면 templates/gsd/ 의 파일들을 프로젝트에 복사
3. 템플릿 원본: [templates/gsd/](./../../templates/gsd/) 참조

## .gsd/가 있는 경우
1. SPEC.md, PLAN.md, STATE.md 존재 확인
2. 누락된 파일이 있으면 템플릿에서 보충
3. 기존 파일은 절대 덮어쓰지 않음
```

### 3.3 워크플로우 커맨드의 .gsd/ 참조 처리

29개 워크플로우가 `.gsd/SPEC.md`, `.gsd/PLAN.md` 등을 참조한다. 이 경로들은 **프로젝트 루트 기준 상대 경로**이므로, 플러그인 커맨드에서도 동일하게 동작한다.

```yaml
# commands/plan.md
---
description: GSD PLAN.md를 작성합니다
disable-model-invocation: true
allowed-tools: Read, Write, Bash, Glob, Grep
---

# GSD Plan 작성

## 사전 확인
- !`test -f "$CLAUDE_PROJECT_DIR/.gsd/SPEC.md" && echo "SPEC_OK" || echo "SPEC_MISSING"`

## SPEC이 없는 경우
먼저 /gsd:init 을 실행하여 프로젝트를 초기화하세요.

## 작업
1. .gsd/SPEC.md 를 읽어 요구사항 파악
2. .gsd/PLAN.md 에 단계별 실행 계획 작성
3. ...
```

`.gsd/SPEC.md` 같은 경로는 Claude가 Read/Write 도구로 접근할 때 **프로젝트 루트 기준**으로 해석되므로, 플러그인 캐시 위치와 무관하게 정상 동작한다.

---

## 4. 덮어쓰기 문제 해소 분석

이전 보고서(`RESEARCH-plugin-vs-safe-apply.md`)에서 .gsd/는 "해소 불가" 항목이었다. 플러그인 내장 + 스캐폴딩 메커니즘을 적용하면:

| 이전 판정 | 수정된 판정 | 근거 |
|----------|----------|------|
| .gsd/ 문서 체계: 플러그인 범위 밖 | **해소 가능** | 템플릿을 플러그인에 내장하고 스킬/커맨드로 안전 배포 |
| /gsd:init 실행 시 덮어쓰기 위험 | **해소** | `test -d` / `test -f` 로 존재 확인 후 누락분만 보충 |
| 워크플로우의 .gsd/ 경로 참조 | **정상 동작** | Read/Write 도구는 프로젝트 루트 기준으로 파일 접근 |

### 수정된 해소율

```
이전 전체 해소율:  5/12 = 42%
.gsd/ 해소 추가:  +1
수정된 해소율:    6/12 = 50%
```

.gsd/가 해소되더라도 `pyproject.toml`, `Makefile`, `.gitignore`, `ci.yml`, `.vscode/settings.json`, `tests/conftest.py`는 여전히 플러그인 범위 밖이다. 단, 이 중 일부는 `/gsd:init` 커맨드에서 **함께 스캐폴딩**할 수 있다:

| 파일 | /gsd:init에서 처리 가능 여부 | 방법 |
|------|------------------------|------|
| `.gitignore` | 가능 | append 방식 (기존 파일에 패턴 추가) |
| `Makefile` | 가능 | `Makefile.gsd` 생성 + include 안내 |
| `.vscode/settings.json` | 가능 | 없으면 생성, 있으면 skip |
| `pyproject.toml` | 부분적 | 의존성 추가는 `uv add` 커맨드로 가능 |
| `ci.yml` | 부분적 | 없으면 생성, 있으면 diff 출력 |
| `tests/conftest.py` | 제한적 | 없으면 생성, 있으면 skip |

`/gsd:init` 커맨드가 **스마트 스캐폴딩** (존재 확인 → 없으면 생성, 있으면 merge/skip)을 수행하면, **실질적 해소율은 ~85%까지 상승**한다.

---

## 5. 제약사항과 한계

### 5.1 "설치 즉시 동작"은 불가

공식 문서에 플러그인 설치 후 자동 실행되는 라이프사이클 훅(post-install hook)은 없다. 사용자가 최소 1회는 `/gsd:init` 또는 세션을 시작해야 한다.

**완화 방안**: SessionStart 훅으로 `.gsd/` 부재 시 안내 메시지 자동 표시.

### 5.2 템플릿 경로 접근 방식

스킬/커맨드의 마크다운 콘텐츠에서 `${CLAUDE_PLUGIN_ROOT}` 변수를 직접 사용할 수 있는지는 문서에서 명시적으로 보장하지 않는다. 확인된 변수는:
- 스킬 콘텐츠: `$ARGUMENTS`, `${CLAUDE_SESSION_ID}`, `!`command`` (동적 주입)
- 훅: `${CLAUDE_PLUGIN_ROOT}`, `${CLAUDE_PROJECT_DIR}`
- MCP: `${CLAUDE_PLUGIN_ROOT}`

스킬에서 플러그인 내부 템플릿에 접근하려면 **`!`command``를 통한 동적 주입** 또는 **상대 경로 참조**를 사용해야 한다:

```yaml
# SKILL.md 내에서
## 템플릿 참조
- 템플릿 목록: !`ls ${CLAUDE_PLUGIN_ROOT}/templates/gsd/`
- SPEC 템플릿: !`cat ${CLAUDE_PLUGIN_ROOT}/templates/gsd/SPEC.md`
```

또는 스킬의 지원 파일(supporting files) 메커니즘 사용:

```
skills/bootstrap/
├── SKILL.md
├── templates/           ← 스킬 디렉토리 내 지원 파일
│   ├── SPEC.md
│   └── PLAN.md
└── scripts/
    └── scaffold.sh
```

```yaml
# SKILL.md 내에서
## 템플릿 위치
- SPEC 템플릿: [templates/SPEC.md](templates/SPEC.md) 참조
- PLAN 템플릿: [templates/PLAN.md](templates/PLAN.md) 참조
```

### 5.3 대용량 템플릿의 컨텍스트 소비

30+ 템플릿 파일을 스킬에서 모두 로드하면 컨텍스트 예산을 초과할 수 있다.

**완화 방안**:
- `scaffold.sh` 스크립트가 파일 복사를 직접 수행 (Claude의 컨텍스트를 소비하지 않음)
- 스킬에서는 스크립트 실행만 지시, 템플릿 내용은 로드하지 않음

```bash
#!/bin/bash
# scripts/scaffold-gsd.sh
# Claude의 컨텍스트를 소비하지 않고 직접 파일 복사

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TEMPLATE_DIR="$PLUGIN_ROOT/templates/gsd"
TARGET_DIR="$PROJECT_DIR/.gsd"

mkdir -p "$TARGET_DIR" "$TARGET_DIR/templates"

# 존재하지 않는 파일만 복사
for f in "$TEMPLATE_DIR"/*.md; do
    basename=$(basename "$f")
    if [ ! -f "$TARGET_DIR/$basename" ]; then
        cp "$f" "$TARGET_DIR/$basename"
        echo "[CREATED] .gsd/$basename"
    else
        echo "[SKIP] .gsd/$basename (already exists)"
    fi
done

# templates/ 하위 디렉토리도 처리
for f in "$TEMPLATE_DIR/templates/"*.md; do
    basename=$(basename "$f")
    if [ ! -f "$TARGET_DIR/templates/$basename" ]; then
        cp "$f" "$TARGET_DIR/templates/$basename"
        echo "[CREATED] .gsd/templates/$basename"
    else
        echo "[SKIP] .gsd/templates/$basename (already exists)"
    fi
done

echo ""
echo "GSD 문서 체계 초기화 완료."
```

---

## 6. 최종 판정

| 질문 | 답변 |
|------|------|
| .gsd/ 템플릿을 플러그인에 내장 가능한가? | **가능** — 플러그인 디렉토리의 모든 파일이 캐시에 복사됨 |
| 플러그인에서 프로젝트에 .gsd/ 파일을 생성할 수 있는가? | **가능** — 스킬의 `allowed-tools: Write, Bash` + 훅의 셸 커맨드 |
| 기존 .gsd/ 파일을 덮어쓰지 않을 수 있는가? | **가능** — `test -f` 확인 후 누락분만 생성 |
| 설치 즉시 자동 배포 가능한가? | **불가** — SessionStart 훅으로 안내는 가능하나, 자동 생성은 최초 세션 시작 필요 |
| 워크플로우의 `.gsd/` 경로 참조가 정상 동작하는가? | **정상** — Claude의 Read/Write 도구는 프로젝트 루트 기준 |

**실행 가능한 최적 구조**:
1. 플러그인 내부 `templates/gsd/`에 모든 .gsd/ 템플릿 포함
2. `scripts/scaffold-gsd.sh`로 셸 수준 파일 복사 (컨텍스트 비소비)
3. `/gsd:init` 커맨드에서 스크립트 실행 + 추가 대화형 설정
4. SessionStart 훅에서 `.gsd/` 부재 시 안내 메시지 자동 주입
5. 워크플로우 커맨드에서 `!`test -f` 로 사전 확인 추가
