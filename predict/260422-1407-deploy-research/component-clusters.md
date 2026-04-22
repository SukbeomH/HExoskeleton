---
commit_hash: 10f52791e66abef574dee28dd0d135e46e196394
---

## 클러스터 분석

| 클러스터 | 관련 파일 | 핵심 기능 | 리스크 영역 |
|----------|-----------|-----------|------------|
| **진입점** | llms.txt, README.md, setup.md (도입부) | 사용자 최초 접촉, 설치 결정 | llms.txt 인지도 낮음, README 길이 |
| **상태 관리** | setup.md Step 0, bootstrap.sh | FRESH/VERIFY/UPGRADE 분기 | CORRUPTED 복구 경험 |
| **파일 설치** | setup.md Step 4-5, symlink 로직 | 스킬/에이전트 배포 | 심볼릭 링크 실패 (Windows 미지원) |
| **훅 등록** | setup.md Step 6, settings.json JSON | Claude Code 자동화 연결 | **수동 JSON 편집 — 최대 마찰점** |
| **멀티 하네스** | adapters/ 7개 파일, adapters/README.md | 타 에이전트 지원 | 각 하네스별 수동 복사, 동기화 없음 |
| **업그레이드** | setup.md U1-U6, bootstrap.sh update 모드 | 버전 전환 | rsync --delete 위험도, 수동 커밋 |
| **플러그인 배포** | marketplace.json, plugin.json | Claude Code 네이티브 배포 | **HXSK에 미구현** |

## HXSK vs autoresearch 배포 격차 분석

### Gap 1: 플러그인 마켓플레이스 부재
- autoresearch: `/plugin install` 1줄
- HXSK: git clone + 9단계 수동 설정
- 영향: 신규 사용자 이탈 최고 구간

### Gap 2: 훅 설치 자동화
- autoresearch: plugin.json에 hooks 선언 → 자동 등록
- HXSK: settings.json JSON을 사용자/에이전트가 수동 편집
- 위험: JSON 문법 오류, 기존 설정 덮어쓰기

### Gap 3: 멀티 하네스 동기화
- autoresearch: 단일 플러그인 → Claude Code만 (공식 지원)
- HXSK: 8개 어댑터 파일 → 각각 수동 복사, 버전 동기화 없음
- 위험: 어댑터 내용이 구버전인 채로 방치

### Gap 4: 버전 고정 / 롤백
- autoresearch: SHA 기반 고정, 자동 업데이트
- HXSK: .bootstrap-version 텍스트 파일, 수동 git 조작

### Gap 5: 발견 가능성(Discoverability)
- autoresearch: GitHub 공개 저장소 + claudemarketplaces.com 등록
- HXSK: llms.txt (채택률 10%) 의존, 플러그인 마켓 미등록

## 개선 기회 클러스터

| 기회 | 구현 난이도 | 임팩트 | 우선순위 |
|------|-----------|--------|---------|
| Claude Code Plugin 패키지화 | 중간 | **매우 높음** | P0 |
| bootstrap.sh → settings.json 자동 병합 | 낮음 | 높음 | P1 |
| 어댑터 파일 단일 설치 스크립트 통합 | 낮음 | 중간 | P2 |
| GitHub Releases + 버전 태그 | 낮음 | 중간 | P2 |
| claudemarketplaces.com 등록 | 낮음 | 높음 | P1 |
| Windows 심볼릭 링크 대안 | 높음 | 낮음 | P4 |

## 웹 리서치 레퍼런스 클러스터

| 패턴 | 사례 | HXSK 적용 가능성 |
|------|------|-----------------|
| Claude Plugin Marketplace | autoresearch, everything-claude-code | **직접 적용 가능** |
| One-command installer | rustup (curl | sh), oh-my-zsh | bootstrap.sh 개선 |
| llms.txt 진입점 | HXSK 현행 | 보조 수단으로 유지 |
| GitHub Release + 버전 태그 | autoresearch 1.9.12 | HXSK 채택 권장 |
| 커뮤니티 마켓플레이스 등록 | claudemarketplaces.com (105K 방문/월) | 즉시 가능 |
