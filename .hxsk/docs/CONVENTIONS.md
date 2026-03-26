# Development Conventions

> **핵심 원칙: 1 Issue = 1 목적 = 1 PR**
>
> 하나의 이슈는 하나의 명확한 변경 목적만 가져야 하며, 그에 대응하는 PR도 하나여야 한다.
> 리뷰어가 30분 안에 리뷰할 수 있는 크기를 목표로 한다.

---

## 1. Repository 초기 설정

### 1.1 Repository 생성 체크리스트

| 항목 | 설정 |
|------|------|
| Visibility | Private (기본) 또는 Public |
| `.gitignore` | 언어/프레임워크에 맞게 선택 |
| License | MIT (기본) 또는 프로젝트에 맞게 |
| README.md | 생성 |

### 1.2 브랜치 전략

| 브랜치 | 역할 | 보호 규칙 |
|--------|------|----------|
| `main` | 프로덕션 릴리즈 | PR 필수, merge commit만 허용 |
| `develop` | 개발 통합 | PR 필수, squash merge |
| `feature/*` | 기능 개발 | - |
| `bugfix/*` | 버그 수정 | - |
| `release/*` | 릴리즈 준비 | (선택) |
| `feat/master-{id}` | Dispatcher v2 이슈 브랜치 | - |
| `feat/master-{id}/work-{seq}` | Dispatcher v2 워크트리 브랜치 | - |

**Default Branch**: `develop` (또는 프로젝트 정책에 따라 `main`)

> **Dispatcher v2**: 병렬 작업 시 `MASTER-{id}.md` → `WORK-{id}-{seq}.md` 문서로 관리.
> 이슈 문서는 `.hxsk/issues/`에 저장 (git-untracked). 완료 후 `archive/`로 이동.

> **간소화 옵션**: 소규모 프로젝트는 `main` + feature branch만으로 운영 가능.

### 1.3 Branch Protection Rules

```
main:
  - Require pull request before merging
  - Require status checks to pass
  - No force push
  - No deletion

develop:
  - Require pull request before merging
  - Allow squash merge only
```

### 1.4 환경 변수 관리

| 파일 | 용도 | Git 추적 |
|------|------|----------|
| `.env` | 실제 시크릿 값 | **추적 안함** (`.gitignore`) |
| `.env.example` | 키 이름 + 더미 값 공유 | 추적 |

```bash
# .env.example
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
API_KEY=your-api-key-here
```

### 1.5 Pre-commit 설정

프로젝트 루트에 `.pre-commit-config.yaml`을 생성하고 언어별 린터/포매터를 등록한다.

**공통 훅 (언어 무관)**:

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
        args: [--markdown-linebreak-ext=md]
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-added-large-files
        args: ['--maxkb=500']
```

**언어별 린터 예시**:

| 언어 | 린터/포매터 | pre-commit repo |
|------|-----------|-----------------|
| Python | ruff | `astral-sh/ruff-pre-commit` |
| JavaScript/TypeScript | eslint + prettier | `pre-commit/mirrors-eslint` |
| Go | gofmt + golangci-lint | `golangci/golangci-lint` |
| Shell | shellcheck + shfmt | `shellcheck-py/shellcheck-py` |

```bash
# 설치
pre-commit install
```

---

## 2. Issue 컨벤션

### 2.1 제목 형식

```
[Type] 대상 - 구체적 행위
```

| Type | 용도 | 예시 |
|------|------|------|
| `Bug` | 버그 수정 | `[Bug] UserService - login 시 세션 만료 체크 누락` |
| `Feature` | 신규 기능 | `[Feature] Dashboard - 실시간 알림 위젯 추가` |
| `Enhancement` | 구조 개선 | `[Enhancement] AuthModule - JWT 검증 로직을 미들웨어로 분리` |

**나쁜 예시** (금지):
- `"스키마 수정"` — 뭘 하겠다는 건지 모름
- `"여러 버그 수정"` — 이슈를 분리해야 함
- `"성능 개선"` — 대상과 행위가 없음

### 2.2 본문 필수 항목

#### Done Criteria (완료 조건)

모든 이슈에 **체크리스트 형태**로 작성한다. **3개를 넘으면 이슈 분리를 검토**한다.

```markdown
## Done Criteria
- [ ] login 호출 시 세션 만료 여부를 먼저 확인
- [ ] 만료된 세션에 대해 401 응답 반환
- [ ] 관련 테스트 통과
```

#### Context (배경/맥락)

```markdown
## Context
현재 UserService.login()이 세션 만료 여부를 체크하지 않아
만료된 세션으로도 API 호출이 가능한 상태입니다.

