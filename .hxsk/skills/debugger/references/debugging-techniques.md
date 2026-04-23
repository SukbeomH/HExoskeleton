# Debugging Techniques

## Rubber Duck Debugging

**When:** Stuck, confused, mental model doesn't match reality.

Write or say:
1. "The system should do X"
2. "Instead it does Y"
3. "I think this is because Z"
4. "The code path is: A → B → C → D"
5. "I've verified that..." (list what you tested)
6. "I'm assuming that..." (list assumptions)

Often you'll spot the bug mid-explanation.

## Minimal Reproduction

**When:** Complex system, many moving parts.

1. Copy failing code to new file
2. Remove one piece
3. Test: Does it still reproduce? YES = keep removed. NO = put back.
4. Repeat until bare minimum
5. Bug is now obvious in stripped-down code

## Working Backwards

**When:** You know correct output, don't know why you're not getting it.

1. Define desired output precisely
2. What function produces this output?
3. Test that function with expected input — correct output?
   - YES: Bug is earlier (wrong input)
   - NO: Bug is here
4. Repeat backwards through call stack

## Differential Debugging

**When:** Something used to work and now doesn't.

**Time-based:** What changed in code? Environment? Data? Config?

**Environment-based:** Config values? Env vars? Network? Data volume?

## Binary Search / Divide and Conquer

**When:** Bug somewhere in a large codebase or long history.

1. Find a known good state
2. Find current bad state
3. Test midpoint
4. Narrow: is midpoint good or bad?
5. Repeat until found

## Comment Out Everything

**When:** Many possible interactions, unclear which causes issue.

1. Comment out everything in function
2. Verify bug is gone
3. Uncomment one piece at a time
4. When bug returns, you found the culprit

---

## Hypothesis Testing

### Falsifiability Requirement

A good hypothesis can be proven wrong.

**Bad (unfalsifiable):**
- "Something is wrong with the state"
- "The timing is off"

**Good (falsifiable):**
- "User state is reset because component remounts on route change"
- "API call completes after unmount, causing state update on unmounted component"

### Forming Hypotheses

1. **Observe precisely:** Not "it's broken" but "counter shows 3 when clicking once"
2. **Ask "What could cause this?"** — List every possible cause
3. **Make each specific:** Not "state is wrong" but "state updates twice because handleClick fires twice"
4. **Identify evidence:** What would support/refute each hypothesis?

### Testing Process

**Change one variable:** Make one change, test, observe, document, repeat.

**Complete reading:** Read entire functions, not just "relevant" lines.

**Embrace not knowing:** "I don't know" = good (now you can investigate). "It must be X" = dangerous.

---

## When to Restart

Consider starting over when:
1. **2+ hours with no progress** — Tunnel-visioned
2. **3+ "fixes" that didn't work** — Mental model is wrong
3. **You can't explain current behavior** — Don't add changes on top
4. **You're debugging the debugger** — Something fundamental is wrong
5. **Fix works but you don't know why** — This is luck, not a fix

**Restart protocol:**
1. Close all files and terminals
2. Write down what you know for certain
3. Write down what you've ruled out
4. List new hypotheses (different from before)
5. Begin again from Phase 1
