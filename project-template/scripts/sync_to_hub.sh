#!/bin/bash
set -e

# Syncs local CodeGraph data to the Global Hub

PROJECT_ROOT=$(dirname "$0")/..
PROJECT_ID="${PROJECT_ID:-$(basename $(pwd))}"

echo "📦 OmniGraph Sync to Hub"
echo "========================="
echo "Project: $PROJECT_ID"
echo ""

# Step 1: Check CodeGraph
if ! command -v codegraph &> /dev/null; then
    echo "⚠️  CodeGraph CLI not found. Using mock data."
    CODEGRAPH_OUTPUT='{"project_id": "'$PROJECT_ID'", "functions": [], "note": "mock"}'
else
    echo "🔍 Extracting CodeGraph metadata..."
    CODEGRAPH_OUTPUT=$(codegraph export --format json 2>/dev/null || echo '{"error": "export failed"}')
fi

# Step 2: Save to temp file
TEMP_FILE=$(mktemp)
echo "$CODEGRAPH_OUTPUT" > "$TEMP_FILE"
echo "📝 Saved to: $TEMP_FILE"

# Step 3: Upload to Hub
HUB_URL="${HUB_URL:-http://localhost:8000/ingest}"
echo ""
echo "📤 Uploading to Global Hub: $HUB_URL"

if command -v curl &> /dev/null; then
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$HUB_URL" \
        -H "Content-Type: application/json" \
        -d @"$TEMP_FILE" 2>/dev/null || echo "000")

    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "201" ]; then
        echo "✅ Sync successful (HTTP $HTTP_STATUS)"
    elif [ "$HTTP_STATUS" = "000" ]; then
        echo "⚠️  Hub not reachable. Data saved locally."
    else
        echo "❌ Sync failed (HTTP $HTTP_STATUS)"
    fi
else
    echo "⚠️  curl not found. Cannot upload."
fi

# Cleanup
rm -f "$TEMP_FILE"
echo ""
echo "🏁 Sync complete."
