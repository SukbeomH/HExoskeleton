---
id: 002
title: "dispatcher/SKILL.md 서브에이전트 프롬프트 중첩 코드블록 GFM 렌더링 모호성"
type: improvement
priority: P3
status: resolved
wave: null
created: 2026-04-13
assignee: null
files:
  - .hxsk/skills/dispatcher/SKILL.md
source: arch-review (2026-04-13)
---

# dispatcher/SKILL.md — 중첩 코드블록 GFM 렌더링 모호성

## 증상

`.hxsk/skills/dispatcher/SKILL.md:112-154` 서브에이전트 프롬프트 템플릿이
외부 3-backtick 펜스 안에 내부 ` ```bash ` 블록을 포함하고 있음.

GFM(GitHub Flavored Markdown) 스펙 상 3-backtick 펜스 내에 동일한 3-backtick이 오면
외부 블록이 L128에서 조기 종료되어 GitHub 렌더링 시 시각적 오류 발생 가능.

## 현재 구조

```
L112: ```            ← 외부 블록 열기
L128: ```bash        ← GFM이 외부 블록 닫힘으로 해석
L131: ```            ← GFM이 내부 블록 닫힘으로 해석
L154: ```            ← GFM이 새 블록 열기로 해석 (미닫힘)
```

## 실제 영향

- **AI 프롬프트 사용 시**: 영향 없음 (LLM은 의도 이해)
- **GitHub/문서 렌더링 시**: 블록 경계 시각적 오류

## 수정 방법

외부 코드블록을 4-backtick으로 교체:

```
L112: ````           ← 4-backtick 외부 블록
L128: ```bash        ← 3-backtick 내부 블록 (안전하게 중첩)
L131: ```            ← 내부 블록 닫힘
L154: ````           ← 4-backtick 외부 블록 닫힘
```

## Done Criteria

- [ ] `dispatcher/SKILL.md` 외부 펜스 3-backtick → 4-backtick 교체
- [ ] GitHub에서 렌더링 확인 (코드블록 경계 정상)
- [ ] doc-lint PASS