## 영향 범위
- UserService: login, validateSession
- AuthMiddleware: tokenVerify
```

### 2.3 이슈 분리 기준

> **원칙: 변경 목적이 다르면 이슈를 분리한다**

| 상황 | 분리 여부 | 이유 |
|------|----------|------|
| 버그 수정 중 리팩토링이 필요해진 경우 | **분리** | 버그 수정과 구조 개선은 목적이 다름 |
| 기능 추가 시 관련 테스트 작성 | 같이 | 기능과 테스트는 하나의 완성 단위 |
| 리팩토링 중 새로운 버그 발견 | **분리** | 발견된 버그는 별도 이슈로 추적 |
| A 모듈 수정이 B 모듈을 선행 조건으로 요구 | **분리 후 의존 관계 명시** | `blocked by #N`으로 연결 |

**분리 예시** — 하나의 이슈로 시작했지만 분리가 필요한 경우:

| 이슈 | Type | 내용 | 예상 PR 크기 |
|------|------|------|-------------|
| #10 | Bug | session 만료 체크 누락 수정 | ~200 lines |
| #11 | Enhancement | AuthMiddleware를 별도 모듈로 분리 | ~400 lines |
| #12 | Feature | 세션 갱신 API 추가 | ~300 lines |

---

## 3. Branch 컨벤션

### 3.1 브랜치 생성

GitHub Issue 화면의 **Development > Create a branch** 기능을 사용한다.

```
{prefix}/{issue-number}-{간결한-설명}
```

| Prefix | 용도 | 예시 |
|--------|------|------|
| `feature/` | 신규 기능 | `feature/42-realtime-notification` |
| `bugfix/` | 버그 수정 | `bugfix/38-session-expiry-check` |
| `docs/` | 문서 변경 | `docs/45-api-documentation` |
| `refactor/` | 구조 개선 | `refactor/50-auth-middleware-split` |
| `release/` | 릴리즈 준비 | `release/v1.2.0` |

**규칙**:
- 이슈 번호를 반드시 포함
- 브랜치명이 길면 핵심 키워드로 축약 (이슈 번호로 추적 가능하므로)
- 영문 소문자 + 하이픈만 사용

### 3.2 로컬 브랜치 정리

머지 완료 후 로컬 브랜치를 삭제한다.

```bash
# develop(또는 main)으로 이동
git checkout develop
git pull

# 원격에서 삭제된 브랜치 반영
git fetch -p

# 로컬 브랜치 삭제
git branch -D feature/42-realtime-notification
```

---

## 4. Commit 컨벤션

### 4.1 메시지 형식

```
{type}({scope}): {description}

Resolved #{issue-number}
```

| Type | 용도 | 예시 |
|------|------|------|
| `feat` | 신규 기능 | `feat(auth): JWT 기반 인증 미들웨어 추가` |
| `fix` | 버그 수정 | `fix(session): 만료된 세션 체크 로직 추가` |
| `refactor` | 리팩토링 | `refactor(api): 라우터 구조를 모듈별로 분리` |
| `docs` | 문서 | `docs(readme): API 엔드포인트 목록 추가` |
| `test` | 테스트 | `test(auth): login 실패 케이스 테스트 추가` |
| `chore` | 빌드/설정 | `chore(deps): express 4.18 → 4.19 업데이트` |
| `style` | 포맷팅 | `style(lint): 들여쓰기 수정` |
| `perf` | 성능 개선 | `perf(query): N+1 쿼리 제거` |
| `ci` | CI/CD | `ci(github): PR 자동 라벨링 추가` |

**규칙**:
- 제목은 **50자 이내**, 본문은 72자 줄바꿈
- 제목은 **명령형**으로 작성 (한국어: `~추가`, `~수정`, `~제거`)
- 이슈를 닫는 커밋에는 `Resolved #N` 포함
- scope는 선택 사항이나 변경 대상이 명확하면 기재

**예시**:

```bash
git commit -m "$(cat <<'EOF'
fix(session): 만료된 세션으로 API 호출 가능한 문제 수정

UserService.login()에서 세션 만료 여부를 체크하지 않아
만료된 세션 토큰으로도 인증이 통과되는 문제를 수정합니다.

Resolved #38
EOF
)"
```

---

## 5. PR 컨벤션

### 5.1 크기 가이드라인

| 크기 | 프로덕션 코드 변경 | 리뷰 시간 | 기준 |
|------|-------------------|----------|------|
| **Small** | ~200 lines | 30분 이내 | **목표** |
| **Medium** | ~500 lines | 1시간 이내 | 허용 범위 |
| **Large** | ~1,000 lines | 반나절 | 분리 검토 필요 |
| **XLarge** | 1,000+ lines | 하루 이상 | **반드시 분리** |

