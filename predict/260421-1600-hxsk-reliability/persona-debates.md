# HXSK Reliability Predict — Persona Debates

**Session**: 260421-1600-hxsk-reliability  
**Date**: 2026-04-21

---

## Persona Roster

| ID | Role | Focus |
|----|------|-------|
| SA | Systems Architect | 환경 의존성, 전체 설계 |
| RE | Reliability Engineer | 실패 모드, 복구 경로 |
| PE | Platform Engineer | 배포, 이식성, 실행 환경 |
| SE | Security Engineer | 입력 검증, 비밀 노출 |
| DA | Devil's Advocate | 반증, 과소평가 위험 도전 |

---

## Round 1: Independent Analysis

### SA — Systems Architect

**SA-1**: `bootstrap.sh:203-210` — `.env.example` 자동 복사, warning 없음 [HIGH 초기 제안]  
**SA-2**: `prune-memories.sh:62-63` — `source "$PRUNE_CFG"` 임의 bash 실행 [HIGH 초기 제안]  
**SA-3**: `${CLAUDE_PROJECT_DIR:-.}` 패턴 전역 의존 — env 미설정 시 전체 시스템 오작동 [HIGH]  
**SA-4**: `check-consistency.sh` python3 훅 패턴 미감지 [MEDIUM]  
**SA-5/PE-5** (SA-PE 공통): `.env.example` 복사 경고 부재 [MEDIUM]  
**SA-6**: `pre-compact-save.sh` `#!/bin/bash` vs `#!/usr/bin/env bash` 불일치 [LOW]  
**SA-7**: `stop-context-save.sh:20-21` 플래그 삭제 경쟁 조건 [MEDIUM]  
**SA-8/RE-4** (SA-RE 공통): SIGKILL stale lock [MEDIUM]

### RE — Reliability Engineer

**RE-1**: `md-store-memory.sh:20-25` TYPE_DIR 누락 → general 리다이렉트 (경고 없음) [HIGH]  
**RE-2**: `md-recall-memory.sh:45` sed 종료 패턴 조기 트리거 [LOW]  
**RE-3**: `set -uo pipefail` (missing `-e`) in 훅 파일 [MEDIUM]  
**RE-4**: (SA-8/RE-4 공통) SIGKILL stale lock [MEDIUM]  
**RE-5**: `md-store-memory.sh:37-39` YAML 인젝션 [MEDIUM]  
**RE-6/PE-6** (RE-PE 공통): `head -100` 하드 캡 [MEDIUM]  
**RE-7/PE-7** (RE-PE 공통): prune awk over-match [LOW]  
**RE-8/PE-8** (RE-PE 공통): python3 훅 미참조 — pre-compact-save.sh python3 의존 미명시 [MEDIUM 초기]

### PE — Platform Engineer

**PE-1**: `pre-compact-save.sh` python3 absent → silent exit 0 [MEDIUM]  
**PE-2**: stop-context-save.sh `ls -t` mtime 정렬 불안정성 [LOW]  
**PE-3**: bootstrap.sh git config merge.ours.driver 사용자 통지 없음 [MEDIUM]  
**PE-4**: (SA-8/RE-4/PE-4 공통) stale lock [MEDIUM]  
**PE-5**: (SA-5/PE-5 공통) .env 복사 경고 부재 [MEDIUM]  
**PE-6**: (RE-6/PE-6 공통) head-100 캡 [MEDIUM]  
**PE-7**: (RE-7/PE-7 공통) prune awk over-match [LOW]  
**PE-8**: (RE-8/PE-8 공통) python3 훅 미명시 [MEDIUM 초기]

### SE — Security Engineer

**SE-1**: md-store-memory.sh YAML 인젝션 벡터 (RE-5와 동일) [MEDIUM]  
**SE-2**: prune-memories.sh config source 임의 실행 (SA-2와 동일) [HIGH 초기]  
**SE-3**: bootstrap.sh `.env` auto-copy에 secrets placeholder 포함 가능 [MEDIUM]  
**SE-4**: `git add -A` 패턴 — setup.md U6 (시나리오와 교차) [참조만]  
**SE-5**: check-consistency.sh `{placeholder}` 대소문자 미감지 (SE 독자) [MEDIUM]

### DA — Devil's Advocate

DA는 라운드 1에서 독자 발견이 아닌 기존 발견 도전에 집중:

**DA-1 도전** (→ RE-2): sed 조기 종료 — "실제 frontmatter에서 소문자 필드가 related 바로 다음에 오는 케이스가 얼마나 있나? 현재 템플릿에 해당 케이스 없음" → Probable 하향 유지

**DA-2 도전** (→ SA-2/SE-2): prune config source — "gitignored 설정 파일, 에이전트 제어 경로 없음. HIGH는 과장" → HIGH → MEDIUM 하향 합의

