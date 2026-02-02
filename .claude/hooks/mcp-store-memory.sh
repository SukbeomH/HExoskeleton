#!/usr/bin/env bash
# MCP JSON-RPC를 통해 mcp-memory-service에 메모리 저장
# Usage: mcp-store-memory.sh <title> <content> [tags]

set -uo pipefail

TITLE="${1:?Usage: mcp-store-memory.sh <title> <content> [tags]}"
CONTENT="${2:?Missing content}"
TAGS="${3:-session-learnings,auto}"

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

# JSON escape & CALL_MSG 생성 (python3로 한 번에 처리)
CALL_MSG=$(python3 -c "
import json, sys
title, content, tags_str = sys.argv[1], sys.argv[2], sys.argv[3]
tags = ','.join([t.strip() for t in tags_str.split(',') if t.strip()])
# mcp-memory-service: content에 title을 markdown 헤더로 포함
full_content = '## ' + title + '\n\n' + content
msg = {
    'jsonrpc': '2.0', 'id': 2,
    'method': 'tools/call',
    'params': {
        'name': 'memory_store',
        'arguments': {
            'content': full_content,
            'metadata': {
                'tags': tags,
                'type': 'general'
            }
        }
    }
}
print(json.dumps(msg))
" "$TITLE" "$CONTENT" "$TAGS" 2>/dev/null)

INIT_MSG='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"hook-client","version":"1.0"}}}'
INIT_NOTIFY='{"jsonrpc":"2.0","method":"notifications/initialized"}'

RESPONSE=$(printf '%s\n%s\n%s\n' "$INIT_MSG" "$INIT_NOTIFY" "$CALL_MSG" \
    | MCP_MEMORY_SQLITE_PATH="${MCP_MEMORY_SQLITE_PATH:-}" timeout 10 memory server 2>/dev/null \
    | grep -m1 '"id":2' || echo "")

if [[ -n "$RESPONSE" ]] && echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'result' in d else 1)" 2>/dev/null; then
    exit 0
else
    exit 1
fi