> 테스트 코드는 라인 수 비중을 낮게 본다. 핵심은 프로덕션 코드 변경량.
> 단, 테스트 포함 총 변경이 1,000줄을 넘으면 분리를 검토한다.

### 5.2 PR 생성 전 자가 점검

- [ ] 이 PR에 **변경 목적이 2개 이상** 포함되어 있지 않은가?
- [ ] 프로덕션 코드 변경이 **500줄을 넘지 않는가**?
- [ ] "이것도 같이 고치면 좋겠다"는 생각으로 **범위를 넓히지 않았는가**?
- [ ] PR 설명만 읽고도 **왜 이 변경이 필요한지** 이해할 수 있는가?
- [ ] 이슈의 **Done Criteria를 모두 충족**하는가?

### 5.3 Merge 전략

| 상황 | Merge 방식 | 이유 |
|------|-----------|------|
| feature/bugfix → develop | **Squash and merge** | 커밋 히스토리 깔끔하게 유지 |
| develop → main (릴리즈) | **Merge commit** | 릴리즈 히스토리 보존 |
| hotfix → main | **Merge commit** | 긴급 수정 추적 |

### 5.4 PR 머지 후 처리

1. GitHub에서 소스 브랜치 삭제 (자동 설정 권장)
2. 로컬 브랜치 정리 (`git fetch -p` → `git branch -D`)

### 5.5 리뷰 중 발견된 문제 처리

> **핵심 규칙: 리뷰 중 발견된 새로운 문제는 별도 이슈로 등록한다**
>
> 현재 PR에서 같이 고치려 하면 PR이 점점 커지는 악순환이 발생한다.

| 발견된 문제 유형 | 처리 방법 |
|-----------------|----------|
| 현재 PR 변경사항의 **직접적인 버그** | 현재 PR에서 수정 |
| 기존 코드의 **구조적 문제** 발견 | **새 이슈 등록** → 코멘트에 이슈 번호 링크 |
| "이것도 같이 개선하면 좋겠다" | **새 이슈 등록** → 현재 PR에서는 하지 않음 |
| 리뷰어의 설계 개선 제안 | **새 이슈 등록** → 다음 스프린트에서 검토 |

**코멘트 예시**:

```markdown
> 이 부분 캡슐화가 깨지는 문제가 있습니다.
> → #72 로 별도 추적합니다.
```

---

## 6. 릴리즈 컨벤션

### 6.1 버전 체계

[Semantic Versioning](https://semver.org/) 을 따른다.

```
v{MAJOR}.{MINOR}.{PATCH}
```

| 변경 유형 | 버전 증가 | 예시 |
|----------|----------|------|
| 하위 호환 깨지는 변경 | MAJOR | `v1.0.0 → v2.0.0` |
| 신규 기능 (하위 호환 유지) | MINOR | `v1.0.0 → v1.1.0` |
| 버그 수정 | PATCH | `v1.0.0 → v1.0.1` |

### 6.2 릴리즈 절차

#### 자동 릴리즈 (권장)

`release-please` 또는 유사 도구를 사용하여 자동화한다.

```
feat: commit → push → Release PR 자동 생성 → merge → 자동 릴리즈 + 태깅
```

#### 수동 릴리즈

1. 릴리즈 이슈 생성: `Release v1.2.0`
2. develop에서 버전 정보 업데이트 (package.json, pyproject.toml 등)
3. develop → main PR 생성 (**Merge commit** 사용)
4. 태깅 및 GitHub Release 생성:

```bash
git checkout main
git pull
git tag v1.2.0
git push origin v1.2.0
```

5. GitHub Releases에서 해당 태그로 릴리즈 노트 작성

### 6.3 릴리즈 커밋 메시지

```
chore(release): v1.2.0
```

---

## 7. 요약 — Quick Reference

| 항목 | 규칙 |
|------|------|
| **이슈 단위** | 1 이슈 = 1 변경 목적 (Bug / Feature / Enhancement) |
| **이슈 제목** | `[Type] 대상 - 구체적 행위` |
| **완료 조건** | 체크리스트 3개 이내, 넘으면 분리 검토 |
| **브랜치명** | `{prefix}/{issue-number}-{설명}` |
| **커밋 메시지** | `{type}({scope}): {description}` (conventional commits) |
| **PR 크기** | 프로덕션 코드 500줄 이내 (목표 200줄) |
| **PR Merge** | feature→develop: squash, develop→main: merge commit |
| **리뷰 중 발견** | 직접 버그만 현재 PR에서 수정, 나머지는 새 이슈 |
| **버전** | Semantic Versioning (`vMAJOR.MINOR.PATCH`) |
| **환경 변수** | `.env` (gitignore) + `.env.example` (추적) |
