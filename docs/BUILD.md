# Distribution

이 프로젝트는 빌드 스크립트가 없습니다. **레포 자체가 배포**입니다.

## Self-Configure 모델

에이전트가 레포의 `llms.txt`를 읽고 `prompts/setup.md`를 따라 프로젝트에 HXSK를 구성합니다.

### 진입점

| 파일 | 용도 |
|------|------|
| `llms.txt` | 모든 에이전트의 진입점 인덱스 |
| `AGENTS.md` | 범용 에이전트 지침 (Copilot, Cursor, Windsurf 등) |
| `CLAUDE.md` | Claude Code 전용 설정 |
| `GEMINI.md` | Gemini CLI 전용 설정 |
| `.hxsk/prompts/setup.md` | 통합 setup 프롬프트 (모든 에이전트 지원) |

### 사용법

사용자가 에이전트에게:
1. 레포 URL 전달, 또는
2. `.hxsk/prompts/setup.md` 내용 복붙

에이전트가 llms.txt를 따라가며 필요한 파일을 fetch하고 프로젝트에 배치합니다.

### 검증

```bash
bash .hxsk/scripts/verify-self-configure.sh --all
```

Layer 1 (정적 검증) + Layer 2 (시뮬레이션)을 실행합니다.

## 과거 빌드 시스템

> v1.11.1까지 3개 빌드 스크립트(plugin, antigravity, opencode)를 사용했습니다.
> Self-Configure 전환으로 빌드 스크립트가 삭제되었습니다.
> 과거 빌드 산출물은 [GitHub Releases](https://github.com/SukbeomH/HExoskeleton/releases)에서 확인할 수 있습니다.
