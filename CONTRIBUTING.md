# Contributing to LLM Boilerplate Pack

Thank you for your interest in contributing! This project uses **AI-native development practices**, meaning AI agents are first-class participants in the development process.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Suggesting Features](#suggesting-features)
  - [Contributing Code](#contributing-code)
- [AI-Native Development Guidelines](#ai-native-development-guidelines)
- [Development Setup](#development-setup)
- [Submitting Changes](#submitting-changes)
- [Style Guide](#style-guide)

## Code of Conduct

This project adheres to a respectful, collaborative environment. Be kind, constructive, and open-minded.

## How Can I Contribute?

### Reporting Bugs

Found a bug? Please [create a bug report](https://github.com/SukbeomH/LLM_Bolierplate_Pack/issues/new?template=bug_report.yml).

**Before submitting:**
- Search existing issues to avoid duplicates
- Gather environment details (OS, Python version, etc.)
- Include reproduction steps and error logs

### Suggesting Features

Have an idea? [Submit a feature request](https://github.com/SukbeomH/LLM_Bolierplate_Pack/issues/new?template=feature_request.yml).

**Make sure to:**
- Explain the problem you're solving
- Describe your proposed solution
- Consider how it fits with AI-native workflows

### Contributing Code

We welcome pull requests! Follow these steps:

1. **Fork & Clone** the repository
2. **Create a branch** for your feature: `git checkout -b feature/my-feature`
3. **Make your changes** following our [style guide](#style-guide)
4. **Test your changes** (see [Development Setup](#development-setup))
5. **Commit** with clear messages: `git commit -m "feat: add X"`
6. **Push** to your fork: `git push origin feature/my-feature`
7. **Open a Pull Request** against `main`

## AI-Native Development Guidelines

This project is designed to work seamlessly with AI coding assistants. When contributing:

### For Human Contributors

- **Read `CLAUDE.md`**: This file contains critical context for AI agents and helps you understand the project's architecture
- **Update Documentation**: If you add features, update relevant `.md` files so AI agents can discover them
- **Use Structured Commits**: Follow conventional commits (e.g., `feat:`, `fix:`, `docs:`)

### For AI Agents

If you're an AI agent contributing to this project:

1. **Always read `CLAUDE.md` first** - This is your source of truth
2. **Consult `RIPER.md`** for planning and execution protocols
3. **Use the `langchain_tools` agent system** for complex tasks
4. **Validate changes** using the Guardian agent's verification tools
5. **Document learnings** in appropriate knowledge bases

### Working with the Agent System

This project includes a multi-agent system (Supervisor → Architect → Artisan → Guardian → Librarian):

- **Supervisor**: Orchestrates task delegation
- **Architect**: Designs solutions
- **Artisan**: Implements code
- **Guardian**: Verifies correctness
- **Librarian**: Records knowledge

When contributing, consider which agent would handle your change and ensure your code integrates smoothly.

## Development Setup

### Prerequisites

- Python 3.11+
- [Poetry](https://python-poetry.org/) or `pip`
- Docker (for MCP server integration)

### Installation

```bash
# Clone the repository
git clone https://github.com/SukbeomH/LLM_Bolierplate_Pack.git
cd LLM_Bolierplate_Pack

# Install dependencies
poetry install
# or
pip install -e .

# Setup MCP servers (optional)
cp .env.mcp.example .env.mcp
# Edit .env.mcp with your API keys
docker-compose -f mcp/docker-compose.mcp.yml up -d
```

### Running Tests

```bash
# Run Python tests
poetry run pytest

# Run agent verification
python langchain_tools/cli.py verify
```

### Configuration

- **`.mcp.json`**: MCP server configuration
- **`pyproject.toml`**: Project dependencies and metadata
- **`CLAUDE.md`**: AI agent knowledge base

## Submitting Changes

### Pull Request Guidelines

- **Title**: Use conventional commit format (e.g., `feat: add community manager skill`)
- **Description**: Explain what and why, not just how
- **Link Issues**: Reference related issues using `#123`
- **Tests**: Ensure all tests pass
- **Documentation**: Update docs if behavior changes

### What to Expect

1. **Automated Checks**: GitHub Actions will run linting and tests
2. **AI Review**: An AI agent may provide initial feedback
3. **Human Review**: A maintainer will review and merge

## Style Guide

### Python

- Follow [PEP 8](https://peps.python.org/pep-0008/)
- Use type hints where appropriate
- Document functions with docstrings
- Keep functions focused and testable

### Markdown

- Use ATX-style headers (`#` not `===`)
- Include a table of contents for long documents
- Use code blocks with language specifiers

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `refactor:` - Code refactoring
- `test:` - Test additions or changes
- `chore:` - Maintenance tasks

Example: `feat(agent): add community-manager skill for issue triage`

## Questions?

If you have questions not covered here:

- Check the [Discussions](https://github.com/SukbeomH/LLM_Bolierplate_Pack/discussions)
- Read the project [README](README.md)
- Open an issue with the `question` label

---

**Thank you for contributing to building the future of AI-native development! 🚀**
