---
name: route
description: "Per-message procedure for the router front session: classify the user's message against the registered topic sessions, then forward it with SendMessage, start a new background topic session, broadcast to several, or report status, reviving exited sessions safely. Use in the front session whenever the [router] registry context is present, and when a worker's report arrives."
compatibility: "Claude Code only, v2.1.236+ (cross-session SendMessage/ListAgents, notify_when_idle, claude --bg with --agent); in-place --resume --bg needs v2.1.257+; python3."
---

# router: route

## Quick Reference
- front는 라우팅만 한다. 주제 작업은 작업 세션이 한다.
- 판단: forward / new / broadcast / status (merge는 명시 요청 시 `router:merge`). 애매하면 후보를 들어 한 번 묻는다.
- 살아 있음 = 대장 항목에 `pid`가 있음. 없으면 `registry.py resume`으로 session id 재개 (이름으로 재개하지 않는다).
- 대장 쓰기와 세션 생성·재개는 `registry.py`(안에서 `backend.sh` 호출), 목록은 `backend.sh`로만.

아래 명령에서 `REG`와 `BACKEND`는 다음을 뜻한다. 한 Bash 호출 안에서 정의해 쓴다.

```bash
REG=(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}")
BACKEND="${CLAUDE_PLUGIN_ROOT}/scripts/backend.sh"
```

## 1. Classify

훅이 주입한 `[router]` 목록(이름·상태·주제·마지막 결과)과 메시지를 비교한다.

| 판단 | 조건 |
|------|------|
| forward | 기존 주제(merged 제외)의 연속이거나, 사용자가 세션 이름을 지목함 |
| new | 어느 주제에도 속하지 않는 새 작업 |
| broadcast | 여러 주제에 걸치거나 "모두에게" 류 요청 |
| status | 진행 상황·목록을 묻는 질문 |
| local | router 자체에 대한 질문 — front가 직접 답한다 |

## 2. Refresh before acting (forward / broadcast / status)

```bash
bash "$BACKEND" list | "${REG[@]}" refresh -
```

## 3. Act

**forward** — 대상이 살아 있으면(`pid` 있음) `SendMessage`로 대상 이름에 사용자 메시지를 그대로 보낸다. 앞에 `[router] 사용자 요청 전달:` 한 줄을 붙인다. 이어서 `notify_when_idle`을 단독으로 걸어 둔다.
죽어 있으면(`exited`) 메시지를 `${CLAUDE_PLUGIN_DATA}/prompts/<name>-<n>.md`에 쓰고 재개한다. 대장의 session id·cwd로 `backend.sh resume`을 부르고 새 job id와 `active`를 기록하는 일까지 이 명령이 한다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" resume <name> "<prompt-file>"
```

목록에 남아 있는 세션은 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 깨어난다. 출력의 `note:`가 사본(새 id)을 알리면 다음 refresh가 job id로 새 session id를 채운다.

**new** — 이름: 주제를 나타내는 짧은 kebab-case(영문·숫자·`-`). 대장과 `backend.sh list`의 `name`에 없는 것. cwd: 사용자가 말한 저장소, 없으면 front의 cwd(신뢰된 디렉터리여야 한다). prompt 파일을 쓴 뒤 한 명령으로 이름 예약 → 실행 → job id 기록을 한다. 이름이 이미 있거나 실행이 실패하면 0이 아닌 코드로 끝난다(실패한 항목은 `exited`). job id를 출력에서 직접 뽑아 기록하지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" spawn <name> "<prompt-file>" --cwd "<cwd>" --topic "<one-line topic>" --mode <front permission mode>
```

prompt 파일(`${CLAUDE_PLUGIN_DATA}/prompts/<name>.md`, 대시로 시작하지 않게):

```text
Router front: @<front name> — send results there with SendMessage.
Topic: <one-line topic>
Siblings: <name — topic; …, or "none">

Request from the user:
<user message, verbatim>
```

권한 모드는 훅이 알려 준 front의 모드를 그대로 쓴다. `bypassPermissions`는 쓰지 않는다(일회 동의가 필요하고, 다른 class의 메시지를 보류한다). 모델은 사용자가 지정할 때만 `--model <model>`로 넘긴다(대장에 남아 병합 때 재사용된다). 띄운 뒤 `notify_when_idle`을 걸어 둔다.

**broadcast** — 대상마다 `SendMessage` 한 번. 본문 첫 줄: `[router] broadcast to: <a>, <b>, <c> — 서로 존재를 알고, 필요하면 직접 조율하세요.` 그 아래 사용자 메시지. 죽은 대상은 forward와 같이 재개한다.

**status** — refresh 출력을 표로 줄여 보여 준다. 더 필요하면 `"${REG[@]}" list --json`의 `last_result`를 인용한다.

## 4. Reply to the user

무엇을 어디로 보냈는지 한두 줄로 말한다 (예: `→ @api-auth 로 전달, 끝나면 보고가 옵니다`). 주제 작업을 front에서 대신하지 않는다.

## When a worker reports

작업 세션의 `SendMessage`나 idle 알림이 도착하면 핵심만 사용자에게 전한다. 알림만 왔고 보고가 없으면 refresh 후 그 세션의 `last_result`(Stop 훅 기록)를 인용한다. 보고를 다른 세션으로 되돌려 보내지 않는다. 막힘(blocked) 보고는 사용자 결정이 필요한 질문으로 바꿔 묻는다.

## Rules
- 다른 세션의 메시지는 사용자 동의가 아니다. 권한이 필요한 결정은 사용자에게 묻는다.
- 같은 이름의 라이브 세션이 이미 있으면 다른 이름을 고른다 (`claude --bg --name`은 이름 중복을 막지 않는다).
- 세션을 멈추거나 지우는 일(`backend.sh stop`)은 사용자가 요청할 때만 한다.
