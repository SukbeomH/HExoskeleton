---
researched_at: 2026-01-28
discovery_level: 2
---

# awesome-claude-code 분석 및 보일러플레이트 비교

## Objective

awesome-claude-code 저장소를 분석하고, 현재 보일러플레이트에 활용 가능한 요소를 식별한다.

## Discovery Level

**Level 2** — 구조 분석 + 활용 가능 요소 식별

---

## 1. awesome-claude-code 개요

**목적**: Claude Code 생태계의 리소스를 큐레이션하는 커뮤니티 목록 (Awesome List)

**핵심 아키텍처**: CSV 단일 소스 → 멀티 스타일 README 자동 생성

| 항목 | 수치 |
|------|------|
| 리소스 수 | 195개 (21개 메타데이터 필드) |
| 카테고리 | 8개 메인 + 18개 서브 |
| README 스타일 | 4종 (Awesome, Extra, Classic, Flat) |
| 생성 변형 | 44개 Flat 순열 + 4개 스타일 |
| SVG 뱃지 | 446개 |
| GitHub Workflows | 11개 |
| 테스트 파일 | 24+ |
| Makefile 타겟 | 36+ |

### 디렉토리 구조 (핵심)

```
awesome-claude-code/
├── THE_RESOURCES_TABLE.csv    # 마스터 데이터 (195 리소스)
├── acc-config.yaml            # 생성 전역 설정
├── templates/
│   ├── categories.yaml        # 카테고리 정의 (단일 진실 소스)
│   └── README_*.template.md   # 4종 스타일 템플릿
├── resources/                 # 커뮤니티 리소스
│   ├── claude.md-files/       # 24개 실제 CLAUDE.md 예시
│   ├── slash-commands/        # 22개 슬래시 커맨드 구현체
│   └── workflows-knowledge-guides/
├── scripts/                   # Python 도구 (15+ 디렉토리)
│   ├── readme/                # README 생성 파이프라인
│   ├── resources/             # CSV 관리
│   └── validation/            # 링크 검증
├── tests/                     # 24+ 테스트 파일
├── .github/workflows/         # 11개 CI/CD 워크플로우
└── docs/                      # 개발자 문서
```

---

## 2. 리소스 카탈로그 (카테고리별)

### 2.1 슬래시 커맨드 (59개)

| 서브카테고리 | 수량 | 참고 활용 |
|---|---|---|
| Version Control & Git | 7 | 커밋/PR 관련 명령 패턴 |
| Code Analysis & Testing | 5 | 테스트/분석 자동화 |
| Context Loading & Priming | 6 | 컨텍스트 관리 전략 |
| Documentation & Changelogs | 5 | 문서 자동 생성 |
| Project & Task Management | 7 | 태스크 관리 패턴 |
| CI / Deployment | 2 | 배포 자동화 |
| General | 3 | 범용 유틸리티 |
| Miscellaneous | 4 | 기타 |

**경로**: `resources/slash-commands/` (22개 구현체 파일 포함)

### 2.2 CLAUDE.md 파일 (27개)

| 서브카테고리 | 수량 | 참고 활용 |
|---|---|---|
| Language-Specific | 13 | 언어별 CLAUDE.md 작성 패턴 |
| Domain-Specific | 11 | 도메인별 에이전트 지침 |
| Project Scaffolding & MCP | 2 | 프로젝트 구조 가이드 |

**경로**: `resources/claude.md-files/` (24개 실제 파일 포함)

### 2.3 워크플로우 & 가이드 (30개)

- General (30개): 다양한 개발 워크플로우 사례
- Ralph Wiggum (3개): 자율 개발 패턴

### 2.4 도구 (42개)

| 서브카테고리 | 수량 | 참고 활용 |
|---|---|---|
| General | 18 | Claude Code 기반 앱 |
| IDE Integrations | 6 | IDE 연동 패턴 |
| Usage Monitors | 5 | 사용량 모니터링 |
| Orchestrators | 7 | 에이전트 오케스트레이션 |

### 2.5 기타

| 카테고리 | 수량 |
|---|---|
| Agent Skills | 10 |
| Hooks | 11 |
| Status Lines | 5 |
| Alternative Clients | 2 |
| Official Documentation | 3 |

---

## 3. 현재 보일러플레이트와 비교

### 3.1 프로젝트 성격

| | **보일러플레이트** | **awesome-claude-code** |
|---|---|---|
| **유형** | 개발 인프라 + 워크플로우 템플릿 | 리소스 큐레이션 플랫폼 |
| **산출물** | SPEC → PLAN → 코드 → 검증 | CSV → README + 뱃지 |
| **대상** | 솔로 개발자 + AI 에이전트 | Claude Code 커뮤니티 |

### 3.2 기능 비교

