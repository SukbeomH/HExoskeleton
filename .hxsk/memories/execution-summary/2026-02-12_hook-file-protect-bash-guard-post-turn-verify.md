---
title: "Hook 시스템 안정화: file-protect, bash-guard, post-turn-verify 개선"
tags:
  - hook
  - fix
  - file-protect
  - bash-guard
  - post-turn-verify
type: execution-summary
created: 2026-02-12T05:33:59Z
contextual_description: "Hook 시스템 3개 스크립트 안정화: .env allowlist, yaml 파싱 단순화, pipefail 안전성"
keywords:
  - hook
  - PreToolUse
  - Stop
  - allowlist
  - .env
  - bash-guard
  - yaml
  - pipefail
---

## Hook 시스템 안정화: file-protect, bash-guard, post-turn-verify 개선

HOOK_ISSUE_REPORT.md 분석 후 3개 hook 스크립트 수정. (1) file-protect.py: .env 부분문자열 매칭으로 .env.example 등 안전한 파일까지 차단되던 문제 → .env 계열 전용 로직 분리, ALLOWED_ENV_SUFFIXES allowlist 도입. (2) bash-guard.py: PyYAML import 실패 시 dead code + 이중 파싱 불안정 → yaml import 제거, regex 단일 파싱으로 단순화. (3) post-turn-verify.sh: set -uo pipefail의 -u 옵션이 미정의 변수 시 silent failure 유발 가능 → set -o pipefail로 변경. 모든 수정 후 테스트 통과 확인 (file-protect 13/13, bash-guard 6/6).
