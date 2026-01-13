# AI-Native Boilerplate

> 팀 협업을 위한 AI-Native 프로젝트 보일러플레이트 - Boris Cherny의 "Compounding Engineering" 철학을 실무에 적용

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

AI 에이전트와 함께 코드를 작성하고, 팀의 지식을 복리로 축적하여 시간이 지날수록 더 똑똑해지는 개발 환경을 구축합니다.

## 🎯 주요 특징

- **🤖 AI-Native 설계**: Claude Code, Cursor 등 AI 코딩 도구와 최적화된 워크플로우
- **📚 지식 축적**: `CLAUDE.md`를 통한 팀 단위 지식 복리화 시스템
- **🔧 Tech-Agnostic**: Node.js, Python, Go, Rust 등 다양한 스택 지원
- **✅ 검증 피드백 루프**: Plan → Execute → Verify → Human Approval 프로세스
- **🤖 Agent Skills 통합 관리**: 표준화된 서브 에이전트 시스템 (코드 분석, 보안, 로그, 시각적 검증)
- **🎨 GUI 기반 주입**: Phase 6 Boilerplate Injector로 기존 프로젝트에 쉽게 적용
- **🔒 안전한 자동화**: 백업, 병합, 선택적 적용으로 기존 설정 보호

## 🚀 빠른 시작

### 1. 보일러플레이트를 새 프로젝트에 주입

```bash
# GUI 기반 주입 (Phase 6)
mise run gui
# 브라우저에서 http://localhost:3000 접속
```

### 2. 수동 설정 (GUI 없이)

```bash
# 1. 핵심 파일 복사
cp -r .claude/ scripts/ CLAUDE.md mise.toml <your-project>/

# 2. 환경 설정
cd <your-project>
mise install

# 3. 검증
mise run verify
```

## 📁 프로젝트 구조

```
boilerplate/
├── CLAUDE.md                      # AI 페르소나 및 팀 지식 중앙 저장소
├── spec.md                        # 프로젝트 명세 템플릿
├── mise.toml                      # 통합 툴체인 관리
├── .claude/                       # Claude Code 설정
│   ├── commands/                  # 커스텀 슬래시 커맨드
│   │   ├── verify-app.sh
│   │   ├── commit-push-pr.sh
│   │   └── review-code.sh
│   ├── hooks/                     # 자동화 훅
│   │   ├── post-tool-use.js      # 포매팅 자동화
│   │   └── stop.js                # 위험 작업 검증
│   └── settings.json              # 권한 관리
├── scripts/
│   ├── core/                      # Tech-Agnostic 스크립트
│   │   ├── detect_stack.sh        # 스택 감지
│   │   ├── auto_verify.sh         # 자동 검증
│   │   ├── commit-push-pr.sh      # Git 워크플로우
│   │   └── check_env.sh           # 환경 변수 진단
│   ├── agents/                    # Agent Skills 표준 기반 서브 에이전트
│   │   ├── simplifier.js          # 코드 단순화 분석
│   │   ├── visual_verifier.js     # 시각적 검증 (웹 프로젝트)
│   │   ├── security-audit.js      # 보안 감사
│   │   ├── log_analyzer.js        # 로컬 로그 분석
│   │   └── update_claude_knowledge.js  # 지식 복리화
│   └── verify-feedback-loop.js    # 통합 검증 루프
├── gui/                           # Phase 6: Boilerplate Injector
│   ├── backend/                   # FastAPI 백엔드
│   └── frontend/                  # Next.js 프론트엔드
└── docs/
    ├── ai-onboarding.md           # AI 팀 온보딩 가이드
    └── mcp-guide.md               # MCP 서버 설정 가이드
```

## 🏗️ Phase별 구현 내역

### Phase 1: AI-Native Core Knowledge System
- ✅ `CLAUDE.md`: 팀 지식 중앙 저장소
- ✅ `spec.md`: 프로젝트 명세 템플릿
- ✅ `docs/ai-onboarding.md`: 팀 온보딩 가이드

### Phase 2: Claude Code 설정 및 자동화
- ✅ `.claude/settings.json`: 권한 관리
- ✅ `.claude/commands/`: 슬래시 커맨드
- ✅ `.claude/hooks/`: 자동화 훅
- ✅ `mise.toml`: 툴체인 관리

### Phase 3: MCP 연계 및 RIPER-5 프로토콜
- ✅ `.mcp.json`: MCP 서버 설정 (Serena, Codanna, Shrimp, Context7 등)
- ✅ RIPER-5 프로토콜 통합
- ✅ `docs/mcp-guide.md`: MCP 설정 가이드

### Phase 4: Tech-Agnostic 엔진
- ✅ `scripts/core/detect_stack.sh`: 스택 감지 엔진
- ✅ `scripts/core/auto_verify.sh`: 자동 검증
- ✅ `scripts/core/commit-push-pr.sh`: Git 워크플로우
- ✅ `scripts/core/check_env.sh`: 환경 변수 진단

### Phase 5: Agent Skills 표준 기반 서브에이전트 및 검증 피드백 루프
- ✅ `scripts/agents/`: Agent Skills 표준 기반 에이전트 라이브러리
  - `simplifier.js`: 코드 단순화 및 복잡도 분석
  - `visual_verifier.js`: 웹 프로젝트 시각적 검증 (Chrome DevTools MCP)
  - `security-audit.js`: 보안 취약점 감사 (Python: safety, Node.js: npm/pnpm audit)
  - `log_analyzer.js`: 로컬 로그 분석 및 에러 추적 (Codanna/Serena MCP 연계)
  - `update_claude_knowledge.js`: 검증 결과를 CLAUDE.md에 자동 기록
