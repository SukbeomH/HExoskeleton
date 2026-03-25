# 솔루션 비교·선정 보고서 작성 가이드

> **목적**: 비전문 의사결정자(경영진)에게 기술 솔루션 선정 결과를 보고하기 위한 체계적 가이드
> **작성일**: 2026-03-04

---

## 목차

1. [평가 프레임워크](#1-평가-프레임워크)
2. [보고서 구조](#2-보고서-구조)
3. [평가 기준 체계](#3-평가-기준-체계)
4. [시각화 가이드](#4-시각화-가이드)
5. [TCO 분석](#5-tco-분석)
6. [리스크 평가](#6-리스크-평가)
7. [추천 섹션 작성법](#7-추천-섹션-작성법)
8. [안티패턴 — 흔한 실수](#8-안티패턴--흔한-실수)
9. [템플릿 및 참고 자료](#9-템플릿-및-참고-자료)
10. [출처](#10-출처)

---

## 1. 평가 프레임워크

### 프레임워크 비교 요약

| 프레임워크 | 적합 상황 | 복잡도 | 비전문가 친화도 |
|---|---|---|---|
| **가중 평점 매트릭스** | 내부 조달 의사결정 | 중 | **높음** |
| **Pugh 매트릭스** | 초기 후보 제거 | 낮음 | 높음 |
| **AHP** | 충돌하는 다기준 복합 결정 | 높음 | 낮음 (결과는 이해 가능) |
| **TOPSIS** | 수학적 최적 순위 도출 | 높음 | 낮음 (결과는 이해 가능) |
| Gartner Magic Quadrant | 시장 수준 벤더 비교 (외부 참고) | 낮음 | 높음 |
| Forrester Wave | 상세 벤더 역량 비교 (외부 참고) | 낮음 | 높음 |

**일반 권장**: 대부분의 조직 내 의사결정에는 **가중 평점 매트릭스**가 엄밀성과 소통 용이성의 최적 균형을 제공함. 기준 가중치 자체가 논쟁적인 경우 AHP로 가중치를 도출한 뒤 매트릭스에 적용하는 하이브리드 접근을 권장.

---

### 1.1 가중 평점 매트릭스 (Weighted Scoring Matrix)

가장 널리 사용되는 내부 평가 도구.

**절차**:
1. 평가 기준 정의
2. 기준별 가중치 할당 (합계 = 100%)
3. 후보별 기준 점수 부여 (예: 1-5 또는 1-10)
4. `가중 점수 = 원점수 × 가중치`
5. 후보별 가중 점수 합산 → 최고점이 추천안

**핵심 원칙**: 벤더 접촉 **이전에** 가중치를 확정하고 문서화할 것. 사후 조정은 편향의 주요 원인.

### 1.2 Pugh 매트릭스 (개념 선택 매트릭스)

정성적 비교 방법으로, 기준 대안(datum)을 설정하고 다른 후보를 +/S/- 로 평가.

**장점**: 빠르고, 정량 데이터 불필요, 트레이드오프를 명확히 드러냄
**적합**: 후보가 5개 이상일 때 초기 제거(shortlisting) 단계

### 1.3 AHP (Analytic Hierarchy Process)

Thomas Saaty(Wharton)가 1970년대 개발. 학술적으로 가장 엄밀한 다기준 의사결정(MCDA) 방법.

**5단계**:
1. 계층 구성: 목표 → 기준 → 하위기준 → 대안
2. 기준 간 쌍대비교 (Saaty 1-9 척도)
3. 기준별 대안 쌍대비교
4. 고유벡터 가중치 계산 후 종합
5. 일관성 검증 (CR ≤ 0.1)

**활용**: 기준 가중치 도출에 사용한 뒤 결과를 가중 평점 매트릭스에 반영

### 1.4 TOPSIS

이상적 최적해(all-max)와 최악해(all-min)로부터의 기하학적 거리로 순위 결정.

**AHP-TOPSIS 하이브리드**: AHP로 가중치 도출 → TOPSIS로 순위 결정. 학술 문헌에서 소프트웨어/벤더 선정에 검증됨.

### 1.5 Gartner Magic Quadrant / Forrester Wave

외부 애널리스트 보고서로, 시장 전체 수준의 벤더 포지셔닝 참고 자료.
- **Magic Quadrant**: Vision 완성도(X) × 실행력(Y) 2×2 매트릭스
- **Forrester Wave**: 현재 제품(Y) × 전략(X) × 고객 피드백(버블 크기)

내부 평가의 보조 근거로 활용하되, 자체 평가를 대체하지 않아야 함.

---

## 2. 보고서 구조

### 역피라미드 원칙

비전문 경영진은 **첫 페이지를 읽고 나머지는 훑어봄**. 결론과 추천을 최상단에 배치.

### 권장 섹션 구성

| 섹션 | 목적 | 분량 |
|---|---|---|
| **Executive Summary** | C-Suite용 의사결정 요약 | 1-2쪽 |
| **배경 및 범위** | 이 평가를 수행한 이유 | 0.5쪽 |
| **평가 방법론** | 기준과 가중치 선정 과정 | 1쪽 |
| **기준 및 가중치** | 무엇을 왜 평가했는지 | 1-2쪽 |
| **후보 개요** | 각 솔루션 간략 프로필 | 1쪽 |
| **평가 결과** | 비교 매트릭스 + 시각화 | 2-4쪽 |
| **TCO / 비용 분석** | 정의된 기간 총비용 | 1-2쪽 |
| **리스크 평가** | 옵션별 위험 ("현상 유지" 포함) | 1-2쪽 |
| **추천** | 명확하고 자신감 있는 행동 제안 | 1쪽 |
| **다음 단계** | 일정, 담당자, 마일스톤 | 0.5쪽 |
| **부록** | 상세 점수 근거, 벤더 프로필 | 필요 시 |

### Executive Summary 5대 필수 요소

1. **문제/기회 진술** — 왜 지금 결정이 필요한가? 무행동의 비용은?
2. **평가 접근 요약** — 방법론 2-3문장
3. **핵심 발견사항** — 옵션 간 가장 중요한 차이
4. **추천안** — 직접적이고 자신감 있게 제시
5. **다음 단계** — 이 문서를 읽은 직후 할 일

**분량**: 본문의 5-10%. 대부분 1-2쪽.

**계층별 보고서 전략**:
- CEO: 1쪽 요약
- C-Suite: 3쪽 요약
- 기술/운영팀: 전체 10-20쪽 보고서

### 작문 원칙

- 능동태 사용 ("X를 추천합니다" ← "X가 추천됩니다" ✗)
- 전문 용어 첫 등장 시 반드시 일반어로 번역
- 가능한 곳에서 영향을 수치화 ("처리 시간 40% 단축", "연간 2억 원 절감")
- 자신감 있는 추천 어조: "추천드립니다", "제안합니다"

---

## 3. 평가 기준 체계

### 공통 기준 카테고리 및 가중치 범위

| 기준 카테고리 | 일반 가중치 범위 | 설명 |
|---|---|---|
| **기능 적합성** | 20-30% | 정의된 유스케이스 충족 여부 |
| **보안 및 컴플라이언스** | 15-25% | 규제 산업일수록 높게 |
| **TCO (총소유비용)** | 15-25% | 3-5년 기간 권장 |
| **통합 역량** | 10-20% | 기존 시스템 연동 |
| **벤더 지속성** | 10-15% | 재무 건전성, 로드맵 신뢰성 |
| **확장성** | 5-15% | 성장 궤적에 따라 |
| **지원 및 SLA** | 5-10% | 응답/해결 시간, 커버리지 |
| **도입 용이성** | 5-10% | 가치 실현 시간, 채택 리스크 |

### 기준별 세부 평가 항목

**기능 적합성**
- 사전 정의된 요구사항 목록(기능 명세) 기준 평가
- 벤더 마케팅이 아닌 표준화된 시나리오 기반 데모로 점수화

**기술 아키텍처**
- 배포 모델 (SaaS / On-Premise / Hybrid)
- 보안 아키텍처 (Zero Trust, 암호화)
- API 설계, 성능 벤치마크

**벤더 지속성**
- 재무 건전성 (매출, 수익성, 펀딩)
- 시장 포지션, 고객 레퍼런스
- 인수 리스크 (제품 방향 변경 가능성)

**보안 및 컴플라이언스**
- 인증: SOC 2 Type II, ISO 27001, GDPR, ISMS-P 등
- 취약점 대응 SLA (Critical CVE 패치 기한)
- 데이터 거주지 / 주권 옵션

**통합 역량**
- 기존 시스템 네이티브 연동
- API 품질 (REST/GraphQL, 문서화, 버전관리)
- SSO/SAML 호환성
- 데이터 마이그레이션 복잡도

**지원 및 SLA**
- 가용성 SLA (99.9% vs 99.99%)
- 심각도별 응답/해결 시간 보장
- 교육, 문서 품질

### Must-have vs Nice-to-have 구분

- **Must-have (필수)**: Pass/Fail 이진 판정. 미충족 시 즉시 탈락
- **Nice-to-have (우대)**: 가중 점수로 평가. 상대 비교 대상

---

## 4. 시각화 가이드

### 시각화 유형별 용도

| 유형 | 용도 | 비전문가 이해도 | 권장 위치 |
|---|---|---|---|
| **막대 차트** | 최종 가중 합산 점수 비교 | **최고** | 결과 요약, 발표 슬라이드 |
| **비교 매트릭스 표** | 기준별 상세 점수 | 높음 | 평가 결과 본문 |
| **신호등(RAG)** | Pass/Fail 빠른 스캔 | 높음 | 대시보드, 요약표 |
| **레이더 차트** | 다차원 역량 "형태" 비교 | 중 | 보조 시각화 (슬라이드) |

### 비교 매트릭스 표 작성법

```
| 기준 (가중치) | 솔루션 A | 솔루션 B | 솔루션 C |
|---|---|---|---|
| 기능 적합성 (30%) | 4.2 / **1.26** | 3.8 / 1.14 | 4.0 / 1.20 |
| 보안 (25%) | 4.5 / **1.13** | 4.5 / **1.13** | 3.5 / 0.88 |
| TCO (20%) | 3.0 / 0.60 | 4.0 / **0.80** | 3.5 / 0.70 |
| ... | ... | ... | ... |
| **합계** | **3.89** | 3.72 | 3.48 |
```

- 원점수 / **가중점수** 형식
- 행별 최고점 볼드 처리
- 합계 행 강조

### 신호등(RAG) 주의사항

- 남성 10%가 적록 색맹 → 색상만으로 정보 전달 금지
- 반드시 기호(+/△/-)나 패턴을 병행

---

## 5. TCO 분석

### 3-5년 TCO 비용 카테고리

| 카테고리 | 예시 |
|---|---|
| **취득/라이선스** | 구매비, 구독료, 사용자당 비용 |
| **구현** | 전문 서비스, SI, 데이터 마이그레이션 |
| **인프라** | 클라우드, 하드웨어, 네트워크 |
| **교육** | 초기 온보딩, 지속 학습 |
| **내부 인력** | IT 관리, 운영, 지원 시간 |
| **유지보수** | 패치, 업그레이드, 벤더 지원 계약 |
| **연동** | API 개발, 미들웨어, 커넥터 |
| **기회비용** | 전환기 생산성 손실 |
| **퇴거/전환비용** | 해지, 데이터 추출, 미래 마이그레이션 |

### 표현 방식

- 누적 막대 차트: 카테고리별 + 연도별 분리
- 콜아웃 박스: "1년차 총비용" 및 "3년 TCO" 요약
- **가장 낮은 초기 가격 ≠ 가장 낮은 TCO** — 이 점을 반드시 강조

---

## 6. 리스크 평가

### 옵션별 리스크 등록부

각 후보(+ **"현상 유지" 옵션 반드시 포함**)에 대해:

| 리스크 카테고리 | 설명 | 발생 가능성 | 영향도 | 완화 방안 |
|---|---|---|---|---|
| 구현 리스크 | 배포 복잡성, 일정 초과 | H/M/L | H/M/L | ... |
| 벤더 리스크 | 재무 불안정, 인수, 단종 | H/M/L | H/M/L | ... |
| 보안/컴플라이언스 | 데이터 처리, 규제 격차 | H/M/L | H/M/L | ... |
| 통합 리스크 | API 격차, 마이그레이션 복잡성 | H/M/L | H/M/L | ... |
| 채택 리스크 | 사용자 저항, 교육 부담 | H/M/L | H/M/L | ... |

### "현상 유지" 리스크 — 핵심 설득 도구

비전문 경영진은 무행동의 비용을 과소평가하는 경향이 있음. 가능한 곳에서 수치화:
- "현재 시스템 유지 시 연간 약 X원의 수동 처리 비용 지속"
- "규제 미준수 시 과태료 최대 Y원"

---

## 7. 추천 섹션 작성법

### 핵심 원칙

- **첫 문단에서 추천 제시** ("12페이지에 묻지 않기")
- 3개 요소 포함: (a) 무엇을 할 것인가, (b) 왜 이 옵션인가, (c) 다음에 무엇이 일어나는가
- 차순위 후보를 인정하고 미선정 사유 설명 (재논의 방지)
- **추천 전제 조건** 명시: 이 추천이 유효하기 위한 가정

### 작성 예시

> "**[솔루션 X]의 도입을 추천합니다.** 최고 가중치 기준인 보안·컴플라이언스에서 최고점을 기록했으며, 3년 TCO가 차순위 대비 18% 낮고, 동종 규모 조직에서의 검증된 도입 사례가 있습니다. 차순위인 [솔루션 Y]는 기능 적합성에서 근소하게 앞섰으나, 벤더 재무 안정성과 TCO에서 열위였습니다. 단, 향후 규제 요건이 대폭 변경될 경우 [솔루션 Y]를 재평가해야 합니다."

---

## 8. 안티패턴 — 흔한 실수

### 평가 과정 안티패턴

| 안티패턴 | 설명 | 해결책 |
|---|---|---|
| **기술 중심 프레이밍** | "어떤 기능이 필요한가?"로 시작 | "어떤 비즈니스 문제를 해결하는가?"로 시작 |
| **벤더 주도 탐색** | 벤더 마케팅이 평가 기준을 정의 | 내부에서 기준 확정 후 벤더 접촉 |
| **사후 가중치 조정** | 점수 확인 후 가중치를 바꿔 원하는 결과 도출 | 벤더 접촉 전 가중치 확정·동결 |
| **가격 우선 탈락** | 초기 가격만으로 제거 | TCO 3-5년 기준 비교 |
| **벤더 자율 데모** | 벤더가 자기 스크립트로 시연 | 동일 시나리오 기반 표준화 데모 |
| **후보 과다** | 5개 초과 최종 비교 | 3-5개로 사전 스크리닝 |
| **지연 채점** | 데모 후 수일~수주 뒤 채점 | 데모 직후 즉시 채점 |

### 보고서 작성 안티패턴

| 안티패턴 | 설명 |
|---|---|
| **결론 매몰** | 추천이 마지막 페이지에 위치 |
| **전문 용어 남발** | 일반어 번역 없이 약어·기술어 사용 |
| **데이터만, 인사이트 없음** | 점수표만 제시하고 의미 해석 부재 |
| **"현상 유지" 옵션 누락** | 무행동 비용·리스크 미제시 |
| **색상만 의존하는 신호등** | 색맹 접근성 미고려 |
| **다부서 관점 부재** | IT만의 평가 → 재무, 법무, 현업 관점 누락 |

---

## 9. 템플릿 및 참고 자료

### 정부·공공 조달 템플릿

| 출처 | 내용 | 링크 |
|---|---|---|
| US TechFAR Hub (USDS) | 기술 평가 패널 지침, 표준화 채점 | [TechFAR Hub](https://techfarhub.usds.gov/evaluation/technical-evaluation/) |
| US NIH NITAAC | 기술 평가 템플릿 | [NITAAC Template](https://nitaac.nih.gov/resources/tools-and-templates/technical-evaluation-template) |
| UK Crown Commercial Service | MoSCoW 우선순위, 가중치 템플릿, 독립 평가자 요구사항 | [UK Guidance (PDF)](https://assets.publishing.service.gov.uk/media/60a387e48fa8f56a3e32fa9a/Bid_evaluation_guidance_note_May_2021.pdf) |
| Oregon DOT | 가중 기준 평가 매트릭스 샘플 | [Oregon DOT (PDF)](https://www.oregon.gov/ODOT/Planning/TSP-Guidelines/Documents/Sample-Evaluation-Matrix.pdf) |
| World Bank | e-Procurement 시스템 평가 가이드 | [World Bank Guide (PDF)](https://thedocs.worldbank.org/en/doc/ff8055a7ae70aefefd0b08a16d8e728d-0290012024/original/Guide-for-the-Assessment-of-Electronic-Government-Procurement-Systems-Intended-for-Use-Under-MDB-Financed-Operations-FINAL-Dec-19-2023-1.pdf) |

### 상용·분석 도구

| 출처 | 내용 | 링크 |
|---|---|---|
| TEC (Technology Evaluation Centers) | ERP/CRM 등 가중 기준 비교 도구 | [TEC Selection Tools](https://www3.technologyevaluation.com/selection-tools) |
| NordLayer | 8개 섹션 사이버보안 평가 키트 | [NordLayer Kit](https://nordlayer.com/decision-makers-kit/comparing-solutions/) |
| GetApp | 소프트웨어 선택 기준 다운로드 템플릿 | [GetApp Template](https://www.getapp.com/resources/software-selection-criteria-template/) |
| Microsoft Learn | 기술 의사결정 기준 수립 프레임워크 | [MS Learn](https://learn.microsoft.com/en-us/microsoft-365/community/making-good-technology-decisions--establishing-decision-criteria) |

### 학술·연구 레퍼런스

| 출처 | 내용 | 링크 |
|---|---|---|
| AHP-TOPSIS ETL 선정 (SpringerPlus) | AHP 가중치 도출 + TOPSIS 순위 실사례 | [SpringerPlus](https://springerplus.springeropen.com/articles/10.1186/s40064-016-1888-z) |
| Hexaview AI 도구 평가 | 오픈소스 AI 도구 가중 평점 프레임워크 | [Hexaview](https://www.hexaviewtech.com/blog/evaluation-framework-weighted-scoring-model-open-source-ai-tools) |

---

## 10. 출처

### 프레임워크

- [Magic Quadrant Research Methodology — Gartner](https://www.gartner.com/en/research/methodologies/magic-quadrants-research)
- [Magic Quadrant FAQ — Gartner](https://www.gartner.com/en/about/magic-quadrant-faq)
- [Forrester Wave Methodology — Forrester](https://www.forrester.com/policies/forrester-wave-methodology/)
- [Weighted Scoring Model Guide — Savio.io](https://www.savio.io/product-roadmap/weighted-scoring-model/)
- [AHP — Wikipedia](https://en.wikipedia.org/wiki/Analytic_hierarchy_process)
- [AHP Complete Guide — Transparent Choice](https://www.transparentchoice.com/analytic-hierarchy-process)
- [AHP for Project Prioritization — PMI](https://www.pmi.org/learning/library/analytic-hierarchy-process-prioritize-projects-6608)
- [TOPSIS — Wikipedia](https://en.wikipedia.org/wiki/TOPSIS)
- [Pugh Matrix — 6Sigma.us](https://www.6sigma.us/six-sigma-in-focus/pugh-matrix/)

### 보고서 구조 및 작성법

- [Executive Summary Best Practices — Asana](https://asana.com/resources/executive-summary-examples)
- [Recommendation Reports — BC Campus](https://pressbooks.bccampus.ca/technicalwriting/chapter/longreports/)
- [How to Write a Recommendation Report — Untold Content](https://untoldcontent.com/how-to-write-a-recommendation-report/)
- [Actionable Recommendations — WHO](https://www.who.int/news/item/29-03-2025-four-practical-tips-for-actionable-and-effective-evaluation-recommendations)
- [Creating Clear Business Reports — Analyst Academy](https://www.theanalystacademy.com/creating-clear-concise-business-reports/)

### 평가 기준

- [IT Vendor Selection Criteria — TechnologyMatch](https://technologymatch.com/blog/the-essential-it-vendor-selection-criteria-and-checklist)
- [10 Essential Vendor Criteria — HOCH Solutions](https://hochsolutions.com/2025/10/01/10-essential-criteria-for-evaluating-software-vendors/)
- [Software Vendor Evaluation — G2](https://track.g2.com/resources/software-vendor-evaluation)
- [ERP Evaluation Criteria — NetSuite](https://www.netsuite.com/portal/resource/articles/erp/erp-evaluation.shtml)

### 시각화 및 리스크

- [Radar Charts Best Practices — Bold BI](https://www.boldbi.com/blog/radar-charts-best-practices-and-examples/)
- [3 Problems With KPI Traffic Lights — Stacey Barr](https://www.staceybarr.com/measure-up/3-problems-with-traditional-kpi-traffic-lights/)
- [Technology Risk Assessment — LeanIX](https://www.leanix.net/en/wiki/trm/technology-risk-assessment)
- [IT Risk Assessment — Hyperproof](https://hyperproof.io/resource/it-risk-assessment/)
- [NIST Risk Management Guide — HHS (PDF)](https://www.hhs.gov/sites/default/files/ocr/privacy/hipaa/administrative/securityrule/nist800-30.pdf)

### TCO

- [Total Cost of Ownership — TechTarget](https://www.techtarget.com/searchdatacenter/definition/TCO)
- [TCO Analysis — Procurement Tactics](https://procurementtactics.com/total-cost-of-ownership-model/)

### 안티패턴

- [Vendor Selection Bias — Olive Technologies](https://olive.app/blog/solution-selection/)
- [Mistakes in Vendor Selection — TechnologyMatch](https://technologymatch.com/blog/mistakes-you-should-avoid-in-your-vendor-selection-process)
- [Ultimate Vendor Selection Framework — Kodiakhub](https://www.kodiakhub.com/blog/vendor-selection-framework)
- [Vendor Comparison Matrix — Ramp](https://ramp.com/blog/vendor-comparison-matrix)
