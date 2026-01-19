# Context7 MCP Server
# Upstash Semantic Code Search
#
# 빌드: docker build -f context7.Dockerfile -t mcp-context7 .

FROM node:20-slim

# 의존성 패키지 설치
RUN apt-get update && apt-get install -y \
  ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# 작업 디렉터리
WORKDIR /app

# Context7 MCP 서버는 npx로 실행하거나 글로벌 설치 가능
# 여기서는 캐싱을 위해 명시적으로 설치
RUN npm install -g @upstash/context7-mcp

# 엔트리포인트
# CONTEXT7_API_KEY 환경변수가 필요합니다.
ENTRYPOINT ["context7-mcp"]
