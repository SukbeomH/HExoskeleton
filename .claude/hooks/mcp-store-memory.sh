#!/usr/bin/env bash
# MCP JSON-RPC를 통해 memorygraph에 메모리 저장
# Usage: mcp-store-memory.sh <title> <content> [tags]

set -uo pipefail

TITLE="${1:?Usage: mcp-store-memory.sh <title> <content> [tags]}"
CONTENT="${2:?Missing content}"
TAGS="${3:-session-learnings,auto}"

# JSON escape & tags 배열 변환
read -r TITLE_JSON CONTENT_JSON TAGS_JSON < <(python3 -c "
import json, sys
print(json.dumps(sys.argv[1]), json.dumps(sys.argv[2]), json.dumps([t.strip() for t in sys.argv[3].split(',') if t.strip()]))
" "$TITLE" "$CONTENT" "$TAGS" 2>/dev/null)

INIT_MSG='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"hook-client","version":"1.0"}}}'
INIT_NOTIFY='{"jsonrpc":"2.0","method":"notifications/initialized"}'
CALL_MSG="{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"store_memory\",\"arguments\":{\"type\":\"general\",\"title\":${TITLE_JSON},\"content\":${CONTENT_JSON},\"tags\":${TAGS_JSON}}}}"

RESPONSE=$(printf '%s\n%s\n%s\n' "$INIT_MSG" "$INIT_NOTIFY" "$CALL_MSG" \
    | timeout 10 memorygraph --profile extended 2>/dev/null \
    | grep -m1 '"id":2' || echo "")

if [[ -n "$RESPONSE" ]] && echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); exit(0 if 'result' in d else 1)" 2>/dev/null; then
    exit 0
else
    exit 1
fi
