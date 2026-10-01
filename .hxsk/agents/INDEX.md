# Agents Index

> 2 agent definitions. Only agents whose tool restriction matters are kept;
> everything else is a skill — invoke the skill directly.

| Agent | Description | Tools | Skills | Path |
|-------|-------------|-------|--------|------|
| spec-reviewer | Validates implementation against SPEC.md requirements -- checks what was built matches what was requested | Read, Grep, Glob (read-only) | verifier, empirical-validation | `agents/spec-reviewer.md` |
| verifier | Validates implemented work against spec requirements with empirical evidence | Read, Bash, Grep, Glob (no Write/Edit) | verifier, empirical-validation | `agents/verifier.md` |
