---
commit_hash: 10f52791e66abef574dee28dd0d135e46e196394
analyzed_at: 2026-04-22T14:07:00+09:00
scope: 배포 관련 파일 전체 (HXSK + autoresearch plugin)
files_analyzed: 18
---

## HXSK 배포 진입점

| 파일 | 역할 | 핵심 메커니즘 |
|------|------|--------------|
| `llms.txt` | AI 에이전트 진입점 | 리소스 인덱스. "이 문서를 읽고 구성 가능" |
| `.hxsk/prompts/setup.md` | 설치 프롬프트 (20.3KB) | Step 0 상태감지(3분기) → Step 1-9 / VERIFY / UPGRADE(U1-U6) |
| `.hxsk/scripts/bootstrap.sh` | 수렴 엔진 (477줄) | FRESH/verify/update 모드 감지, `.bootstrap-version` 기반 |
| `Makefile` | 진입점 대안 | `make setup` → bootstrap.sh + init-env |
| `README.md` | 사용자 문서 (294줄) | 뱃지, 사용법 개요 |

## autoresearch 플러그인 배포 진입점

| 파일 | 역할 | 핵심 메커니즘 |
|------|------|--------------|
| `.claude-plugin/marketplace.json` | 마켓플레이스 카탈로그 | GitHub 기반 Git 배포 |
| `claude-plugin/.claude-plugin/plugin.json` | 플러그인 메타데이터 | name, version, author, keywords |
| `scripts/install.sh` | 수동 설치 스크립트 | --claude/--opencode/--codex 플래그, -g/-l 글로벌/로컬 옵션 |

## HXSK 설치 단계 분석 (Step 0~9)

| Step | 작업 | 난이도 | 자동화 수준 |
|------|------|--------|------------|
| 0 | 상태감지 bash 스니펫 실행 | 낮음 | 반자동 (에이전트 실행) |
| 1 | llms.txt 읽기 | 낮음 | 자동 |
| 2 | 에이전트 지침 파일 설정 (CLAUDE.md 등) | 중간 | 반자동 |
| 3 | `.hxsk/` 디렉토리 구조 생성 | 중간 | 반자동 |
| 4 | 스킬/에이전트 설치 (심볼릭 링크) | 높음 | 반자동 (bash 루프) |
| 5 | 에이전트 자동 로드 경로 연결 | 중간 | 반자동 |
| 6 | 훅 설치 (settings.json 수동 편집) | **높음** | **수동** |
| 7 | 메모리 시스템 확인 | 낮음 | 반자동 |
| 8 | README 뱃지 추가 (선택) | 낮음 | 선택 |
| 9 | Multi-Harness 활성화 (선택) | 높음 | 수동 |

## autoresearch 설치 단계 분석

| 방법 | 명령 수 | 자동화 수준 | 플랫폼 |
|------|---------|------------|--------|
| Plugin Marketplace (Claude Code) | 2줄 | **완전 자동** | Claude Code 전용 |
| scripts/install.sh | 1줄 (인터랙티브) | **반자동** | Claude/OpenCode/Codex |
| 수동 파일 복사 | 많음 | 수동 | 범용 |

## 어댑터 파일 구조 (HXSK Multi-Harness)

| 하네스 | 파일 | 설치 방법 | 이벤트 |
|--------|------|-----------|--------|
| Claude Code | `.claude/settings.json` | 네이티브 통합 | Stop, PreCompact |
| Cursor 1.7+ | `cursor-hooks.json` | 파일 복사 | stop, preCompact |
| Gemini CLI | `gemini-settings.json` | 파일 복사 | SessionEnd, PreCompress |
| Copilot CLI | `copilot-hooks.json` | 파일 복사 | sessionEnd, agentStop |
| Windsurf | `windsurf-hooks.json` | 파일 복사 | post_cascade_response |
| OpenCode | `opencode-plugin.ts` | JS wrapper 필요 | session.idle |
| Codex | `codex-hooks.json` | 파일 복사 | stop |
| Aider/Continue | (미지원) | git 훅 폴백 | post-commit |

## 핵심 설계 결정 (HXSK)

- **Self-Configure 모델**: AI 에이전트가 문서를 읽고 스스로 구성 — 패키지 매니저 없음
- **Zero External Dependencies**: 순수 bash + markdown
- **Claude Code 플러그인 시스템 미사용**: 기존 배포 방식 유지
- **llms.txt 채택**: 전체 웹 채택률 10.13% (2026 기준)

## 핵심 설계 결정 (autoresearch)

- **Claude Code Plugin System 네이티브**: marketplace.json → `/plugin install` 1줄 완료
- **Multi-platform scripts/install.sh**: OpenCode, Codex도 지원
- **버전 관리**: semver (1.9.12), GitHub Releases
- **배포 채널**: GitHub 공개 저장소 → Claude Code 마켓플레이스 등록
