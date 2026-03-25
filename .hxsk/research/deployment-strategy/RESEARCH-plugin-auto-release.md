# RESEARCH: GSD 플러그인 자동 릴리즈 워크플로우

**작성일**: 2026-01-29
**상태**: COMPLETED
**참조**:
- https://code.claude.com/docs/en/plugin-marketplaces
- https://github.com/googleapis/release-please-action
- https://semantic-release.gitbook.io/semantic-release/

**요약**: `release-please` + GitHub Actions로 gsd-plugin 디렉토리 변경 시 자동 릴리즈 구현 권장

---

## 1. Claude Code 플러그인 배포 방식

### 1.1 지원되는 배포 채널

| 채널 | 설명 | 사용 예시 |
|------|------|----------|
| **GitHub** | 가장 일반적, marketplace.json 기반 | `source: {"source": "github", "repo": "org/plugin"}` |
| **Git URL** | GitLab, Bitbucket 등 지원 | `source: {"source": "git", "url": "https://..."}` |
| **Relative Path** | 로컬 개발용 | `source: {"source": "relative", "path": "./plugin"}` |
| **npm** | Deprecated, 호환성 유지 | `source: {"source": "npm", "package": "@org/plugin"}` |

### 1.2 플러그인 설치 흐름

```bash
# 1. 마켓플레이스 등록
/plugin marketplace add SukbeomH/gsd-plugin

# 2. 플러그인 설치
/plugin install gsd@SukbeomH-gsd-plugin

# 3. 자동 업데이트
# Claude Code 시작 시 마켓플레이스에서 버전 체크
```

### 1.3 필요한 파일 구조

```
gsd-plugin/
├── .claude-plugin/
│   └── plugin.json       # 버전 포함 매니페스트
├── marketplace.json      # 마켓플레이스 카탈로그 (선택)
├── commands/
├── skills/
├── agents/
├── hooks/
└── scripts/
```

**plugin.json 예시:**
```json
{
  "name": "gsd",
  "version": "1.2.0",
  "description": "Get Shit Done methodology",
  "author": {"name": "SukbeomH"}
}
```

---

## 2. 자동 릴리즈 도구 비교

### 2.1 semantic-release vs release-please

| 기능 | semantic-release | release-please |
|------|-----------------|----------------|
| 버전 결정 | 완전 자동 | Release PR 생성 |
| 워크플로우 | push → 즉시 릴리즈 | push → PR → merge → 릴리즈 |
| 안전성 | 낮음 (실수 가능) | **높음 (리뷰 가능)** |
| 모노레포 지원 | 플러그인 필요 | **네이티브 지원** |
| npm 의존성 | 필요 | 불필요 (GitHub Action) |
| Changelog | 자동 생성 | 자동 생성 |

**권장: `release-please`** - 플러그인은 npm 패키지가 아니므로 release-please가 더 적합

### 2.2 Conventional Commits → 버전 결정

```
fix: 버그 수정       → 패치 (1.0.0 → 1.0.1)
feat: 새 기능        → 마이너 (1.0.0 → 1.1.0)
feat!: 호환성 깨짐   → 메이저 (1.0.0 → 2.0.0)
BREAKING CHANGE:     → 메이저 (1.0.0 → 2.0.0)
```

---

## 3. 구현 방안

### 3.1 방안 A: release-please (권장)

**장점:**
- Release PR로 리뷰 가능
- plugin.json 버전 자동 업데이트
- CHANGELOG.md 자동 생성
- 모노레포 네이티브 지원

**워크플로우:**
```yaml
name: Release Please
on:
  push:
    branches: [master]
    paths:
      - 'gsd-plugin/**'

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        id: release
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json

      - uses: actions/checkout@v4
        if: ${{ steps.release.outputs.release_created }}

      - name: Create Plugin ZIP
        if: ${{ steps.release.outputs.release_created }}
        run: |
          cd gsd-plugin
          zip -r ../gsd-plugin-${{ steps.release.outputs.tag_name }}.zip . \
            -x ".git/*" "node_modules/*" "__pycache__/*" ".pytest_cache/*"

      - name: Upload Release Asset
        if: ${{ steps.release.outputs.release_created }}
        uses: softprops/action-gh-release@v1
        with:
          tag_name: ${{ steps.release.outputs.tag_name }}
          files: gsd-plugin-${{ steps.release.outputs.tag_name }}.zip
```

