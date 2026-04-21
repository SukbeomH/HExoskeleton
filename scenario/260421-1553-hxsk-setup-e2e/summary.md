# HXSK Setup E2E — Executive Summary

**Scenario**: 실제 사용자 입장에서 setup 단계부터 e2e 검증  
**Iterations**: 25/25 완료  
**Score**: 900 (= 25×10 + 38×15 + 10/10×30 + 4×5 + 10×3)  
**Date**: 2026-04-21

---

## Coverage Matrix

| Dimension | 탐색 | Critical | High | Medium | Low |
|-----------|------|---------|------|--------|-----|
| happy_path | ✓ | — | — | — | 1 |
| first_run_ux | ✓✓✓✓ | — | 4 | — | — |
| error_path | ✓✓✓✓✓ | 2 | 2 | 1 | — |
| upgrade_path | ✓✓✓✓✓✓ | 1 | 2 | 2 | — |
| edge_case | ✓✓✓✓✓✓✓ | 1 | 1 | 3 | 1 |
| permission | ✓ | — | 1 | — | — |
| integration | ✓ | — | — | 1 | — |
| recovery | ✓ | — | 1 | — | — |
| temporal | ✓ | — | — | 1 | — |
| concurrent | △ (1 case) | — | — | — | 1 |
| **Total** | **25** | **3** | **11** | **8** | **3** |

---

## Top Findings

### 즉시 수정 필요 (Critical × 3)

| ID | 위치 | 문제 | 수정 |
|----|------|------|------|
| C1 | setup.md Step 0 | .bootstrap-version 손상 → FRESH 오분기 → 데이터 덮어쓰기 | `CORRUPTED` 분기 추가 |
| C2 | md-store-memory.sh | 타입 디렉토리 없음 → 조용한 exit 1 → 메모리 유실 | `mkdir -p "$TARGET_DIR"` 추가 |
| C3 | setup.md U6 | `git add -A` → .env 커밋 가능 | 명시적 파일 스테이징으로 교체 |

### 신규 사용자 이탈 원인 (High × 4, first-run UX)

| ID | 위치 | 문제 |
|----|------|------|
| H1 | bootstrap.sh | FAIL 시 setup.md 참조 안내 없음 |
| H2 | setup.md 체크리스트 | 항목별 검증 명령 없음 |
| H3 | SPEC.md 플레이스홀더 | 강제 검증 없어 {placeholder} 상태로 /planner 실행 |
| H4 | SPEC.md Goals 섹션 | 형식 예시 없어 GATE-0 차단 후 해결 방법 모름 |

### 업그레이드 안정성 (High × 3, upgrade_path)

| ID | 위치 | 문제 |
|----|------|------|
| U1 | setup.md U1 | 프레임워크 수정 판별 기준 없음 → 오판 |
| U2 | setup.md U3 | rsync 폴백 검증 없음 → 빈 디렉토리 복사 |
| U3 | setup.md U6 롤백 | .bak 없을 때 git checkout 기반 복구 안내 없음 |

---

## Recommendation Roadmap

### P0 — 즉시 (데이터 손실/보안)

1. **`md-store-memory.sh`** — `mkdir -p "$TARGET_DIR"` 추가 (C2)
2. **setup.md U6** — `git add -A` → 명시적 스테이징으로 교체 (C3)
3. **setup.md Step 0** — `CORRUPTED` 분기 추가 (C1)

### P1 — 신규 사용자 경험 개선

4. **bootstrap.sh** — FAIL 메시지에 setup.md 참조 추가 (H1)
5. **setup.md 완료 체크리스트** — 각 항목에 검증 명령 1줄 추가 (H2)
6. **planner SKILL.md** — SPEC.md `{placeholder}` 경고 추가 (H3)
7. **GATES.md GATE-0** — Goals 섹션 형식 예시 추가 (H4)

### P2 — 업그레이드 안정성

8. **setup.md U1** — 파일 유형별 판별 기준 예시 추가
9. **setup.md U3** — rsync/cp 후 파일 수 검증 스텝 추가
10. **setup.md U6 롤백** — `git checkout HEAD -- <파일>` 안내 추가

### P3 — 환경 호환성

11. **setup.md Step 4** — Windows symlink 폴백 (`cp -r`) 추가
12. **setup.md Step 0** — `.bootstrap-version` 빈 파일 케이스 처리
13. **doc-lint.sh** — `ORPHAN_EXCLUDE_DIRS`에 `./scenario` 기본 추가

---

## Dimension Heatmap

```
Dimension       Coverage   Severity
──────────────────────────────────
error_path      ●●●●●      🔴🔴🟠🟠🟡
first_run_ux    ●●●●       🟠🟠🟠🟠
upgrade_path    ●●●●●●     🔴🟠🟠🟡🟡🟡
edge_case       ●●●●●●●    🔴🟠🟡🟡🟡🟢🟢
permission      ●          🟠
integration     ●          🟡
recovery        ●          🟠
temporal        ●          🟡
concurrent      △          🟢

🔴 Critical  🟠 High  🟡 Medium  🟢 Low  △ Partial
```

---

## 패턴 요약

| 패턴 | 발생 빈도 | 영향 |
|------|----------|------|
| A: 조용한 실패 | 4건 | 에이전트/사용자 인식 불가, 누적 손상 |
| B: 데이터 손실 | 3건 | 프로젝트 데이터/설정 유실 |
| C: 환경 의존성 | 5건 | 특정 환경 사용자 전체 차단 |
| D: UX 마찰 | 4건 | 신규 사용자 이탈 주요 원인 |

**핵심 인사이트**: HXSK는 기능 자체보다 "오류 발생 시 다음 단계 안내"와 "조용한 실패의 가시화"가 가장 큰 UX 취약점. 특히 신규 사용자가 setup.md를 건너뛰거나 완료 체크리스트를 검증 없이 통과하는 경로가 높은 이탈 확률을 만든다.
