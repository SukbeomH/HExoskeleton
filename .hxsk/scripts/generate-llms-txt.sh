#!/usr/bin/env bash
# generate-llms-txt.sh — llms.txt를 현재 프로젝트 상태에서 동적 생성
# Usage: bash scripts/generate-llms-txt.sh [output-path]
# Default output: llms.txt (프로젝트 루트)
set -euo pipefail

OUTPUT="${1:-llms.txt}"
TODAY=$(date '+%Y-%m-%d')

# 컴포넌트 수 자동 감지
SKILL_COUNT=$(find .hxsk/skills -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
HOOK_COUNT=$(find .hxsk/hooks -name "*.sh" -o -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
AGENT_COUNT=$(find .hxsk/agents -name "*.md" -not -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')
TEMPLATE_COUNT=$(find .hxsk/templates -name "*.md" -o -name "*.yaml" -o -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
RESEARCH_COUNT=$(find .hxsk/research -name "*.md" -not -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')

# 리서치 카테고리 수
RESEARCH_CATS=0
if [ -f .hxsk/research/INDEX.md ]; then
    RESEARCH_CATS=$(grep -c '^## ' .hxsk/research/INDEX.md 2>/dev/null || echo "0")
fi

cat > "$OUTPUT" << EOF
# HExoskeleton

> AI 에이전트 기반 개발 방법론. 순수 bash + 마크다운 기반, 외부 종속성 없음.
> 어떤 코딩 에이전트든 이 문서를 읽고 프로젝트에 HXSK를 구성할 수 있습니다.
> Last Updated: ${TODAY} · Format: llms.txt v1.0

## Setup
- [Setup Prompt](.hxsk/prompts/setup.md): 어떤 에이전트든 이 프롬프트를 실행하면 HXSK 구성 완료 (Claude Code 포함)

## Agent Instructions
- [AGENTS.md](AGENTS.md): 범용 에이전트 지침 (Copilot, Cursor, Windsurf, Devin 등)
- [CLAUDE.md](CLAUDE.md): Claude Code 지침
- [GEMINI.md](GEMINI.md): Gemini CLI 지침

## Skills
- [Skills Index](.hxsk/skills/INDEX.md): ${SKILL_COUNT}개 스킬 목록 + 설명

## Hooks
- [Hooks Index](.hxsk/hooks/INDEX.md): ${HOOK_COUNT}개 훅 스크립트 목록 (Claude Code 전용)

## Agents
- [Agents Index](.hxsk/agents/INDEX.md): ${AGENT_COUNT}개 에이전트 정의

## Templates
- [Templates](.hxsk/templates/): ${TEMPLATE_COUNT}개 문서 템플릿

## Architecture
- [ARCHITECTURE.md](.hxsk/ARCHITECTURE.md): 시스템 아키텍처 + 기술 부채 현황
- [Research Index](.hxsk/research/INDEX.md): ${RESEARCH_COUNT}개 리서치 문서 카탈로그 (${RESEARCH_CATS}개 카테고리)

## Optional
- [Memory System](.hxsk/docs/MEMORY.md): 파일 기반 메모리 시스템 상세
- [Workflow Guide](.hxsk/docs/WORKFLOWS.md): SPEC→PLAN→EXECUTE→VERIFY 워크플로우
- [Skills Guide](.hxsk/docs/SKILLS.md): 스킬 상세 가이드
- [Hooks Guide](.hxsk/docs/HOOKS.md): 훅 시스템 상세
EOF

echo "[GENERATED] ${OUTPUT} (Skills:${SKILL_COUNT} Hooks:${HOOK_COUNT} Agents:${AGENT_COUNT} Templates:${TEMPLATE_COUNT} Research:${RESEARCH_COUNT})"
