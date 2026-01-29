# GSD Plugin for Claude Code

**Get Shit Done** - AI agent development methodology with code-graph-rag and memory-graph integration.

## Installation

```bash
# Clone or copy gsd-plugin to your plugins directory
claude --plugin-dir /path/to/gsd-plugin

# Or install globally
cp -r gsd-plugin ~/.claude/plugins/gsd
```

## Prerequisites

- **Claude Code** CLI installed
- **Node.js** 18+ (for code-graph-rag MCP server)
- **Python** 3.11+ (for hook scripts)
- **uv** package manager (recommended)

### MCP Servers (Optional but Recommended)

```bash
# code-graph-rag - AST-based code analysis
npm install -g @er77/code-graph-rag-mcp

# memorygraph - Agent memory persistence
pip install memorygraph
```

### Environment Variables

플러그인의 MCP 서버가 정상 작동하려면 다음 환경변수가 필요합니다:

| 변수 | 용도 | 필수 |
|------|------|------|
| `CONTEXT7_API_KEY` | Context7 MCP (라이브러리 문서 조회) | 선택* |

> *context7을 사용하려면 프로젝트 `.mcp.json`에 직접 추가해야 합니다 (플러그인 빌드에서 제외됨)

**설정 방법:**

```bash
# ~/.zshrc 또는 ~/.bashrc
export CONTEXT7_API_KEY="your-api-key"

# 또는 direnv 사용
echo 'export CONTEXT7_API_KEY="your-api-key"' >> .envrc
direnv allow
```

**API 키 발급:** https://context7.com

## Quick Start

```bash
# Initialize GSD in your project
/gsd:init

# View all available commands
/gsd:help

# Start planning
/gsd:plan
```

## Commands

| Command | Description |
|---------|-------------|
| `/gsd:init` | Initialize GSD documents and compare infrastructure |
| `/gsd:help` | List all available commands |
| `/gsd:plan` | Create implementation plan |
| `/gsd:execute` | Execute planned work |
| `/gsd:verify` | Verify completed work |
| `/gsd:debug` | Systematic debugging workflow |
| `/gsd:map` | Map codebase structure |
| `/gsd:progress` | Show current progress |
| `/gsd:resume` | Resume paused work |
| `/gsd:pause` | Pause and save state |
| `/gsd:handoff` | Create handoff document |
| `/gsd:new-project` | Start new project |
| `/gsd:new-milestone` | Create new milestone |
| `/gsd:complete-milestone` | Mark milestone complete |
| `/gsd:add-phase` | Add execution phase |
| `/gsd:insert-phase` | Insert phase at position |
| `/gsd:remove-phase` | Remove a phase |
| `/gsd:add-todo` | Add TODO item |
| `/gsd:check-todos` | Review TODO items |
| `/gsd:feature-dev` | Feature development workflow |
| `/gsd:bug-fix` | Bug fix workflow |
| `/gsd:research-phase` | Research and discovery |
| `/gsd:discuss-phase` | Discuss phase details |
| `/gsd:list-phase-assumptions` | List phase assumptions |
| `/gsd:audit-milestone` | Audit milestone progress |
| `/gsd:plan-milestone-gaps` | Identify milestone gaps |
| `/gsd:quick-check` | Quick status check |
| `/gsd:update` | Update GSD documents |
| `/gsd:web-search` | Web search for solutions |
| `/gsd:whats-new` | Show recent changes |
| `/gsd:bootstrap` | Full project bootstrap |

## Skills

| Skill | Description |
|-------|-------------|
| `commit` | Atomic commits with conventional format |
| `create-pr` | Create pull requests |
| `pr-review` | Multi-persona code review |
| `clean` | Run code quality tools |
| `planner` | Create executable plans |
| `plan-checker` | Validate plans |
| `executor` | Execute plans |
| `verifier` | Verify work against spec |
| `debugger` | Systematic debugging |
| `impact-analysis` | Analyze change impact |
| `arch-review` | Architecture review |
| `codebase-mapper` | Map codebase structure |
| `context-health-monitor` | Monitor context complexity |
| `empirical-validation` | Require proof for completion |
| `bootstrap` | Initial project setup |

## Agents

| Agent | Description |
|-------|-------------|
| `planner` | Planning agent |
| `plan-checker` | Plan validation agent |
| `executor` | Execution agent |
| `verifier` | Verification agent |
| `debugger` | Debugging agent |
| `clean` | Code quality agent |
| `commit` | Commit creation agent |
| `create-pr` | PR creation agent |
| `pr-review` | PR review agent |
| `impact-analysis` | Impact analysis agent |
| `arch-review` | Architecture review agent |
| `codebase-mapper` | Codebase mapping agent |
| `context-health-monitor` | Context monitoring agent |

## GSD Document Structure

After `/gsd:init`, your project will have:

```
.gsd/
├── SPEC.md           # Project specification
├── DECISIONS.md      # Architecture decisions
├── JOURNAL.md        # Development journal
├── ROADMAP.md        # Project roadmap
├── templates/        # 22 document templates
└── examples/         # 3 usage examples
```

## Hooks

The plugin includes hooks for:
- **SessionStart**: Environment setup and status check
- **PreToolUse**: File protection and bash command guard
- **PostToolUse**: Auto-format Python files
- **PreCompact**: Save state before context compaction
- **Stop**: Index code changes and verify work
- **SessionEnd**: Store session summary in memory-graph

## License

MIT