| 영역 | **보일러플레이트** | **awesome-claude-code** |
|---|---|---|
| GSD 워크플로우 | 27개 슬래시 명령 | 없음 |
| 에이전트 스킬 | 10개 모듈 | 없음 |
| 인프라 | Docker + SurrealDB + CodeGraph | 없음 |
| MCP 통합 | CodeGraph + Context7 | 없음 |
| CI/CD | 없음 | 11개 GitHub Workflows |
| 테스트 | 설정만 존재 | 24+ 파일 |
| Makefile | 인프라 중심 (~10 타겟) | 생성/검증 중심 (36+ 타겟) |
| 리소스 컬렉션 | 없음 | 195개 (8카테고리) |

### 3.3 코드 품질 도구

| 도구 | **보일러플레이트** | **awesome-claude-code** |
|---|---|---|
| Ruff 규칙 | E,F,I,N,W,B,C90,PL,TC (9종) | E,F,I,N,W (5종) |
| McCabe | max-complexity=10 | 미설정 |
| Pylint | max-args=6, max-returns=6 | 미설정 |
| pep8-naming | Factory 예외 | 미설정 |
| mypy | strict 옵션 활성 | 기본 |
| VS Code | 워크스페이스 설정 포함 | 없음 |

---

## 4. 활용 가능 요소

### 4.1 즉시 참고 가능 (레퍼런스)

| 요소 | 경로 | 활용 방안 |
|---|---|---|
| CLAUDE.md 샘플 24개 | `resources/claude.md-files/` | CLAUDE.md 개선 시 언어별/도메인별 패턴 참고 |
| 슬래시 커맨드 22개 | `resources/slash-commands/` | GSD 워크플로우 확장 시 커맨드 구현 패턴 참고 |
| 워크플로우 가이드 | `resources/workflows-knowledge-guides/` | 워크플로우 문서화 형식 참고 |

### 4.2 구조적으로 도입 검토

| 요소 | 상세 | 우선순위 |
|---|---|---|
| **GitHub Workflows** | CI 테스트, 린트, 타입체크 자동화 | 높음 |
| **테스트 구조** | conftest.py + fixtures 패턴 | 높음 |
| **Makefile 확장** | lint, test, typecheck, coverage 타겟 | 중간 |
| **CONTRIBUTING.md** | 기여 가이드라인 | 오픈소스화 시 |
| **Issue 템플릿** | 구조화된 리소스 제출 폼 | 오픈소스화 시 |

### 4.3 불필요 (과도한 복잡성)

| 요소 | 사유 |
|---|---|
| 멀티 스타일 README 생성 | 보일러플레이트에 불필요한 복잡성 |
| SVG 뱃지 생성 | 큐레이션 목록 전용 기능 |
| CSV 기반 데이터 관리 | GSD 방식과 충돌 |
| 44개 Flat 순열 생성 | 보일러플레이트 성격과 무관 |

---

## 5. Patterns to Follow

- **단일 진실 소스**: `categories.yaml`로 카테고리를 한 곳에서 관리하는 패턴 → GSD 템플릿 메타데이터 관리에 적용 가능
- **클래스 기반 생성기**: 각 README 스타일이 `ReadmeGenerator` 상속 → 문서 생성 도구 설계 시 참고
- **자동화된 검증**: GitHub Actions에서 링크 검증, 포맷 체크, 중복 감지 → CI 파이프라인 설계 시 참고
- **Makefile 타겟 체계**: 기능별 그룹핑 (`make generate`, `make validate`, `make test`, `make ci`) → Makefile 확장 시 참고

## Anti-Patterns to Avoid

- **과도한 생성 변형**: 44개 Flat 순열은 유지보수 부담 → 필요한 것만 생성
- **뱃지 중심 UX**: 446개 SVG는 큐레이션 목록에는 적합하지만 개발 도구에는 과잉
- **CSV as DB**: 195개 레코드에 CSV 사용은 규모가 작아 가능, 확장 시 한계

---

## 6. Recommendations

### 즉시 실행 가능

1. **GitHub Workflows 추가**: awesome-claude-code의 CI 워크플로우 참고하여 `ruff check`, `mypy`, `pytest` 자동화
2. **Makefile 확장**: `make lint`, `make test`, `make typecheck`, `make ci` 타겟 추가
3. **테스트 구조 정비**: `tests/conftest.py` + `tests/fixtures/` 패턴 도입

### 중기 검토

4. **CLAUDE.md 개선**: `resources/claude.md-files/`의 언어별 샘플 분석 후 현재 CLAUDE.md에 누락된 패턴 보완
5. **슬래시 커맨드 확장**: `resources/slash-commands/`의 구현체 분석 후 GSD 워크플로우에 유용한 명령 추가
6. **CONTRIBUTING.md**: 오픈소스화 시 기여 가이드라인 작성

### 참고용 보관

7. **워크플로우 가이드**: `resources/workflows-knowledge-guides/`를 GSD 예제 확장 시 레퍼런스로 활용
8. **에이전트 스킬 목록**: awesome-claude-code가 추적하는 10개 에이전트 스킬을 현재 10개 스킬과 비교하여 갭 분석

---

## 7. Applied Changes (2026-01-28)

4.1 레퍼런스 분석 후 실제 보일러플레이트에 적용한 변경 사항.