- ✅ `scripts/verify-feedback-loop.js`: 통합 검증 루프 (모든 에이전트 조율)
- ✅ `gui/backend/app/api/agents.py`: GUI 기반 에이전트 통합 관리 API
- ✅ `gui/frontend/components/AgentHub.tsx`: 에이전트 대시보드 UI

### Phase 6: GUI 기반 Boilerplate Injector
- ✅ FastAPI 백엔드 (스택 감지, 파일 주입, 사후 진단)
- ✅ Next.js 프론트엔드 (대시보드 UI)
- ✅ 안전한 주입 프로세스 (백업, 병합, 선택적 적용)

## 💻 사용 방법

### 기본 워크플로우

1. **Plan 모드**: 작업 시작 전 계획 수립
   ```
   [MODE: PLAN]
   이 기능을 구현하기 위한 계획을 세워줘
   ```

2. **Execute 모드**: 계획 승인 후 구현
   ```
   [MODE: EXECUTE]
   계획대로 구현해줘
   ```

3. **Verify**: 자동 검증 실행
   ```bash
   mise run verify
   # 또는
   .claude/commands/verify-app.sh
   ```

4. **Human Approval**: 최종 승인

### 주요 명령어

```bash
# 검증 (lint, type-check, test)
mise run verify

# 통합 검증 루프 (Agent Skills 기반)
node scripts/verify-feedback-loop.js

# 개별 에이전트 실행
node scripts/agents/simplifier.js      # 코드 단순화 분석
node scripts/agents/security-audit.js  # 보안 감사
node scripts/agents/log_analyzer.js    # 로그 분석

# 포매팅
mise run format

# 테스트
mise run test

# PR 생성 전 검토
mise run pre-pr

# GUI 실행 (Phase 6)
mise run gui
```

### 슬래시 커맨드 (Cursor/Claude Code)

- `/verify-app`: 종합 검증 실행
- `/commit-push-pr`: Git 커밋 및 PR 생성
- `/review-code`: 코드 리뷰 노트를 CLAUDE.md에 추가

## 🔧 환경 설정

### 필수 도구

- [mise](https://mise.jdx.dev/): 툴체인 관리
- Node.js 18+ (프론트엔드)
- Python 3.11+ (백엔드, 선택사항)

### 설치

```bash
# mise 설치 (macOS)
brew install mise

# 도구 설치
mise install

# 프로젝트 의존성 설치
# Python 프로젝트인 경우
cd gui/backend && pip install -r requirements.txt

# Node.js 프로젝트인 경우
cd gui/frontend && npm install
```

## 📚 문서

- [AI 온보딩 가이드](docs/ai-onboarding.md): AI와 함께 작업하는 방법
- [MCP 가이드](docs/mcp-guide.md): MCP 서버 설정 및 사용법
- [Phase 6 평가 리포트](.cursor/plans/phase6_evaluation_report.md): Phase 6 구현 상세 분석

## 🎓 핵심 개념

### Compounding Engineering

Boris Cherny의 철학으로, AI 에이전트가 과거 실수를 학습하여 시간이 지날수록 더 똑똑해지는 시스템:

- **지식 축적**: `CLAUDE.md`에 Lessons Learned 자동 기록
- **Anti-patterns**: 반복되는 실수 방지
- **Best Practices**: 검증된 패턴 축적

### RIPER-5 프로토콜

구조화된 AI 개발 워크플로우:

- **RESEARCH**: 사실 기반 분석 (Codanna 활용)
- **INNOVATE**: 솔루션 탐색
- **PLAN**: 상세 기술 명세 작성 (Shrimp Task Manager)
- **EXECUTE**: 정밀 편집 (Serena 활용)
- **REVIEW**: 검증 및 반영

### Tech-Agnostic 원칙

특정 프레임워크에 종속되지 않고, 프로젝트의 스택을 자동 감지하여 적절한 도구를 사용:

- `detect_stack.sh`로 스택 자동 감지
- 스택별 검증 도구 자동 실행
- `mise.toml`로 툴체인 통합 관리

## 🔒 보안

- **권한 관리**: `.claude/settings.json`에서 화이트리스트 기반 권한 제어
- **Stop 훅**: 위험한 작업(DB 마이그레이션, 인프라 변경) 시 사용자 승인 요구
- **환경 변수 보안**: `check_env.sh`에서 실제 값 노출 방지

## 🤝 기여

1. Issue 생성
2. Feature 브랜치 생성: `feature/{issue_number}-description`
3. 변경사항 커밋
4. PR 생성: `Resolved #{issue_number} - {description}`
5. 리뷰 후 병합

자세한 내용은 [Git Flow 규칙](.cursor/docs/raw) 참고

## 📝 라이선스

MIT License

## 🙏 감사의 글

이 프로젝트는 다음 영감을 받았습니다:

- [Boris Cherny의 Compounding Engineering](https://news.hada.io/topic?id=25570)
- [fullstack-starter](https://github.com/first-fluke/fullstack-starter)
- Claude Code 및 Cursor의 AI-Native 개발 환경

