# 코드 기반 명세 vs 자연언어 명세

> **조사일**: 2026-03-04
> **출처**: Benoit Essiambre
> **키워드**: code-as-spec, natural-language, Kolmogorov-complexity, literate-programming, agent-coding

---

## Essiambre의 주장

자연언어는 "참을 수 없을 정도로, 그리고 치명적으로 부정확(imprecise)" — "break"같은 단어는 수십 가지 의미.

## 코드 = 궁극의 명세

- Kolmogorov 복잡성: 완전히 명시된 정보 = 컴퓨터 프로그램
- 코드는 "exacting, and unambiguous"
- 이상적 코드베이스 = "living encyclopedic document" (도메인의 최종 지식 저장소)

## Firefox 사례

영어 명세에 의존 → 구현 간 호환성 문제 → Chromium의 코드 기반 사실상 표준이 승리.

## 하이브리드 접근

- Literate Programming + PR 워크플로우: 자연언어와 코드 통합
- 참조 구현의 과다 명시 > 저명시 (후자가 더 위험)
- 테스트 스위트로 세부사항 과다 명시 완화

## 에이전트 코딩 시사점

- 에이전트에게 자연언어 명세만 주면 불완전 → 코드 기반 명세(테스트, 타입)가 더 효과적
- AGENTS.md/CLAUDE.md의 자연언어 지침보다 **코드 자체의 구조가 더 강력한 가이드**
- 이전 리서치(Osmani)의 "코드베이스 자체를 개선하라"와 일치

---

## 출처

- [Benoit Essiambre — Code as Specification](https://benoitessiambre.com/specification.html)

*Last updated: 2026-03-04*