**설정 파일:**

`release-please-config.json`:
```json
{
  "packages": {
    "gsd-plugin": {
      "release-type": "simple",
      "bump-minor-pre-major": true,
      "bump-patch-for-minor-pre-major": true,
      "changelog-path": "CHANGELOG.md",
      "extra-files": [
        {
          "type": "json",
          "path": ".claude-plugin/plugin.json",
          "jsonpath": "$.version"
        }
      ]
    }
  }
}
```

`.release-please-manifest.json`:
```json
{
  "gsd-plugin": "1.0.0"
}
```

### 3.2 방안 B: semantic-release

**워크플로우:**
```yaml
name: Release
on:
  push:
    branches: [master]
    paths:
      - 'gsd-plugin/**'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - uses: actions/setup-node@v4
        with:
          node-version: 'lts/*'

      - run: npm install -g semantic-release @semantic-release/git @semantic-release/github

      - run: npx semantic-release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**`.releaserc.json`:**
```json
{
  "branches": ["master"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    ["@semantic-release/github", {
      "assets": [{"path": "gsd-plugin.zip", "label": "GSD Plugin"}]
    }]
  ]
}
```

### 3.3 방안 C: 수동 + 간단한 자동화

변경 감지 + 수동 버전 관리:

```yaml
name: Build Plugin
on:
  push:
    branches: [master]
    paths:
      - 'gsd-plugin/**'
  workflow_dispatch:
    inputs:
      version:
        description: 'Release version (e.g., 1.2.0)'
        required: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Get version
        id: version
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            echo "version=${{ github.event.inputs.version }}" >> $GITHUB_OUTPUT
          else
            VERSION=$(jq -r .version gsd-plugin/.claude-plugin/plugin.json)
            echo "version=$VERSION" >> $GITHUB_OUTPUT
          fi

      - name: Create ZIP
        run: |
          cd gsd-plugin
          zip -r ../gsd-plugin-v${{ steps.version.outputs.version }}.zip . \
            -x ".git/*" "__pycache__/*"

      - name: Create Release
        uses: ncipollo/release-action@v1
        with:
          tag: v${{ steps.version.outputs.version }}
          artifacts: "gsd-plugin-v${{ steps.version.outputs.version }}.zip"
          generateReleaseNotes: true
          skipIfReleaseExists: true
```

---

## 4. 권장 구현

### 4.1 선택: release-please

| 이유 | 설명 |
|------|------|
| 안전성 | Release PR로 리뷰 후 머지 |
| 모노레포 | gsd-plugin 디렉토리만 독립 릴리즈 |
| 유지보수 | npm 의존성 없음, GitHub Action만 |
| Changelog | 자동 생성 및 커밋 |

### 4.2 구현 순서

1. **Conventional Commits 적용**
   - 플러그인 변경 시 `feat(gsd-plugin):`, `fix(gsd-plugin):` 형식 사용

2. **설정 파일 생성**
   - `release-please-config.json`
   - `.release-please-manifest.json`

3. **워크플로우 추가**
   - `.github/workflows/release-plugin.yml`

4. **마켓플레이스 설정**
   - `gsd-plugin/marketplace.json` 생성 (선택)

### 4.3 예상 릴리즈 플로우

```
1. feat(gsd-plugin): 새 skill 추가
   ↓
2. push to master
   ↓
3. release-please가 Release PR 생성
   - 버전: 1.0.0 → 1.1.0
   - CHANGELOG.md 업데이트
   - plugin.json 버전 업데이트
   ↓
4. PR 리뷰 → 머지
   ↓
5. 자동으로:
   - Git 태그 생성 (v1.1.0)
   - GitHub Release 생성
   - gsd-plugin-v1.1.0.zip 첨부
   ↓
