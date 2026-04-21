# HXSK Setup E2E — Edge Cases & Failure Modes

**Source**: 25-iteration scenario exploration  
**Date**: 2026-04-21

---

## Summary Table

| # | 환경/조건 | 실패 모드 | Severity | 재현 용이도 |
|---|----------|----------|----------|------------|
| E1 | .bootstrap-version 손상/빈 파일 | FRESH 오분기 → 기존 데이터 덮어쓰기 | Critical | 쉬움 (touch 명령) |
| E2 | md-store-memory.sh 첫 호출 | 타입 디렉토리 없음 → 조용한 exit 1 | Critical | 쉬움 |
| E3 | git add -A + .env | 시크릿 커밋 포함 | Critical | 쉬움 |
| E4 | Windows Git Bash, Developer Mode OFF | ln -sfn 실패 → 스킬 미로드 | High | Windows 환경 |
| E5 | 부분 설치 후 재시도 | settings.json 덮어쓰기 → 커스텀 훅 소실 | High | 쉬움 |
| E6 | setup 건너뜀 + /bootstrap | 에러 메시지에 다음 단계 없음 → 이탈 | High | 쉬움 |
| E7 | SPEC.md {placeholder} 미교체 | /planner 무의미한 계획 수립 | High | 쉬움 |
| E8 | settings.json 훅 이벤트 누락 | PreCompact 미등록 → 메모리 손실 | High | 쉬움 |
| E9 | CI/공유 환경 read-only .hxsk/ | Step 3 Permission denied | High | 특수 환경 |
| E10 | SPEC.md Goals 섹션 없음 | GATE-0 차단 + 형식 안내 없음 | High | 쉬움 |
| E11 | U3 rsync 없음 + tarball 구조 불일치 | cp -r 성공 + 내용 없음 | High | Alpine 환경 |
| E12 | U6 settings.json 없는 경우 백업 스텝 스킵 | 롤백 시 .bak 파일 없음 | High | 설정 의존 |
| E13 | 완료 체크리스트 시각적 체크 | 검증 명령 없음 → /bootstrap FAIL | High | 쉬움 |
| E14 | U1 프레임워크 파일 수정 감지 | 판단 기준 없어 오판 → 커스텀 소실 | High | 쉬움 |
| E15 | GitHub 차단 + U2 옵션 없음 | 업그레이드 불가 | Medium | 특수 환경 |
| E16 | prune-memories.sh dry-run 실패 | U4에서 업그레이드 과잉 차단 | Medium | 손상된 메모리 파일 |
| E17 | bootstrap.sh memories/ 자동 생성 없음 | md-store-memory.sh exit 1 | Medium | 쉬움 |
| E18 | Cursor 1.6 (최소 1.7 미달) | 어댑터 설치해도 훅 무시 | Medium | Cursor 1.6 환경 |
| E19 | WSL2 /mnt/ 마운트 | symlink Windows 앱에서 경로 불일치 | Medium | WSL2+Windows |
| E20 | Codex CLI feature flag 미활성화 | 어댑터 설치해도 이벤트 미발화 | Medium | Codex 기본 설정 |
| E21 | setup.md 버전 ≠ TARGET_VERSION | 신규 디렉토리 동기화 누락 | Medium | 캐시된 구버전 사용 |
| E22 | scenario/learn/reason/ 디렉토리 생성 | ORPHAN-01 doc-lint 차단 | Medium | autoresearch 사용 시 |
| E23 | Claude Code + Gemini 동시 실행 | SKILL.md write race condition | Low | 동시 실행 |

---

## 재현 스크립트 (주요 케이스)

### E1: .bootstrap-version 손상 재현
```bash
echo "" > .hxsk/.bootstrap-version   # 빈 파일
# 또는
echo "corrupted content" > .hxsk/.bootstrap-version  # version: 없음
# → Step 0 실행 시 FRESH 분기
```

### E2: md-store-memory.sh 타입 디렉토리 없음
```bash
rm -rf .hxsk/memories/architecture-decision
bash .hxsk/hooks/md-store-memory.sh "test" "test" "test" "architecture-decision"
echo "Exit code: $?"   # → 1 (실패) 또는 0 (mkdir -p 있으면)
```

### E3: git add -A 시크릿 노출 시뮬레이션
```bash
echo "SECRET_KEY=abc123" > .env  # .gitignore에 없다고 가정
git add -A --dry-run | grep ".env"  # 포함 여부 확인
```

### E8: settings.json 훅 이벤트 수 확인
```bash
cat .claude/settings.json | python3 -c "
import json, sys
s = json.load(sys.stdin)
hooks = s.get('hooks', {})
print('Events registered:', list(hooks.keys()))
print('Count:', len(hooks))
"
```

### E22: doc-lint ORPHAN 확인
```bash
mkdir -p scenario/test-dir
touch scenario/test-dir/test.md
bash .hxsk/scripts/doc-lint.sh 2>&1 | grep ORPHAN
```

---

## 패턴 분류

### 패턴 A: 조용한 실패 (Silent Failure)
- E2 (md-store-memory.sh), E8 (훅 미등록), E18 (Cursor 1.6), E20 (Codex feature flag)
- **공통점**: exit code 0 반환 또는 에러 없음 → 에이전트/사용자가 성공으로 인식
- **대책**: 각 단계 후 명시적 검증 명령 추가

### 패턴 B: 데이터 손실 (Data Loss)
- E1 (FRESH 오분기), E5 (settings.json 덮어쓰기), E14 (U1 오판)
- **공통점**: 기존 파일이 경고 없이 덮어써짐
- **대책**: 기존 파일 존재 시 diff 확인 + 사용자 승인

### 패턴 C: 환경 의존성 (Environment Dependency)
- E4 (Windows), E9 (read-only), E11 (Alpine), E19 (WSL2), E23 (Cursor 버전)
- **공통점**: 특정 환경에서만 재현, 문서에 폴백 없음
- **대책**: 환경 감지 후 자동 폴백 또는 명시적 환경별 안내

### 패턴 D: UX 마찰 (UX Friction)
- E6 (에러 메시지 미흡), E7 (플레이스홀더 미교체), E10 (GATE-0 형식 안내 없음), E13 (체크리스트 미검증)
- **공통점**: 기능은 있지만 사용자가 다음 단계를 모름
- **대책**: 에러 메시지에 "다음 단계" 포함, 체크리스트에 검증 명령 추가
