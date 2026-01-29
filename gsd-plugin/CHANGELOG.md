# Changelog

## [1.1.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.0.0...gsd-plugin-v1.1.0) (2026-01-29)


### Features

* **gsd-plugin:** add automatic release workflow with release-please ([1361104](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/136110423a0b1a64811c0d26bf2f13f3c51b140a))
* **gsd-plugin:** add session changelog tracking hook ([7ab5947](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/7ab5947c372398fc62c31b335b4464987327e9a3))
* Implement the gsd-plugin framework by adding new skills, commands, agents, and templates, while refactoring core configurations and removing deprecated spec files. ([5005d1f](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/5005d1fc8a7c81c7619a55ece49b424762e3eb85))


### Bug Fixes

* 훅 보안 강화 및 플러그인 메타데이터 업데이트 ([9bde872](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/9bde872f979d9cfcefcba1fb3a214eb673cb21cc))


### Documentation

* README 문서 대폭 개선 및 환경변수/참고문서 섹션 추가 ([be3d08c](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/be3d08c03939a8c1b282a1a7429225885efa719f))

## [1.0.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/releases/tag/gsd-plugin-v1.0.0) (2026-01-29)

### Features

* Initial release of GSD Plugin for Claude Code
* 31 slash commands for GSD workflow
* 14 skills for development automation
* 13 specialized agents
* Hook system (SessionStart, PreToolUse, PostToolUse, PreCompact, Stop, SessionEnd)
* MCP server integration (graph-code, memorygraph)
* GSD document templates (22 templates)

### Components

**Commands:**
- `/gsd:init`, `/gsd:plan`, `/gsd:execute`, `/gsd:verify`
- `/gsd:debug`, `/gsd:map`, `/gsd:progress`, `/gsd:resume`, `/gsd:pause`
- `/gsd:new-project`, `/gsd:new-milestone`, `/gsd:complete-milestone`
- And 19 more commands...

**Skills:**
- commit, create-pr, pr-review, clean, planner, plan-checker
- executor, verifier, debugger, impact-analysis, arch-review
- codebase-mapper, context-health-monitor, empirical-validation, bootstrap

**Agents:**
- planner, plan-checker, executor, verifier, debugger, clean
- commit, create-pr, pr-review, impact-analysis, arch-review
- codebase-mapper, context-health-monitor
