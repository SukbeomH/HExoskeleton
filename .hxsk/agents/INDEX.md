# Agents Index

> 17 agent definitions. Agents mount skills and orchestrate execution.

| Agent | Description | Model | File |
|-------|-------------|-------|------|
| arch-review | Validates architectural rules and ensures design quality | opus | `agents/arch-review.md` |
| bootstrap | Complete initial project setup -- deps verification, directory setup, codebase analysis, and memory initialization | sonnet | `agents/bootstrap.md` |
| clean | Runs code quality checks (shellcheck, shfmt) and auto-fixes issues | haiku | `agents/clean.md` |
| codebase-mapper | Analyzes existing codebases to understand structure, patterns, and technical debt | sonnet | `agents/codebase-mapper.md` |
| commit | Analyzes diffs, splits logical changes, creates conventional emoji commits | haiku | `agents/commit.md` |
| context-health-monitor | Monitors context complexity and triggers state dumps before quality degrades | haiku | `agents/context-health-monitor.md` |
| create-pr | Analyzes changes, creates branch, splits commits logically, pushes and creates PR via gh CLI | haiku | `agents/create-pr.md` |
| debugger | Systematic debugging with persistent state and fresh context advantages | opus | `agents/debugger.md` |
| dispatcher | MASTER/WORK 기반 6-Phase 병렬 이슈 오케스트레이터 (v2) | opus | `agents/dispatcher.md` |
| executor | Executes HXSK plans with atomic commits, deviation handling, checkpoint protocols | sonnet | `agents/executor.md` |
| handoff | Session handoff workflow -- git status, test, commit+push, memory store, summary | haiku | `agents/handoff.md` |
| impact-analysis | Analyzes change impact before code modifications to prevent regression | opus | `agents/impact-analysis.md` |
| plan-checker | Validates plans before execution to catch issues early | sonnet | `agents/plan-checker.md` |
| planner | Creates executable phase plans with task breakdown and dependency analysis | opus | `agents/planner.md` |
| pr-review | Multi-persona code review (Dev, QA, Security, Arch, DevOps, UX) with severity triage | opus | `agents/pr-review.md` |
| verifier | Validates implemented work against spec requirements with empirical evidence | sonnet | `agents/verifier.md` |
| write-report | Writes structured solution comparison reports for non-technical decision makers | sonnet | `agents/write-report.md` |