**DA-3 발견**: CLAUDE_PROJECT_DIR systemic risk가 CONFIRMED-01로 격상 지지 (5/5)

**DA-4 발견**: recall fallback [NO_MATCH] 부재 — SA/RE가 놓친 에이전트 혼동 위험 [HIGH]

**DA-5 도전** (→ SA-1): .env auto-copy — "most cases: .env.example에 placeholder만 있음. HIGH는 과장" → HIGH → MEDIUM 하향

---

## Round 2: Debate

### 논점 1: SA-1/.env auto-copy HIGH vs MEDIUM

**SA**: "실제 `.env.example`에 API 키 있는 프로젝트 존재. 복사 시 운영 서버 크레덴셜 활성화 위험."  
**DA**: ".env.example 컨벤션은 placeholder 전용. 실제 시크릿이 .env.example에 있다면 별도 문제."  
**SE**: "두 관점 모두 valid. 하지만 `report_warn` 추가로 문제 해결 가능. 심각도 MEDIUM, fix는 1줄."  
**합의**: MEDIUM, fix priority MEDIUM — 1줄 수정으로 위험 대부분 해소

---

### 논점 2: RE-1 vs '이미 general에 저장되는 것이 fallback이니 괜찮다'

**SA**: "general 폴더에 저장되면 타입 필터 recall이 영구 실패. architecture-decision으로 저장한 게 general에 들어가면 `md-recall-memory.sh ... architecture-decision` 쿼리로 찾을 수 없음."  
**DA**: "general 폴더 자체도 recall 가능 아닌가?"  
**RE**: "타입별 검색 경로가 `.hxsk/memories/architecture-decision/*.md` — general에 있으면 해당 경로에서 미발견. 에이전트 의사결정에 직접 영향."  
**합의**: HIGH 유지, 즉시 수정 필요

---

### 논점 3: DA-3 CLAUDE_PROJECT_DIR risk — 'env 설정 안 하는 케이스 얼마나 되나?'

**PE**: "Claude Code의 SessionStart 훅에서 CLAUDE_PROJECT_DIR이 설정됨. 실제 누락 케이스 — CI, 직접 터미널 호출, 서브에이전트."  
**SA**: "서브에이전트에서 부모 세션 env 미전달은 실제 발생. 메모리가 ~/Desktop/Hexoskeleton이 아닌 / 아래에 쌓이는 케이스 목격."  
**DA**: "합의. 이건 HIGH 맞다."  
**합의**: HIGH 5/5 CONFIRMED

---

### 논점 4: RE-8/PE-8 Python 훅 참조 미명시 severity

**RE**: "pre-compact-save.sh가 python3 호출하는데 check-consistency.sh가 이를 검증 안 함."  
**PE**: "python3은 사실상 현대 시스템에 다 있음. Alpine은 예외지만 알파인에서 Claude Code 사용 케이스 드묾."  
**DA**: "MEDIUM은 과장. pre-compact-save.sh가 python3 없으면 exit 0으로 조용히 넘어가는 건 맞지만, 실제 python3 없는 환경에서 Claude Code 쓰는 케이스 거의 없음."  
**합의**: MEDIUM → LOW 하향. predict-results.tsv에 LOW로 기록

---

## Consensus Formation

| Finding | Round 1 Max | Round 2 Δ | Final |
|---------|------------|----------|-------|
| DA-3 (env var) | HIGH | +0 | HIGH 5/5 |
| RE-1 (TYPE_DIR) | HIGH | +0 | HIGH 5/5 |
| DA-4 (fallback) | HIGH | +0 | HIGH 5/5 |
| SA-8/RE-4 (stale lock) | MEDIUM | +0 | MEDIUM 5/5 |
| RE-6/PE-6 (head-100) | MEDIUM | +0 | MEDIUM 4/5 |
| RE-3 (missing -e) | MEDIUM | +0 | MEDIUM 4/5 |
| RE-5/SE-1 (YAML inject) | MEDIUM | +0 | MEDIUM 4/5 |
| DA-5/SA-4 (python check) | MEDIUM | +0 | MEDIUM 4/5 |
| SA-1/PE-5 (.env copy) | HIGH | -1 step | MEDIUM 4/5 |
| SA-7 (flag race) | MEDIUM | +0 | MEDIUM 3/5 |
| SA-2/SE-2 (source cfg) | HIGH | -1 step | MEDIUM 3/5 |
| RE-2 (sed early exit) | LOW | +0 | LOW 2/5 |
| SA-6 (shebang) | LOW | +0 | LOW 2/5 |
| RE-7/PE-7 (awk over-match) | LOW | +0 | LOW 1/5 |
