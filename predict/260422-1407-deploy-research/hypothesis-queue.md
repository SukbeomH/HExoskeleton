# Hypothesis Queue — 배포 프로세스 개선

> autoresearch:fix 또는 autoresearch:ship 체인으로 소비 가능

| Rank | ID | Hypothesis | Confidence | Location | Source Persona |
|------|----|-----------|-----------|----------|----------------|
| 1 | H-01 | `bootstrap.sh`에 CORRUPTED 분기를 추가하면 `.bootstrap-version` 손상 시 FRESH 오분기+데이터 덮어쓰기를 방지할 수 있다 | HIGH | `bootstrap.sh:26-42` | RE (confirmed 6/8) |
| 2 | H-02 | `md-store-memory.sh`에 `mkdir -p "$TYPE_DIR"` 추가 시 메모리 유실 없이 16개 타입 모두 저장된다 | HIGH | `md-store-memory.sh` | RE (confirmed 5/8) |
| 3 | H-03 | `setup.md`에 [필수]/[선택] 레이블 추가 시 신규 사용자 핵심 경로가 9단계 → 3단계로 인지된다 | HIGH | `setup.md:Step 0-9` | DA+AR+PE+UX (confirmed 5/8) |
| 4 | H-04 | `install-hooks.sh --merge` 스크립트 생성 시 Step 6 JSON 수동 편집 제거 및 커스텀 훅 보존이 가능하다 | HIGH | `setup.md:Step 6` | UX+PE (confirmed 5/8) |
| 5 | H-05 | GitHub Releases에 SHA256 체크섬 첨부 + setup.md U2에 검증 스니펫 추가 시 공급망 위험이 CRITICAL→LOW로 완화된다 | HIGH | `setup.md:U2` | SA+DE (confirmed 4/8) |
| 6 | H-06 | `scripts/install.sh --harness <name>` 구현 시 모든 하네스의 어댑터 설치가 1-liner로 완료된다 | MEDIUM | `.hxsk/adapters/`, `scripts/` | AR+DE (confirmed 3/8) |
| 7 | H-07 | `bootstrap.sh`에 로그 저장 (`tee` 패턴) 추가 시 설치 실패 재현 가능성이 확보된다 | HIGH | `bootstrap.sh` | DE+DA+RE (confirmed 3/8) |
| 8 | H-08 | symlink 실패 시 `cp -r` 폴백 추가 시 Windows 환경에서 스킬 설치 성공률이 개선된다 | HIGH | `setup.md:Step 4` | RE (minority 2/8) |
| 9 | H-09 | `hxsk-harness-sync.sh` 스크립트 생성 시 어댑터 버전 드리프트를 자동 감지·수정할 수 있다 | MEDIUM | `.hxsk/adapters/` | AR+DE (confirmed 3/8) |
| 10 | H-10 | README + `llms.txt`에 하네스별 진입 경로 Quick Decision Tree 추가 시 모든 하네스 사용자의 "첫 5분" 경험이 개선된다 | MEDIUM | `README.md`, `llms.txt` | UX+PE (probable 2/8) |

> **설계 의도 주석**: HXSK는 하네스 비종속 범용 방법론. H-06~H-10은 Claude Code 특정 채널이 아닌
> 범용 배포 경로(scripts/install.sh, harness-agnostic 문서)를 우선한다.
> Claude Code Plugin 패키징은 선택적 배포 채널 중 하나로만 위치시킨다.
