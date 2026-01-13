# gui/backend/Dockerfile
# FastAPI 백엔드 컨테이너 이미지
# 프로젝트 표준인 uv를 사용하여 의존성을 관리합니다.

FROM python:3.12-slim

# uv 설치
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvbin/uv
RUN chmod +x /uvbin/uv

# 작업 디렉토리 설정
WORKDIR /app

# 시스템 의존성 설치 (필요한 경우)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    git \
    && rm -rf /var/lib/apt/lists/*

# 의존성 파일 복사 및 설치
COPY requirements.txt ./
# uv를 사용하여 의존성 설치 (가상 환경 생성)
RUN /uvbin/uv pip install --system -r requirements.txt

# 애플리케이션 코드 복사
COPY . .

# 포트 노출
EXPOSE 8000

# FastAPI 서버 실행
# uvicorn을 직접 실행 (uv run 대신 시스템에 설치된 uvicorn 사용)
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