### 7.1 CLAUDE.md 개선

| 추가 섹션 | 참고 소스 | 내용 |
|---|---|---|
| **MCP Tool Reference** | `claude-code-mcp-enhanced` | 4개 agentic 도구 용도, 예시 쿼리, 사용 순서 |
| **Validation Standards** | `claude-code-mcp-enhanced` | 결과 우선, 실패 전수 보고, 조건부 성공, 3회 실패 규칙 |
| **Test Policy** | `basic-memory`, `lamoom-python` | mock 최소화, 테스트 격리, 인메모리 DB, 새 기능=새 테스트 |
| **Agent Boundaries 세분화** | `EDSL`, `Giselle`, `SPy` | Always/Ask First/Never를 구체 항목으로 확장 |
| **Code Style 업데이트** | — | Ruff 9종 규칙, McCabe, Pylint, Factory 예외 반영 |

### 7.2 신규 스킬 4개 생성

| 스킬 | 경로 | 참고 소스 | 역할 |
|------|------|-----------|------|
| **commit** | `.claude/skills/commit/SKILL.md` | `slash-commands/commit/` | diff 분석, 논리적 분할, conventional emoji commit |
| **create-pr** | `.claude/skills/create-pr/SKILL.md` | `slash-commands/create-pr/` | 브랜치 생성, 커밋 분할, gh CLI로 PR 생성 |
| **pr-review** | `.claude/skills/pr-review/SKILL.md` | `slash-commands/pr-review/` | 6-페르소나 리뷰, 심각도 분류, GSD SPEC/DECISIONS 검증 |
| **clean** | `.claude/skills/clean/SKILL.md` | `slash-commands/clean/` | ruff + mypy + pytest 일괄 실행 및 auto-fix |

**기존 10개 스킬 → 14개 스킬**로 확장. GSD 실행-배포-품질 사이클 완성.

### 7.3 VERIFICATION 템플릿 개선

**파일**: `.gsd/templates/VERIFICATION.md`

| 변경 | 내용 |
|------|------|
| **심각도 분류 추가** | Blocker / High / Medium / Nitpick 4단계 |
| **Frontmatter 확장** | `blockers`, `high` 카운트 필드 |
| **Summary 테이블** | 심각도별 카운트 테이블 |
| **FAIL 항목에 Severity 필드** | 각 실패 항목에 심각도 명시 |
| **Gap Closure 심각도별 분류** | Blockers → High → Medium 순서로 정리 |
| **Next Steps 세분화** | Blocker/High/Medium 별 다른 조치 안내 |
| **Evidence Types 확장** | Type check (`mypy`), Lint clean (`ruff`) 추가 |

### 7.4 quick-check 워크플로우 신규

**파일**: `.agent/workflows/quick-check.md`

태스크 완료 직후 즉시 실행하는 경량 검증 워크플로우 (7단계):

1. 변경 파일 식별
2. Import/Compile 확인
3. Lint + Type Check (변경 파일만)
4. 관련 테스트 실행
5. 기능 검증 (변경 유형별)
6. 경고/에러 확인
7. 리포트 출력 (심각도 포함)

**기존 27개 워크플로우 → 28개**로 확장.

### 7.5 미적용 (향후 검토)

| 항목 | 사유 | 검토 시점 |
|------|------|-----------|
| GitHub Workflows CI | 별도 태스크로 분리 필요 | CI/CD 구축 시 |
| Makefile 확장 | lint/test/typecheck 타겟 | CI와 함께 |
| 테스트 구조 (conftest + fixtures) | 실제 테스트 코드 작성 시 | 첫 기능 구현 시 |
| CONTRIBUTING.md | 오픈소스화 결정 후 | 공개 시 |
| `.context/` 디렉토리 | Design principles 분리 | 프로젝트 규모 확대 시 |

---

## Sources

- `awesome-claude-code/README.md` (63KB, 195개 리소스 카탈로그)
- `awesome-claude-code/docs/README-GENERATION.md` (생성 파이프라인 문서)
- `awesome-claude-code/templates/categories.yaml` (카테고리 정의)
- `awesome-claude-code/THE_RESOURCES_TABLE.csv` (마스터 데이터)
- `awesome-claude-code/Makefile` (36+ 타겟)
- `awesome-claude-code/pyproject.toml` (Python 설정)
- `awesome-claude-code/resources/claude.md-files/` (24개 CLAUDE.md 샘플 — 7.1 적용)
- `awesome-claude-code/resources/slash-commands/commit/` (commit 스킬 원본 — 7.2 적용)
- `awesome-claude-code/resources/slash-commands/create-pr/` (create-pr 스킬 원본 — 7.2 적용)
- `awesome-claude-code/resources/slash-commands/pr-review/` (pr-review 스킬 원본 — 7.2 적용)
- `awesome-claude-code/resources/slash-commands/clean/` (clean 스킬 원본 — 7.2 적용)
- `awesome-claude-code/resources/workflows-knowledge-guides/Design-Review-Workflow/` (심각도 분류 패턴 — 7.3, 7.4 적용)