6. 사용자: Claude Code 재시작 시 업데이트 감지
```

---

## 5. 추가 고려사항

### 5.1 ZIP 제외 패턴

```
.git/*
__pycache__/*
*.pyc
.pytest_cache/*
node_modules/*
.env
.venv/*
*.log
.DS_Store
```

### 5.2 마켓플레이스 자동 업데이트

별도 저장소에 marketplace.json을 유지하고, release-please가 버전 업데이트 시 함께 PR 생성하도록 구성 가능.

### 5.3 Pre-release 지원

```json
// release-please-config.json
{
  "packages": {
    "gsd-plugin": {
      "prerelease": true,
      "prerelease-type": "beta"
    }
  }
}
```

---

## 6. 구현 결과 (2026-01-29)

### 6.1 첫 릴리즈 성공

| 항목 | 값 |
|------|-----|
| **버전** | v1.1.0 |
| **태그** | `gsd-plugin-v1.1.0` |
| **아티팩트** | `gsd-plugin-1.1.0.zip` (195KB) |
| **URL** | https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/tag/gsd-plugin-v1.1.0 |

### 6.2 발견된 이슈 및 해결

#### 이슈 1: GitHub Actions PR 생성 권한

**증상:**
```
GitHub Actions is not permitted to create or approve pull requests
```

**원인:** 기본 저장소 설정에서 GitHub Actions의 PR 생성이 비활성화

**해결:**
- Settings → Actions → General → Workflow permissions
- "Allow GitHub Actions to create and approve pull requests" 활성화

#### 이슈 2: release-please v4 컴포넌트 출력 변수

**증상:** `build-and-upload` job이 `skipped`로 표시되어 ZIP 미첨부

**원인:** 모노레포/컴포넌트 설정 시 출력 변수명이 `component--output` 형식

**잘못된 설정:**
```yaml
release_created: ${{ steps.release.outputs.release_created }}
```

**올바른 설정:**
```yaml
release_created: ${{ steps.release.outputs['gsd-plugin--release_created'] }}
tag_name: ${{ steps.release.outputs['gsd-plugin--tag_name'] }}
version: ${{ steps.release.outputs['gsd-plugin--version'] }}
```

**참고:** 이 동작은 release-please 공식 문서에서 명확히 설명되지 않음. GitHub Action 소스 코드 분석 필요.

### 6.3 유용한 디버깅 명령어

```bash
# 워크플로우 실행 목록
gh run list --workflow="release-plugin.yml" --limit 5

# 실패 로그 확인
gh run view <run_id> --log-failed

# Job 상태 확인
gh run view <run_id> --json jobs | jq '.jobs[] | {name, status, conclusion}'

# 릴리즈 에셋 확인
gh release view <tag> --json assets | jq

# 수동 워크플로우 트리거
gh workflow run release-plugin.yml
```

### 6.4 워크플로우 최종 구조

```yaml
jobs:
  release-please:
    outputs:
      # 컴포넌트별 prefix 필수
      release_created: ${{ steps.release.outputs['gsd-plugin--release_created'] }}
      tag_name: ${{ steps.release.outputs['gsd-plugin--tag_name'] }}
      version: ${{ steps.release.outputs['gsd-plugin--version'] }}
    steps:
      - uses: googleapis/release-please-action@v4
      - name: Debug outputs  # 디버깅용 추가
        run: echo "release_created: ${{ steps.release.outputs['gsd-plugin--release_created'] }}"

  build-and-upload:
    needs: release-please
    if: ${{ needs.release-please.outputs.release_created == 'true' }}
    steps:
      - uses: actions/checkout@v4
      - name: Create Plugin ZIP
      - uses: softprops/action-gh-release@v2
```

### 6.5 교훈

1. **사전 테스트 필수**: 첫 릴리즈 전 `workflow_dispatch`로 테스트
2. **저장소 권한 확인**: GitHub Actions 권한은 기본적으로 제한적
3. **출력 변수 형식 확인**: release-please 설정 방식에 따라 출력 변수명이 다름
4. **디버그 로그 추가**: 문제 발생 시 원인 파악을 위해 출력 로그 필수

---

## 7. 참고 자료

- [Claude Code Plugin Marketplaces](https://code.claude.com/docs/en/plugin-marketplaces)
- [release-please Action](https://github.com/googleapis/release-please-action)
- [release-please Manifest Mode](https://github.com/googleapis/release-please/blob/main/docs/manifest-releaser.md)
- [semantic-release](https://semantic-release.gitbook.io/semantic-release/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions Path Filters](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onpushpull_requestpull_request_targetpathspaths-ignore)
