---
title: "HExoskeleton 릴리즈 프로세스 (hxsk-plugin)"
tags:
  - release
  - hxsk-plugin
  - ci
  - workflow
  - release-please
type: pattern-discovery
created: 2026-02-20T05:58:26Z
contextual_description: "HExoskeleton 프로젝트의 올바른 릴리즈 절차 — feat/fix는 자동, ci/chore는 수동 패치"
keywords:
  - 릴리즈
  - 버전
  - 태그
  - release-please
  - CI
  - GitHub
  - hxsk-plugin
---

## HExoskeleton 릴리즈 프로세스 (hxsk-plugin)

## 올바른 릴리즈 과정

### 전제 조건
- release-please는 `feat:`, `fix:` 커밋만 버전 bump 트리거
- `ci:`, `chore:` 커밋은 버전 bump 없음 → 수동 패치 릴리즈 필요
- master 브랜치는 protected → 직접 push 불가, PR 필수

### 단계별 릴리즈 절차

#### Case A: feat/fix 커밋 → release-please 자동
1. master에 `feat:` 또는 `fix:` 커밋 머지
2. release-please가 자동으로 릴리즈 PR 생성 (chore(master): release hxsk-plugin X.Y.Z)
3. PR 머지 → 태그 자동 생성 → CI workflow 트리거 → 아티팩트 자동 첨부

#### Case B: ci/chore 커밋만 있을 때 → 수동 패치 릴리즈
1. `.release-please-manifest.json` 버전 수동 bump (예: 1.9.0 → 1.9.1)
2. 브랜치 생성 → PR 생성 → 머지
3. 태그 생성 및 push:
   ```bash
   git tag hxsk-plugin-v1.9.1
   git push origin hxsk-plugin-v1.9.1
   ```
4. GitHub 릴리즈 생성:
   ```bash
   gh release create hxsk-plugin-v1.9.1      --repo SukbeomH/HExoskeleton      --title "hxsk-plugin v1.9.1"      --notes "..."
   ```
5. CI workflow 자동 트리거 → 빌드 아티팩트 자동 첨부

### 태그 네이밍
- 형식: `hxsk-plugin-vX.Y.Z`
- 예: hxsk-plugin-v1.9.0, hxsk-plugin-v1.9.1

### 빌드 아티팩트 (CI 자동 생성)
- hxsk-plugin-{VERSION}.zip
- antigravity-boilerplate-{VERSION}.zip
- opencode-boilerplate-{VERSION}.zip

### 수동 workflow 트리거 (빌드만 필요할 때)
```bash
gh workflow run release-plugin.yml --repo SukbeomH/HExoskeleton
```
→ release-please job 스킵, build + upload job만 실행 (최신 태그 기준)

### CI 주의사항
- release-please job의 Debug outputs 스텝은 JSON 특수문자로 실패 가능 (무시해도 됨)
- build job과 upload job이 success이면 릴리즈 정상 완료
