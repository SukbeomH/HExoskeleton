# HXSK Reliability Predict — Component Clusters

**Session**: 260421-1600-hxsk-reliability

---

## Cluster A: Memory Pipeline (신뢰성 위험 최대)

**Components**: `md-store-memory.sh`, `md-recall-memory.sh`  
**Risk Level**: HIGH  

**Confirmed Issues**:
- RE-1: TYPE_DIR silent redirect (store)
- DA-4: fallback no marker (recall)
- RE-6/PE-6: head-100 cap (recall)
- RE-3: missing -e (both)
- RE-5: YAML injection (store)

**Single point of failure**: CLAUDE_PROJECT_DIR 미설정 시 두 스크립트 모두 동시 오작동

---

## Cluster B: 유지보수 자동화 (안정성 위험)

**Components**: `prune-tick.sh`, `prune-memories.sh`  
**Risk Level**: MEDIUM  

**Confirmed Issues**:
- SA-8/RE-4: stale lock (prune-tick)
- SA-2/SE-2: config source 임의 실행 (prune-memories)
- RE-7/PE-7: awk over-match (prune-memories)

---

## Cluster C: 세션 컨텍스트 저장 (데이터 손실 위험)

**Components**: `stop-context-save.sh`, `pre-compact-save.sh`  
**Risk Level**: MEDIUM  

**Confirmed Issues**:
- SA-7: flag delete race (stop-context-save)
- SA-6: shebang inconsistency (pre-compact-save)
- PE-1: python3 absent silent fail (pre-compact-save)

---

## Cluster D: 설치/검증 (UX + 보안)

**Components**: `bootstrap.sh`, `check-consistency.sh`  
**Risk Level**: MEDIUM  

**Confirmed Issues**:
- SA-1/PE-5: .env auto-copy no warning (bootstrap)
- DA-5/SA-4: python3 hook pattern miss (check-consistency)
- PE-3: merge.ours.driver silent config (bootstrap)

---

## Risk Matrix

```
          │ Low impact │ Medium impact │ High impact
──────────┼────────────┼───────────────┼────────────
High prob │            │   Cluster D   │  Cluster A
Med prob  │  Cluster B │   Cluster C   │
Low prob  │            │               │
```

**Action Priority**: A → C → D → B
