---
title: "macOS sed 워드바운더리 미지원 - \b 대신 plain 패턴 사용"
tags:
  - macos
  - sed
  - word-boundary
  - scripting
type: pattern-discovery
created: 2026-02-23T06:45:24Z
contextual_description: "macOS BSD sed는 \b 워드바운더리를 지원하지 않아 bulk sed 치환 시 plain 패턴만 사용해야 함"
keywords:
  - sed
  - macOS
  - BSD sed
  - word boundary
  - \b
  - bulk rename
---

## macOS sed 워드바운더리 미지원 - \b 대신 plain 패턴 사용

## macOS sed 워드바운더리 미지원 - \b 대신 plain 패턴 사용

macOS의 기본 sed는 \b 워드바운더리를 지원하지 않는다. \bGSD\b 패턴이 silently 무시됨.

**재현 경로:**
`echo "test GSD here" | sed -e 's/\bGSD\b/HXSK/g'` → 'test GSD here' (교체 안 됨)
`echo "test GSD here" | sed -e 's/GSD/HXSK/g'` → 'test HXSK here' (교체 됨)

**근본 원인:**
macOS sed (BSD sed)는 POSIX ERE에서 \b를 word boundary로 처리하지 않는다.
GNU sed에서는 동작하나 BSD sed에서는 literal 문자나 무시됨.

**해결책:**
- plain `s/GSD/HXSK/g` 사용 (워드바운더리 없이)
- 충돌 가능성: 복합 단어(XGSD 등)가 없는 경우 안전
- GNU sed가 필요하면 `brew install gnu-sed` 후 `gsed` 사용

**영향 확인:**
리네이밍 전 `grep -oE '[A-Za-z0-9_-]*[Gg][Ss][Dd][A-Za-z0-9_-]*'` 로 복합 패턴 여부 확인 권장.
