---
name: merge
description: "Merges converged router topic sessions into one: collects a summary from each source, writes a merged brief, starts a new topic session seeded with it and marks the sources merged in the registry. Use only when the user explicitly asks to merge sessions (/router:merge <source...> [into <name>])."
compatibility: "Claude Code only, v2.1.236+ (cross-session SendMessage/ListAgents, claude --bg with --agent); python3."
---

# router: merge

## Quick Reference
- 사용자의 명시적 명령으로만 실행한다. 수렴을 스스로 감지해 병합하지 않는다.
- 요약 수집: 살아 있으면 메시지로 요청, 종료됐으면 대장의 `last_result`, 부족하면 `backend.sh summarize`.
- 원본 세션은 대장에서 `merged`로 표시만 한다. 멈추기는 사용자가 원할 때만.

`REG`/`BACKEND`는 `router:route`와 같다.

```bash
REG=(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}")
BACKEND="${CLAUDE_PLUGIN_ROOT}/scripts/backend.sh"
```

## Steps

1. **대상 확정.** 인자에서 원본 이름들과 새 이름을 읽는다. 새 이름이 없으면 원본 주제를 아우르는 kebab-case 이름을 제안한다. 원본이 2개 미만이거나 대장에 없으면 멈추고 묻는다.

2. **상태 갱신.**

   ```bash
   bash "$BACKEND" list | "${REG[@]}" refresh -
   ```

3. **요약 수집.** 원본마다:
   - 살아 있음(`pid` 있음): `SendMessage`로 `[router] merge 준비: 이 주제의 목표·결정·현재 상태·남은 문제·건드린 파일을 300단어 이내로 front에 답장해 주세요.`를 보낸다. 답장을 기다린다(오지 않으면 refresh 후 `last_result`).
   - 종료됨: `"${REG[@]}" list --json`의 `last_result`를 쓴다. 비었거나 부족하면 `bash "$BACKEND" summarize <session_id>` (원본을 건드리지 않도록 fork해서 요약한다).

4. **병합 brief 작성.** `${CLAUDE_PLUGIN_DATA}/prompts/<new>.md`에 쓴다 (대시로 시작하지 않게).

   ```text
   Router front: @<front name> — send results there with SendMessage.
   Topic: <merged one-line topic>
   Siblings: <other non-merged workers — topic; …, or "none">
   Merged from: <source names>

   Merged brief:
   <원본별 요약을 합친 것: 공통 목표, 결정, 충돌과 해소안, 남은 일, 관련 cwd/브랜치/파일>

   Request from the user:
   <병합 명령과 함께 준 지시, 없으면 "Continue the merged topic.">
   ```

5. **새 작업 세션 생성과 원본 표시.** cwd는 원본의 cwd(서로 다르면 사용자에게 묻는다), 권한 모드는 front의 모드. 모델: 원본들의 `model`(대장 `list --json`)이 모두 같은 값이면 `--model <그 값>`을 더한다. 서로 다르거나 일부만 있으면 넘기지 않고(기본 모델) 6의 보고에서 그렇게 알린다. 이름 예약 → 실행 → job id 기록을 한 명령으로 한다. job id를 출력에서 직접 뽑아 기록하지 않는다.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" spawn <new> "<brief-file>" --cwd "<cwd>" --topic "<merged topic>" --mode <front permission mode>
   ```

   성공(종료 코드 0)했을 때만 원본마다 한 번씩 표시한다. 실패하면 새 항목은 `exited`로 남고 원본은 그대로 둔 채 사용자에게 알린다.

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/registry.py" --data "${CLAUDE_PLUGIN_DATA}" mark <source> merged --into <new>
   ```

6. **보고.** 새 세션 이름, 합친 원본, 쓴 모델(또는 기본 모델인 이유), brief의 핵심 3줄을 알린다. 원본 세션을 멈출지(`bash "$BACKEND" stop <job_id>`) 물어본다.
