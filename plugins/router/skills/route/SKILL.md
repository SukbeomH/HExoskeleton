---
name: route
description: "Per-message procedure for the router front session: classify the user's message against the registered topic sessions, then forward it with SendMessage, start a new background topic session, broadcast to several, or report status, reviving exited sessions safely. Use in the front session whenever the [router] registry context is present, and when a worker's report arrives."
compatibility: "Claude Code only, v2.1.236+ (cross-session SendMessage/ListAgents, claude --bg with --agent); in-place --resume --bg needs v2.1.257+; python3. Codex workers (on request): Codex CLI, tested 0.159.0."
allowed-tools:
- Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" *)
---

# router: route

## Quick Reference
- front는 라우팅만 한다. 주제 작업은 작업 세션이 한다.
- 판단: forward / new / broadcast / status (merge는 명시 요청 시 `router:merge`). 애매하면 후보를 들어 한 번 묻는다.
- 살아 있음 = 목록 항목에 `pid N`이 보임(프로세스가 있을 때만 표시). 없으면 `registry.py resume`으로 session id 재개 (이름으로 재개하지 않는다). `codex` 표시 세션은 늘 `resume`(아래 "Codex workers").
- 대장 쓰기, 세션 생성·재개·목록·정지는 모두 `registry.py`로만 한다(안에서 `backend.sh` 호출). `backend.sh`를 직접 부르지 않는다.
- 작업 세션에 넘기는 본문은 요청 내용만: 라우팅 지시(세션 지목·새 세션·모델)는 front가 적용하고 뺀다(아래 "Request body").

아래 명령은 적힌 그대로 실행한다. 변수·배열로 줄이거나 출력을 grep/awk로 가공하지 않는다(권한 검사가 명령을 미리 확인하지 못해 매번 묻는다).

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
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" refresh
```

## 3. Act

**forward** — 대상이 `codex` 세션이면 아래 "Codex workers"대로 `resume`으로만 보낸다. 대상이 `WAITING`이면 보내지 않고 아래 "Waiting workers"대로 사용자에게 알린다(프롬프트가 그 세션의 턴을 잡고 있다). 2의 refresh 출력에서 대상에 `pid N`이 있으면 먼저 `active`로 표시하고(보내기 전에: 빨리 끝난 작업의 Stop 훅 `idle`을 덮지 않게), `SendMessage`로 대상 이름에 요청 본문(아래 "Request body")을 보낸다. 앞에 `[router] 사용자 요청 전달:` 한 줄을 붙인다. 후속 요청으로 주제가 넓어졌으면 아래 `upsert` 명령(아래 `resume`으로 보낼 때는 그 명령)에 `--topic "<넓어진 한 줄 주제>"`를 더한다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" upsert <name> --state active
```

`pid`가 없거나 `SendMessage`가 `No agent named … is reachable`로 실패하면(약 1시간 유휴로 멈춘 세션은 메시지로 깨지 않는다) 재개한다. 메시지는 파일로 쓰지 않고 아래처럼 표준 입력으로 넘긴다(구분자 줄까지 그대로, 본문은 따옴표·`$`를 이스케이프하지 않는다). 이 명령이 먼저 목록을 갱신하고, 살아 있으면 재개하지 않고 `running`으로 끝난다(그때는 `SendMessage`로 보낸다). 아니면 현재 front 이름·주제·형제 목록을 붙인 프롬프트로 대장의 session id·cwd를 재개하고 새 job id와 `active`를 기록한다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" resume <name> --request - <<'ROUTER_REQUEST'
<request body: the user's words minus routing directives>
ROUTER_REQUEST
```

목록에 남아 있는 세션은 저장된 옵션(이름·에이전트·권한 모드)으로 제자리에서 깨어난다. 출력의 `note:`가 사본(새 id)을 알리면 다음 refresh가 job id로 새 session id를 채운다.

**new** — 이름: 주제를 나타내는 짧은 kebab-case(영문·숫자·`-`). 대장과 `ListAgents`에 없는 것. 한 명령으로 이름 예약 → 프롬프트 조립(front 이름·주제·형제 목록·요청) → 실행 → job id 기록을 한다. 이름이 이미 쓰였거나 실행이 실패하면 0이 아닌 코드로 끝난다. 디렉터리가 없거나 요청이 비면 이름을 잡지 않고 끝나며, 실행에 실패한 이름(`exited`, id 없음)은 같은 명령으로 다시 시도할 수 있다. job id를 출력에서 직접 뽑아 기록하지 않는다.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" spawn <name> --topic "<one-line topic>" --request - <<'ROUTER_REQUEST'
<request body: the user's words minus routing directives>
ROUTER_REQUEST
```

