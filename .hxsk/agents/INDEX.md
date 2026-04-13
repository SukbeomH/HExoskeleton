# Agents Index

> 18 agent definitions. Agents mount skills and orchestrate execution.

| Agent | Description | Path |
|-------|-------------|------|
| arch-review | Validates architectural rules and ensures design quality | `agents/arch-review.md` |
| bootstrap | Complete initial project setup -- deps verification, directory setup, codebase analysis, and memory initialization | `agents/bootstrap.md` |
| clean | Runs code quality checks (shellcheck, shfmt) and auto-fixes issues | `agents/clean.md` |
| codebase-mapper | Analyzes existing codebases to understand structure, patterns, and technical debt | `agents/codebase-mapper.md` |
| commit | Analyzes diffs, splits logical changes, creates conventional emoji commits aligned with HXSK atomic commit protocol | `agents/commit.md` |
| context-health-monitor | Monitors context complexity and triggers state dumps before quality degrades | `agents/context-health-monitor.md` |
| create-pr | Analyzes changes, creates branch, splits commits logically, pushes and creates pull request via gh CLI | `agents/create-pr.md` |
| debugger | Systematic debugging with persistent state and fresh context advantages | `agents/debugger.md` |
| dispatcher | MASTER/WORK 기반 6-Phase 병렬 이슈 오케스트레이터 | `agents/dispatcher.md` |
| executor | Executes HXSK plans with atomic commits, deviation handling, checkpoint protocols, and state management | `agents/executor.md` |
| handoff | Session handoff workflow -- git status check, language-agnostic test execution, commit+push, session-handoff memory store, and summary output | `agents/handoff.md` |
| impact-analysis | Analyzes change impact before code modifications to prevent regression | `agents/impact-analysis.md` |
| plan-checker | Validates plans before execution to catch issues early | `agents/plan-checker.md` |
| planner | Creates executable phase plans with task breakdown, dependency analysis, and goal-backward verification | `agents/planner.md` |
| pr-review | Multi-persona code review (Dev, QA, Security, Arch, DevOps, UX) with severity triage and actionable feedback | `agents/pr-review.md` |
| spec-reviewer | Validates implementation against SPEC.md requirements -- checks what was built matches what was requested | `agents/spec-reviewer.md` |
| verifier | Validates implemented work against spec requirements with empirical evidence | `agents/verifier.md` |
| write-report | Writes structured solution comparison reports for non-technical decision makers | `agents/write-report.md` |
