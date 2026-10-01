# RESEARCH.md Format

Written for Discovery Level 2–3 (see [discovery-protocol.md](discovery-protocol.md)) as `.hxsk/phases/{N}/RESEARCH.md`, next to the phase's plans, before planning.

```markdown
---
phase: {N}
researched_at: {YYYY-MM-DD}
discovery_level: 2 | 3
---

# Phase {N} Research

## Objective
{What question is this research answering?}

## Key Decisions

### Decision 1: {Topic}
**Question:** {What needed to be decided?}
**Options Considered:**
1. {Option A}: {pros/cons}
2. {Option B}: {pros/cons}

**Decision:** {Which option and why}
**Confidence:** {High | Medium | Low}

## Findings

### {Topic}
{What was learned}

**Sources:**
- {URL or reference}

## Patterns to Follow
- {Pattern}: {How to apply it}

## Anti-Patterns to Avoid
- {Anti-pattern}: {Why to avoid}

## Dependencies Identified
| Package | Version | Purpose |
|---------|---------|---------|
| {pkg} | {ver} | {why needed} |

## Risks
- **{Risk}:** {Impact and mitigation}

## Recommendations for Planning
1. {Recommendation}
```
