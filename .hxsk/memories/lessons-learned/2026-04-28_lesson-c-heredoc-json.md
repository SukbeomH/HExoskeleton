---
title: "Lesson C: heredoc JSON 변수 이스케이핑 누락"
tags:
  - lessons-learned
  - category-C
  - pr-160

type: lessons-learned
created: 2026-04-28T01:01:54Z
contextual_description: "증상: bash heredoc에서 사용자 제공 변수(${QUESTION} 등)를 JSON으로 직접 삽입 시 따옴표·백슬래시가 포함되면 malformed JSON 발생. claude"
---

## Lesson C: heredoc JSON 변수 이스케이핑 누락

증상: bash heredoc에서 사용자 제공 변수(${QUESTION} 등)를 JSON으로 직접 삽입 시 따옴표·백슬래시가 포함되면 malformed JSON 발생. claude-code.sh의 HITL pending 파일 사례(PR #160).
예방: heredoc 내 JSON 문자열 삽입 시 반드시 yaml_safe/json_safe 전처리 적용. sed 's/\\/\\\\/g; s/"/\\"/g' 패턴 사용. 또는 python3 -c json.dumps().
