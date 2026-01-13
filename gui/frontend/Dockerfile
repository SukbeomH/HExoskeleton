# gui/frontend/Dockerfile
# Next.js 프론트엔드 컨테이너 이미지

FROM node:22-slim

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 의존성 설치 (필요한 경우)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    && rm -rf /var/lib/apt/lists/*

# pnpm 전역 설치
RUN npm install -g pnpm

# 의존성 파일 복사 및 설치
COPY package.json package-lock.json* ./
RUN pnpm install --frozen-lockfile

# 애플리케이션 코드 복사
COPY . .

# 포트 노출
EXPOSE 3000

# Next.js 개발 서버 실행
CMD ["pnpm", "dev"]

