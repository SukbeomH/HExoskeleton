#!/usr/bin/env bash
# MCP JSON-RPC를 통해 mcp-memory-service에서 메모리 검색
# Usage: mcp-recall-memory.sh <query> [project_path] [limit]
# mcp-store-memory.sh와 쌍을 이루는 recall helper

set -uo pipefail

QUERY="${1:?Usage: mcp-recall-memory.sh <query> [project_path] [limit]}"
PROJECT_PATH="${2:-$(pwd)}"
LIMIT="${3:-5}"

# memory 미설치 시 빈 출력
command -v memory &>/dev/null || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# .mcp.json에서 storage path 추출
if [ -z "${MCP_MEMORY_SQLITE_PATH:-}" ] && [ -f "$PROJECT_DIR/.mcp.json" ]; then
    MCP_MEMORY_SQLITE_PATH=$(python3 -c "
import json
with open('$PROJECT_DIR/.mcp.json') as f:
    cfg = json.load(f)
env = cfg.get('mcpServers',{}).get('memory',{}).get('env',{})
print(env.get('MCP_MEMORY_SQLITE_PATH',''))
" 2>/dev/null || true)
    export MCP_MEMORY_SQLITE_PATH
fi

# CALL_MSG 생성 (mcp-memory-service: memory_search with semantic mode)
CALL_MSG=$(python3 -c "
import json, sys
query, limit = sys.argv[1], int(sys.argv[2])
msg = {
    'jsonrpc': '2.0', 'id': 2,
    'method': 'tools/call',
    'params': {
        'name': 'memory_search',
        'arguments': {
            'query': query,
            'mode': 'semantic',
            'limit': limit
        }
    }
}
print(json.dumps(msg))
" "$QUERY" "$LIMIT" 2>/dev/null) || exit 0

INIT_MSG='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"hook-client","version":"1.0"}}}'
INIT_NOTIFY='{"jsonrpc":"2.0","method":"notifications/initialized"}'

RESPONSE=$(printf '%s\n%s\n%s\n' "$INIT_MSG" "$INIT_NOTIFY" "$CALL_MSG" \
    | MCP_MEMORY_SQLITE_PATH="${MCP_MEMORY_SQLITE_PATH:-}" timeout 20 memory server 2>/dev/null \
    | grep -m1 '"id":2' || echo "")

# 결과 파싱: mcp-memory-service 응답을 plain text로 출력
if [[ -n "$RESPONSE" ]]; then
    MEMO_RESPONSE="$RESPONSE" MEMO_LIMIT="$LIMIT" python3 -c '
import json, os
limit = int(os.environ.get("MEMO_LIMIT", "5"))
try:
    data = json.loads(os.environ.get("MEMO_RESPONSE", ""))
    result = data.get("result", {})
    content = result.get("content", [])
    for item in content:
        text = item.get("text", "")
        if text:
            # mcp-memory-service는 텍스트 포맷으로 반환할 수 있음
            try:
                memories = json.loads(text)
                if isinstance(memories, list):
                    for m in memories[:limit]:
                        title = m.get("title", m.get("name", ""))
                        body = m.get("content", m.get("description", ""))
                        if title:
                            print("- **%s**" % title)
                            if body:
                                summary = body[:200].replace("\n", " ")
                                print("  %s" % summary)
                        elif body:
                            summary = body[:300].replace("\n", " ")
                            print("- %s" % summary)
                elif isinstance(memories, dict):
                    body = memories.get("content", "")
                    if body:
                        print("- %s" % body[:300])
            except (json.JSONDecodeError, TypeError):
                # 텍스트 포맷 그대로 출력
                lines = text.strip().split("\n")
                for line in lines[:limit * 3]:
                    print(line)
except Exception:
    pass
'
fi
