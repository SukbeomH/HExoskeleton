---
name: approve
description: "Answers a router worker's open permission prompt from the front: /router:approve <id> allows exactly the shown call, /router:approve <id> deny denies it, bare /router:approve lists open requests. User-typed only in the front session; the plugin's hook writes the decision and blocks the prompt, so the model never runs this."
disable-model-invocation: true
compatibility: "Claude Code only, v2.1.236+ with UserPromptExpansion and PermissionRequest hooks (verified on v2.1.287); python3."
---

# router: approve

## Quick Reference
- 사용자가 front에서 직접 입력한 `/router:approve <id> [deny]`만 승인·거부를 보낸다. 플러그인의 UserPromptExpansion 훅이 결정을 쓰고 프롬프트를 막는다(모델 턴 없음). 그래서 이 본문은 보통 보이지 않는다.
- 이 본문이 보이면 훅이 이 명령을 처리하지 못한 것이다. 승인·거부는 전달되지 않았다.

## If you are reading this

1. 사용자에게 그대로 알린다: `승인이 전달되지 않았습니다(router 훅이 /router:approve를 처리하지 못했습니다). 터미널에서 claude attach <job_id>로 그 작업 세션을 열어 응답해 주세요.` `<job_id>`는 `[router]` 목록에서 그 작업 세션의 `WAITING` 줄 `… or runs: claude attach …`에 있다. 그 세션이 `codex`(줄에 `unanswered = denied when it expires`)면 attach 문장 대신 `이 요청은 시간이 지나면 거부됩니다. 플러그인 훅을 확인한 뒤 다시 보내 주세요.`라고 알린다.
2. 그 밖의 일은 하지 않는다. 승인 파일을 쓰거나, `registry.py`·`claude`를 실행하거나, 다른 세션에 메시지를 보내 승인을 대신하지 않는다.
