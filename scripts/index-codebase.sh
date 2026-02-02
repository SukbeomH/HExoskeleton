#\!/usr/bin/env bash
#
# index-codebase.sh - code-graph-rag MCP indexing
# claude -p를 통해 MCP 도구(mcp__graph-code__index)를 호출
#
set -euo pipefail

PROJECT_DIR="${1:-$(pwd)}"
RESET="${2:-false}"

# claude CLI 필수
command -v claude >/dev/null 2>&1 || {
    echo "ERROR: claude CLI not found."
    exit 1
}

echo "=== Code Graph Indexing ==="
echo "  Directory: $PROJECT_DIR"
echo "  Reset: $RESET"
echo ""

claude -p "Run the mcp__graph-code__index tool with directory=\\"$PROJECT_DIR\\" and reset=$RESET. Then run mcp__graph-code__get_graph_stats to show the result. Output only the stats summary." \
    --model haiku \
    --allowedTools "mcp__graph-code__index,mcp__graph-code__get_graph_stats" \
    --output-format text 2>/dev/null

echo ""
echo "Index complete."