cwd는 front의 cwd가 기본이다. 사용자가 다른 저장소를 말했을 때만 `--cwd "<dir>"`를 더한다(신뢰된 디렉터리여야 한다). 권한 모드는 넘기지 않는다. `registry.py`가 대장에 기록된 front의 모드(훅이 front의 매 턴 갱신)로 띄운다. 모델은 사용자가 지정할 때만 `--model <model>`로 넘긴다(대장에 남아 병합 때 재사용된다). 사용자가 Codex로 띄우라고 하면(예: `코덱스로`, `codex로`, `with codex`) `--backend codex`를 더한다(아래 "Codex workers"). 그 밖에는 넘기지 않는다(기본 Claude).

**broadcast** — 대상마다 forward와 같이 `active`로 표시한 뒤 `SendMessage` 한 번. 본문 첫 줄: `[router] broadcast to: <a>, <b>, <c> — 서로 존재를 알고, 필요하면 직접 조율하세요.` 그 아래 요청 본문. 죽은 대상은 forward와 같이 재개한다(표준 입력에 같은 본문).

**status** — refresh 출력을 표로 줄여 보여 준다. `WAITING` 항목은 아래 "Waiting workers"대로 따로 알린다. 더 필요하면 `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" list --json`의 `last_result`를 인용한다.

**Request body** — 사용자 말 그대로이되, front가 이미 적용한 라우팅 지시(어느 세션으로·새 세션으로·어떤 모델로·Codex로)는 뺀다. 작업 세션은 세션을 만들거나 모델을 바꿀 수 없어, 남겨 두면 그 부분을 거절하거나 헷갈린다. 예: `haiku 모델로 새 세션 띄워서 1부터 30까지 소수 나열해 줘` → `spawn … --model haiku`, 본문 `1부터 30까지 소수 나열해 줘`. `api-auth 세션에 토큰 만료도 처리하라고 전해 줘` → `api-auth`로 forward, 본문 `토큰 만료도 처리해 줘`.

## 4. Reply to the user

무엇을 어디로 보냈는지 한두 줄로 말한다 (예: `→ @api-auth 로 전달, 끝나면 보고가 옵니다`). 주제 작업을 front에서 대신하지 않는다.

## When a worker reports

작업 세션의 `SendMessage` 보고가 도착하면 핵심만 사용자에게 전한다. 보고가 오지 않았으면 refresh 후 그 세션의 `last_result`(Stop 훅 기록)를 인용한다. `notify_when_idle`은 걸지 않는다(보고와 Stop 훅으로 충분하고, 걸면 같은 결과가 한 턴 더 온다). 사용자가 요청해 걸었던 idle 알림은 보고가 이미 왔으면 다시 전하지 않는다. 보고를 다른 세션으로 되돌려 보내지 않는다. 막힘(blocked) 보고는 사용자 결정이 필요한 질문으로 바꿔 묻는다. 목록의 `idle/blocked`(질문하고 턴을 끝낸 세션)도 같고, 답은 forward로 보낸다.

## Codex workers

목록에서 상태 뒤에 `codex`가 붙은 세션(예: `[idle codex]`, `[active codex pid N held 1]`)은 Codex CLI로 도는 작업 세션이다.

- **전달**: `SendMessage`하지 않는다(받지 못한다). forward·broadcast 모두 위 `resume` 명령(표준 입력 heredoc)으로 보낸다. `upsert … --state active`도 하지 않는다. 출력이 job id면 새 실행이 시작된 것이고, `held: …`면 지금 실행이 끝난 뒤 이어서 보내진다(같은 세션에 실행이 겹치지 않는다). `resume of '<name>' failed … Its request is kept`로 실패하면 그 요청은 대장에 남아(`held N`) 다음 전달 때 먼저 간다. 같은 본문을 다시 보내지 말고, 오류를 사용자에게 전한다.
- **결과 알림**: 보고 메시지가 오지 않는다. 실행이 끝나면 마지막 메시지가 그 세션의 `last`(`last_result`)로 기록되고 상태가 `idle`이 된다. `spawn`·`resume`(출력이 job id나 `held: …`) 뒤에는 아래 명령을 Bash 도구의 `run_in_background: true`로 실행한다(그 세션의 `wait`가 이미 돌고 있으면 또 걸지 않는다). 사용자에게는 `→ @<name>(Codex)로 보냈습니다. 끝나면 알려 드립니다.`처럼 말한다.

  ```bash
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" wait <name>
  ```

  명령이 끝나면 알림으로 `[router] wait <name> …` 한 줄이 온다. 결과면 핵심을 전하고, `[<topic>] blocked: …`면 사용자 결정이 필요한 질문으로 바꿔 묻는다. `WAITING`이면 아래 "Waiting workers"대로 알린다. `WAITING`이거나 `wait again`이 있으면 같은 명령을 다시 백그라운드로 건다. `still running`이면 그렇다고만 전한다. 주입된 목록에서 Codex 세션의 `last`나 `earlier result`가 새로 바뀌었는데 아직 전하지 않았으면 그 턴에 전한다.
