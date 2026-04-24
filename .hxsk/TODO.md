# TODO.md — Pending Items

> Quick capture of ideas, tasks, and issues.
>
> Use `/add-todo` to add items, `/check-todos` to view.

## Format

```markdown
- [ ] Description `priority` — YYYY-MM-DD
- [x] Completed item `priority` — YYYY-MM-DD ✓ YYYY-MM-DD
```

## Priority Levels

| Level | Use For |
|-------|---------|
| `high` 🔴 | Blocking issues, urgent fixes |
| `medium` 🟡 | Normal priority (default) |
| `low` 🟢 | Nice-to-have, future ideas |

---

## Items

<!-- Active todos below -->

- [x] **[P1] hxsk-plugin hooks.json 경로 실증 검증** — 공식 스펙 확인 + 구조 검증 통과 `high` — 2026-03-06 ✓ 2026-03-06
- [x] **[A3] Antigravity IDE 훅 지원 여부 공식 확인** — 미지원 결론. session-memory.md 룰로 대체 `medium` — 2026-03-06 ✓ 2026-03-06
- [x] **[L1] ARCHITECTURE.md 컴포넌트 섹션 보완** — scaffold 스크립트, manual-utility 훅 위상 문서화 완료 `low` — 2026-03-06 ✓ 2026-03-06
- [x] **[L2] STACK.md manual-utility 훅 분류** — compact-context.sh, organize-docs.sh 위상 명시 완료 `low` — 2026-03-06 ✓ 2026-03-06
- [x] **[P3] SubagentStop prompt 타입 플러그인 지원 검증** — 공식 스펙 확인: SubagentStop + prompt 타입 공식 지원됨. 현재 hooks.json 구현 정상 `low` — 2026-03-06 ✓ 2026-03-06
- [x] **build 후 3개 타겟 통합 테스트** — 3개 타겟 모두 BUILD SUCCESSFUL `medium` — 2026-03-06 ✓ 2026-03-06
- [x] **ROADMAP.md Phase 계획 수립** — Phase 1~3 작성 완료, 상태 현행화 `medium` — 2026-03-06 ✓ 2026-03-06

- [ ] **메모리 2-hop 검색 벤치마크** — Phase 2 목표. 검색 레이턴시 + 정확도 측정 `medium` — 2026-04-24
- [ ] **강인성 테스트 인프라 (Phase 5)** — 압박 시나리오 CI 자동화. SPEC.md 작성 필요 `medium` — 2026-04-24
- [ ] **한국어 할루시네이션 연구 (Phase 6)** — Watson et al. 메트릭 한국어 적용 연구 `low` — 2026-04-24

---

*Last updated: 2026-04-24*
