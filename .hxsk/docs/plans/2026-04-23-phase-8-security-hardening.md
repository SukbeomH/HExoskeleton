# Phase 8 Plan — Security Hardening & Release Automation

**Status**: 설계 확정, 구현 대기  
**Date**: 2026-04-23  
**Prior phase**: Phase 7 (하네스 비종속 신뢰성, v5.5.0, #140)  
**Version target**: v5.6.0 / hxsk-plugin-v1.13.0

---

## Background

Phase 7 완료 후 STRIDE/OWASP 15-iteration 보안 감사 실시 (2026-04-23).
1 High, 4 Medium 발견. Phase 8는 감사 결과 기반 보안 수정 + 릴리즈 자동화가 주 목표.

Audit folder: `security/260423-1200-hxsk-hooks-scripts-audit/`

---

## Goals

1. **P0 보안 수정** — `bash-guard.py` 파일 삭제 명령 패턴 추가 (High/Confirmed)
2. **P1 보안 수정** — `file-protect.py` secrets 패턴 강화 + `md-recall-memory.sh` grep `--` 추가
3. **P1 보안 수정** — `setup.md` SHA256 검증 필수화
4. **P2 보안 개선** — `xargs -0` + `yaml_safe` 백슬래시 + 메모리 무결성 문서화
5. **release-please 설정** — `hxsk-plugin` 멀티 패키지 릴리즈 자동화
6. **메모리 age-based prune** — 카운트 전용 → 날짜+카운트 복합 정책

---

## Waves

### Wave 1 — P0 보안 수정 (bash-guard)
**Target**: `hooks/bash-guard.py`  
**Change**:
```python
DESTRUCTIVE_FS = [
    r'\brm\s+(-[^\s]*r|-r[^\s]*)',
    r'\bshred\b',
    r'\bdd\b.*\bif=/dev/zero\b',
    r'\btruncate\b.*\s0\b',
    r'\bchmod\b.*-[^\s]*R.*[0-7]*7[0-7]{2}',
    r'\bgit\s+push\b.*--mirror\b',
]
```
Merge into existing check loop.

### Wave 2 — P1 보안 수정 (file-protect + grep + SHA256)
**Target**: `hooks/file-protect.py`, `hooks/md-recall-memory.sh`, `prompts/setup.md`

1. `file-protect.py`: `"secrets/"` → `r"secrets[/.]"` + `.gitconfig` 명시적 차단
2. `md-recall-memory.sh:31`: `xargs grep -li "$QUERY"` → `xargs grep -li -- "$QUERY"`
3. `setup.md`: SHA256 블록 `# 선택` → 필수, `sha256sum` 어설션 추가

### Wave 3 — P2 개선 (robustness)
**Target**: `hooks/md-recall-memory.sh`, `hooks/md-store-memory.sh`

1. `find | xargs` → `find -print0 | xargs -0` (space-safe)
2. `yaml_safe()`: 백슬래시 이스케이프 추가
3. 메모리 무결성 trust boundary 주석 추가

### Wave 4 — release-please 자동화
**Target**: `.github/`, CI 설정

1. `release-please-config.json` — `hxsk-plugin` 패키지 설정
2. `.github/workflows/release-please.yml` — 릴리즈 자동화 워크플로우
3. CHANGELOG 포맷을 release-please 호환으로 조정

### Wave 5 — 메모리 age-based prune
**Target**: `scripts/prune-memories.sh`, `scripts/prune-tick.sh`

1. `prune-memories.sh`에 `--max-age-days N` 플래그 추가 (기본: 30일)
2. `prune-tick.sh`에서 날짜 기반 정책 적용
3. `.prune-config` 스키마에 `PRUNE_MAX_AGE_DAYS` 추가

---

## Success Criteria

- [ ] `bash-guard.py`에서 `rm -rf /tmp/test` 차단 확인
- [ ] `file-protect.py`에서 `secrets.json` 쓰기 차단 확인
- [ ] `md-recall-memory.sh`에서 `-r` QUERY가 memories 밖 검색 불가 확인
- [ ] setup.md SHA256 블록이 선택→필수로 표기 변경
- [ ] `prune-memories.sh --max-age-days 1`로 1일 초과 메모리 삭제 확인
- [ ] release-please PR이 CHANGELOG 기반으로 자동 생성 확인

---

## Risk

| Risk | Mitigation |
|------|-----------|
| bash-guard 패턴이 정상 명령 오탐 | 단위 테스트로 false-positive 확인 후 배포 |
| release-please CHANGELOG 파싱 실패 | conventional commits 형식 검증 먼저 |
| age-based prune이 중요 메모리 삭제 | `lessons-learned` 타입은 age 제외 (high-value 보호) |

---

## Notes

- `security/260423-1200-hxsk-hooks-scripts-audit/recommendations.md` — 전체 R1~R7 상세
- Wave 1~3은 단일 PR로 묶어도 무방 (모두 hooks 계층)
- Wave 4는 `.github/` 변경이므로 별도 PR 권장
- Wave 5는 Wave 1~3 이후에 시작 (메모리 무결성 경계 문서화 선행)
