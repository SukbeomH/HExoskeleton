---
phase: 7
plan: 4
status: COMPLETE
completed_at: 2026-04-22
commit: 7b1175d
---

# Plan 7.4 SUMMARY: install-hooks.sh — Step 6 자동화

## 결과

Finding 2(Step 6 JSON 수동 편집 172줄)를 한 줄 명령으로 대체:

```bash
bash .hxsk/scripts/install-hooks.sh --merge
```

## 생성 파일

- `.hxsk/scripts/install-hooks.sh` (228줄)

## 핵심 동작

| 모드 | 동작 |
|------|------|
| `--merge` | 기존 `enabledPlugins` 등 비훅 설정 보존, `hooks` 키만 교체 |
| 기본 (신규 생성) | 기존 파일 `.before-hxsk.bak` 백업 후 HXSK 전체 설정으로 교체 |

## 설계 결정

- **jq 미사용**: python3 전용 (HXSK 외부 의존성 없음 원칙)
- **원자적 교체**: `os.replace()` 사용 — 부분 기록 방지
- **JSON 자동 검증**: 설치 후 `python3 -c "import json; json.load(...)"` 실행

## 검증 결과

| 검증 항목 | 결과 |
|-----------|------|
| `install-hooks.sh --merge` → "[OK] JSON 유효" | PASS |
| `enabledPlugins` 보존 확인 | PASS |
| `Stop` 훅 이벤트 존재 | PASS |
| `setup-verify.sh` | PASS 5/5 |
| `check-reliability.sh` | ISSUE COUNT: 0 |

## 불변 조건 충족

- install-hooks.sh는 순수 bash + python3만 사용 (jq 없음)
- --merge 시 `enabledPlugins`, `model` 등 비훅 설정 보존
- 생성된 settings.json은 항상 유효한 JSON
- ISSUE COUNT: 0 유지
