#!/bin/bash
# MCP 설정 동기화 헬퍼 스크립트
# .mcp.json 파일을 파싱하여 Cursor, Claude Desktop, Windsurf 각각의 설정 포맷에 맞게 출력합니다.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MCP_JSON="$PROJECT_ROOT/.mcp.json"

if [ ! -f "$MCP_JSON" ]; then
	echo "❌ .mcp.json 파일을 찾을 수 없습니다: $MCP_JSON"
	exit 1
fi

# jq가 설치되어 있는지 확인
if ! command -v jq &> /dev/null; then
	echo "❌ jq가 설치되어 있지 않습니다. 설치 후 다시 시도하세요."
	echo "   macOS: brew install jq"
	echo "   Linux: sudo apt-get install jq"
	exit 1
fi

# 프로젝트 이름 추출 (디렉토리 이름)
PROJECT_NAME=$(basename "$PROJECT_ROOT")

echo "📋 MCP 설정 동기화 가이드"
echo "=========================================="
echo "프로젝트: $PROJECT_NAME"
echo ""

# Cursor 설정 포맷 출력
echo "🔧 Cursor IDE 설정 (Settings > Features > MCP Servers)"
echo "------------------------------------------------------"
echo ""
echo "다음 서버들을 하나씩 추가하세요:"
echo ""

jq -r '.mcpServers | to_entries[] |
  "Name: " + .key + "\n" +
  "Type: command\n" +
  "Command: " + .value.command + " " + (.value.args | join(" ")) + "\n" +
  (if .value.env and (.value.env | length) > 0 then
    "Environment Variables:\n" +
    (.value.env | to_entries[] | "  " + .key + "=" + .value) + "\n"
  else "" end) +
  "Description: " + (.value.comment // "No description") + "\n" +
  "---\n"
' "$MCP_JSON"

echo ""
echo "💡 팁:"
echo "   - 각 서버를 추가한 후 'Test Connection' 버튼으로 연결을 확인하세요."
echo "   - 이름 충돌을 방지하기 위해 프로젝트별 접두어를 사용할 수 있습니다 (예: ${PROJECT_NAME}-serena)"
echo ""

# Claude Desktop 설정 포맷 출력
echo ""
echo "🤖 Claude Desktop 설정 (Global Config)"
echo "------------------------------------------------------"
echo ""
echo "~/.config/claude_desktop_config.json 파일에 다음 내용을 추가하세요:"
echo ""

# Claude Desktop 포맷으로 변환
jq -r '{
  mcpServers: .mcpServers
}' "$MCP_JSON" | jq .

echo ""
echo "💡 팁:"
echo "   - Claude Desktop은 전역 설정을 사용하므로 모든 프로젝트에서 동일한 MCP 서버를 사용합니다."
echo "   - 프로젝트별로 다른 설정이 필요한 경우 프로젝트 루트의 .mcp.json을 사용하는 Claude Code를 권장합니다."
echo ""

# Claude Code (프로젝트 루트 자동 인식)
echo ""
echo "📝 Claude Code (CLI) 설정"
echo "------------------------------------------------------"
echo ""
echo "Claude Code는 프로젝트 루트의 .mcp.json을 자동으로 인식합니다."
echo "현재 프로젝트 루트에 .mcp.json이 있으므로 추가 설정이 필요 없습니다."
echo ""
echo "확인 방법:"
echo "  cd $PROJECT_ROOT"
echo "  claude mcp list  # MCP 서버 목록 확인"
echo ""

# Windsurf 설정 포맷 출력
echo ""
echo "🌊 Windsurf / VS Code 설정"
echo "------------------------------------------------------"
echo ""
echo "Windsurf는 VS Code 확장 프로그램을 통해 MCP를 설정합니다:"
echo ""
echo "1. VS Code 확장 프로그램에서 'MCP Client' 또는 유사한 확장을 설치하세요."
echo "2. 설정 파일 (.vscode/mcp.json 또는 전역 설정)에 다음 내용을 추가하세요:"
echo ""

# Windsurf/VS Code 포맷으로 변환
jq -r '{
  mcpServers: .mcpServers
}' "$MCP_JSON" | jq .

echo ""
echo "💡 팁:"
echo "   - Windsurf의 경우 확장 프로그램의 문서를 참조하여 정확한 설정 방법을 확인하세요."
echo ""

# 환경 변수 안내
echo ""
echo "🔐 환경 변수 설정"
echo "------------------------------------------------------"
echo ""
ENV_VARS=$(jq -r '.mcpServers[] | select(.env and (.env | length) > 0) | .env | to_entries[] | .key + "=" + .value' "$MCP_JSON" | sort -u)
if [ -n "$ENV_VARS" ]; then
	echo "다음 환경 변수들이 필요합니다:"
	echo ""
	echo "$ENV_VARS" | while IFS='=' read -r key value; do
		if [[ "$value" == \$\{*\} ]]; then
			env_name="${value#\$\{}"
			env_name="${env_name%\}}"
			echo "  $key=\$$env_name  # .env 파일에서 설정하세요"
		else
			echo "  $key=$value"
		fi
	done
	echo ""
	echo "이 변수들을 .env 파일에 추가하고 .gitignore에 포함되어 있는지 확인하세요."
else
	echo "환경 변수가 필요한 MCP 서버가 없습니다."
fi
echo ""

# 검증 스크립트
echo ""
echo "✅ 설정 검증"
echo "------------------------------------------------------"
echo ""
echo "설정이 완료된 후 다음 명령어로 MCP 서버 연결을 확인할 수 있습니다:"
echo ""
echo "  # Codanna 인덱스 확인"
echo "  # (Cursor에서 MCP 도구 사용 시 자동으로 확인됨)"
echo ""
echo "  # Serena 프로젝트 활성화"
echo "  # (Cursor에서 mcp_serena_activate_project 명령 사용)"
echo ""

