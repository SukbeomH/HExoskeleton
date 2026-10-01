<p align="center">
  <img src="logo.png" alt="HExoskeleton" width="200" />
</p>

<h1 align="center">HExoskeleton (HXSK)</h1>

<p align="center">AI 코딩 에이전트의 외골격 — 추상화의 늪 없이, 검증된 결과물을 내는 개발 방법론.</p>

HXSK는 SPEC → PLAN → EXECUTE → VERIFY 워크플로우를 [Agent Skills](https://agentskills.io)로 제공하고, 검증 전용 서브에이전트, 위험한 동작을 막는 가드 훅, 그리고 프로젝트의 `.hxsk/`에 저장되는 파일 기반 작업 상태·메모리를 더한다. 구성 요소는 bash, python3 표준 라이브러리, 마크다운뿐이라 따로 설치할 패키지가 없다.

## 설치

### Claude Code — 플러그인 (스킬 + 에이전트 + 훅)

```text
/plugin marketplace add SukbeomH/HExoskeleton
/plugin install hxsk@hexoskeleton
```

### GitHub Copilot CLI — 플러그인

Copilot CLI는 `.claude-plugin/` 매니페스트를 읽는다고 문서화되어 있다. 아래 명령은 문서 기준이며 이 저장소에서 직접 시험하지는 않았다.

```bash
copilot plugin marketplace add SukbeomH/HExoskeleton
copilot plugin install hxsk@hexoskeleton
```

### 그 밖의 Agent Skills 호환 하네스 (Codex, Cursor 등)

```bash
git clone https://github.com/SukbeomH/HExoskeleton
HExoskeleton/scripts/init-project.sh --skills /path/to/your-project
```

스킬을 `<project>/.agents/skills/`로 복사하고, `.hxsk/`를 만들고, `AGENTS.md`에 HXSK 블록을 추가한다. 기존 파일은 덮어쓰지 않는다.

> **훅은 Claude Code 플러그인에서만 검증되어 있다.** 다른 하네스에서는 스킬과 `AGENTS.md` 지침만 동작한다고 가정한다.

## 첫 실행

Claude Code에서 `/hxsk:hxsk-init`을 실행한다(또는 "HXSK 초기화해줘"). 프로젝트에 `.hxsk/`(SPEC, STATE, VERIFICATION, 메모리 등)를 만들고 `SPEC.md` 작성을 안내한다. 상태를 기록하는 훅은 `.hxsk/`가 있는 프로젝트에서만 동작하므로, 초기화하지 않은 프로젝트에는 가드 훅만 적용된다.

`.hxsk/`에서 `SPEC.md`·`STATE.md`·`VERIFICATION.md`·`memories/`는 직접 관리하며 커밋한다. Stop 훅이 매 턴 다시 쓰는 `CURRENT.md`, 이 클론 전용 재진입 메모인 `SESSION_HANDOFF.md`(직접 또는 `handoff` 스킬로 작성), 런타임 로그는 `.hxsk/.gitignore`로 제외된다. 훅은 `STATE.md`와 `SESSION_HANDOFF.md`를 없을 때 만들기만 하고 다시 쓰지 않는다.

## 워크플로우

```text
SPEC.md (무엇을) → PLAN (어떻게) → EXECUTE (atomic commit) → VERIFY (실행 증거)
```

- `planner` → `plan-checker` → `executor` → `verifier` 스킬이 각 단계를 맡는다. 큰 작업은 `dispatcher`가 워크트리 단위로 병렬 실행한다.
- 완료 선언에는 실제로 실행한 검증 명령의 결과가 있어야 한다 (`empirical-validation`).
- 결정·근본 원인·교훈은 `memory-protocol`로 `.hxsk/memories/`에 남기고 다음 세션에서 검색한다.

## 업그레이드

- Claude Code: `claude plugin update hxsk@hexoskeleton` 후 새 세션 시작(또는 `/reload-plugins`)
- Copilot CLI: `copilot plugin update hxsk`
- 그 밖의 하네스: `git pull` 후 `scripts/init-project.sh --skills <project>` 재실행 (`.agents/skills` 복사본 갱신)

### v5.x(복사 설치)에서 옮겨오기

1. 프로젝트에서 복사본을 지운다: `.hxsk/{skills,agents,hooks,scripts,templates,adapters,githooks,prompts,docs,workflow}`, `.hxsk/memories/_schema`, `.hxsk/.bootstrap-version`, `.claude/skills`·`.claude/agents` 심볼릭 링크.
2. `.claude/settings.json`에서 `.hxsk/hooks/…`를 가리키는 `hooks` 항목을 지운다(플러그인이 대신 등록한다). Codex/Copilot 훅 파일과 `.cursorrules`·`.windsurfrules` 링크도 지운다.
3. `SPEC.md`, `STATE.md`, `VERIFICATION.md`, `memories/` 등 작업 상태는 그대로 둔다.
4. 위 설치 절차로 플러그인을 설치하고 `/hxsk:hxsk-init`을 실행한다. 기존 파일은 덮어쓰지 않는다.

## 저장소 구조

저장소 루트가 플러그인이다: `.claude-plugin/`(매니페스트), `skills/`, `agents/`, `hooks/`, `scripts/`, `templates/`(`.hxsk/` 스캐폴드), `docs/`, `tests/`. `.agents/skills`는 `skills/`를 가리키는 심볼릭 링크다.

문서: [설계 철학](docs/DESIGN-PHILOSOPHY.md) · [훅](docs/HOOKS.md) · [게이트 관례](docs/GATES.md) · [변경 이력](CHANGELOG.md)

## 개발

```bash
scripts/init-project.sh .      # 로컬 dogfood 상태 .hxsk/ (gitignore)
claude --plugin-dir .          # 작업 트리를 플러그인으로 로드
bash scripts/verify.sh         # 검증 단일 진입점 (CI와 동일)
```

기여 규칙은 [AGENTS.md](AGENTS.md)를 본다.

## 라이선스

[MIT](LICENSE)
