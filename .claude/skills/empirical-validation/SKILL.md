---
name: empirical-validation
description: Requires proof before marking work complete — no "trust me, it works"
trigger: "경험적 검증, 실행 결과 확인, 증거 기반 확인, prove it works, empirical proof, validate with output"
---

## Quick Reference
- **원칙**: "The code looks correct" ≠ 검증. 경험적 증거 필수
- **UI**: Screenshot으로 시각 상태 확인 (`browser_subagent`)
- **API**: `curl` 명령으로 응답 확인 (`run_command`)
- **Build/Test**: 성공 출력 캡처 (`run_command`)
- **금지 문구**: "This should work", "Based on my understanding" 등

---

# Empirical Validation

## Core Principle

> **"The code looks correct" is NOT validation.**
> 
> Every change must be verified with empirical evidence before being marked complete.

## Validation Methods by Change Type

| Change Type | Required Validation | Tool |
|-------------|---------------------|------|
| **UI Changes** | Screenshot showing expected visual state | `browser_subagent` |
| **API Endpoints** | Command showing correct response | `run_command` |
| **Build/Config** | Successful build or test output | `run_command` |
| **Data Changes** | Query showing expected data state | `run_command` |
| **File Operations** | File listing or content verification | `run_command` |

## Validation Protocol

### Before Marking Any Task "Done"

1. **Identify Verification Criteria**
   - What should be true after this change?
   - How can that be observed?

2. **Execute Verification**
   - Run the appropriate command or action
   - Capture the output/evidence

3. **Document Evidence**
   - Add to `.hxsk/JOURNAL.md` under the task
   - Include actual output, not just "passed"

4. **Confirm Against Criteria**
   - Does evidence match expected outcome?
   - If not, task is NOT complete

## Examples

### API Endpoint Verification
```bash
# Good: Actual test showing response
curl -X POST http://localhost:3000/api/login -d '{"email":"test@test.com"}' 
# Output: {"success":true,"token":"..."}

# Bad: Just saying "endpoint works"
```

### UI Verification
```
# Good: Take screenshot with browser tool
- Navigate to /dashboard
- Capture screenshot
- Confirm: Header visible? Data loaded? Layout correct?

# Bad: "The component should render correctly"
```

### Build Verification
```bash
# Good: Show build output
npm run build
# Output: Successfully compiled...

# Bad: "Build should work now"
```

## Forbidden Phrases

Never use these as justification for completion:
- "This should work"
- "The code looks correct"
- "I've made similar changes before"
- "Based on my understanding"
- "It follows the pattern"

## Integration

This skill integrates with:
- `/verify` — Primary workflow using this skill
- `/execute` — Must validate before marking tasks complete
- `.gemini/GEMINI.md` Rule 4 (Empirical Validation) — Every change MUST be verified with empirical evidence (screenshot, command output, test result) before marking complete

## Failure Handling

If verification fails:

1. **Do NOT mark task complete**
2. **Document** the failure in `.hxsk/STATE.md`
3. **Create** fix task if cause is known
4. **Trigger** Context Health Monitor if 3+ failures