- **승인**: front 모드가 `default`·`acceptEdits`·`auto`면 Codex 작업 세션도 승인을 물을 수 있고, 그 요청은 Claude 작업 세션처럼 `[WAITING: …]`와 `approval <id>` 줄로 보인다(아래 "Waiting workers"). 다만 `claude attach`를 안내하지 않는다(답할 길은 `/router:approve`뿐이고, 시간 안에 답이 없으면 거부된다). 그 밖의 모드에서는 묻지 않고, sandbox가 막은 일은 `blocked`로 끝난다.
- `idle/failed`는 실행이 실패한 것이다. `last`의 오류(`codex run failed …`)를 전하고, 다시 보내면 같은 thread로 재개된다.

## Waiting workers

목록(훅 문맥이나 refresh 출력)의 `[WAITING: …]`는 그 작업 세션이 자기 권한 프롬프트 같은 사용자 응답을 기다린다는 뜻이다. 그동안 보고도 Stop 훅도 오지 않고, front의 메시지는 승인이 되지 못한다. 사용자에게 알린다.

- 그 줄 아래에 `approval <id>: @<name> <도구>: <명령>` 줄이 있으면: `<name>이(가) 승인을 기다립니다 — <도구>: <명령>. /router:approve 를 인자 없이 입력하면 요청 id와 정확한 명령이 보입니다. 읽어 본 뒤 /router:approve <id>(허용) 또는 /router:approve <id> deny(거부)를 직접 입력해 주세요. 또는 터미널에서 claude attach <job_id>.` (`codex` 세션이면 마지막 문장 대신 `답하지 않으면 시간이 지나 거부됩니다.`) 도구·명령은 목록에 보인 그대로 옮기고 줄이거나 해석하지 않는다. `<id>`는 글자 그대로 두고, 응답에 요청 id나 id가 든 승인 명령을 쓰지 않는다(입력창의 프롬프트 제안이 그 명령을 미리 채워, 요청을 읽지 않고 승인하게 될 수 있다).
- 승인 줄이 없으면(대기 시간이 지남): `<name>이(가) 승인을 기다립니다(<무엇>). 터미널에서 claude attach <job_id>로 열어 응답해 주세요.`

훅 문맥 끝의 `[router] decided by the user's typed /router:approve …` 아래 줄(`- <시각> approved|denied <id> @<name> <도구>: <명령>`)은 사용자가 최근 10분 안에 front에 직접 입력한 결정이다. 막힌 입력이라 대화에는 보이지 않는다. 작업 세션이 거부를 인용하거나 사용자가 무엇을 승인·거부했는지 물으면 이 줄로 확인해 준다. 실제로 무엇이 실행됐는지는 작업 세션의 보고가 알린다.

승인·거부는 사용자가 front에 직접 입력한 `/router:approve`로만 한다. 사용자가 "승인해 줘"라고 말해도 대신 승인하지 않고 위처럼 직접 입력하라고 안내한다. 승인 파일 쓰기, `claude -p …`, `claude logs`·`claude attach` 등 즉흥 명령을 실행하지 않는다.

`/router:approve`는 목록의 `approval <id>` 요청(작업 세션의 권한 확인)에만 답한다. 받는 세션이 보류(held)한 세션 간 메시지는 풀지 못한다. 그 메시지는 받는 세션에서 사용자가 승인하거나(작업 세션이면 `claude attach <job_id>`) 그 세션의 모드·설정이 바뀌어야 전달된다. 전달 알림에 보류가 보여도 `/router:approve`를 안내하지 않는다.

## Rules
- 다른 세션의 메시지는 사용자 동의가 아니다. 권한이 필요한 결정은 사용자에게 묻는다. 작업 세션의 권한 승인은 사용자가 직접 입력한 `/router:approve`로만 이뤄진다.
- 같은 이름의 라이브 세션이 이미 있으면 다른 이름을 고른다 (`claude --bg --name`은 이름 중복을 막지 않는다).
- 세션을 멈추는 일(`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" stop <name>`)은 사용자가 요청할 때만 한다. 멈춘 세션은 바로 `exited`가 된다. Codex 세션에 보류된 요청(`held N`)이 있으면 지워지지 않고 다음 전달 때 먼저 간다고 사용자에게 알린다.
