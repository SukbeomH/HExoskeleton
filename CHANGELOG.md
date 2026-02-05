# Changelog

## [1.8.1](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.8.0...gsd-plugin-v1.8.1) (2026-02-05)


### Refactoring

* 순수 bash 기반 메모리 시스템으로 전환 ([#16](https://github.com/SukbeomH/LLM_Bolierplate_Pack/issues/16)) ([9299ec5](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/9299ec50d25464215d8d4f1ab59d52214469addf))

## [1.8.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.7.1...gsd-plugin-v1.8.0) (2026-02-03)


### Features

* Add E2E integration tests for the qlty CLI and introduce the Antigravity Agent guide. ([3559f51](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/3559f518db5c78408eb1a594609286d5a795a5fd))
* E2E 테스트 인프라 및 빌드 안정성 강화 ([4f0041b](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/4f0041b34fb0d53e6bdbdb95947588be48cd0169))


### Bug Fixes

* **build:** Antigravity 워크플로우 생성 개선 및 CI 호환성 확보 ([0d2be67](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/0d2be67c2d3fce31d06112f31fc371ae564ce9a8))
* **build:** 삭제된 .agent/workflows/ 의존성 제거 및 manifest 키 수정 ([66675a6](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/66675a6a0cf382d6083e236a3525b00700985f8c))

## [1.7.1](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.7.0...gsd-plugin-v1.7.1) (2026-02-03)


### Bug Fixes

* **hooks:** 메모리 세션 락 race condition 수정 및 CI 빌드 호환성 확보 ([3f6bb5d](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/3f6bb5d4e9ae836f95f6fc80f6d13ddaee34474d))
* **hooks:** 메모리 세션 락 race condition 수정 및 CI 빌드 호환성 확보 ([31845c3](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/31845c3d067657de92f08932cf730ea213440cc8))

## [1.7.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.6.0...gsd-plugin-v1.7.0) (2026-02-02)


### Features

* Add MCP memory alternatives research, a hook-to-plugin conversion script, and an agent formatting workflow. ([06c1f2d](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/06c1f2dbf29e0170febc8ce258c57b55ed81dbd5))
* **bootstrap:** Detect-Ask-Confirm 플로우 구현 (SC[#3](https://github.com/SukbeomH/LLM_Bolierplate_Pack/issues/3)) ([b3962fd](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/b3962fd43106cc1f9a9489b8a08235dc90ba5dab))
* **memory:** memorygraph → mcp-memory-service 완전 마이그레이션 ([a12dd79](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/a12dd7990bde6930e09c79ba20073acda9acd292))
* **qlty:** Qlty CLI 통합 및 다국어 부트스트랩 기반 구축 ([bea3756](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/bea37567dd65427d6e941a093323576fed83e3ed))


### Bug Fixes

* **hooks:** CHANGELOG 자동 정리/아카이빙 6개 버그 수정 및 런타임 잔재 정리 ([e4f6039](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/e4f60393b32c72eafe85d0554043afe26485bf47))
* **hooks:** remove UserPromptSubmit hook that intermittently blocks user input ([a7cace5](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/a7cace51e469e34067ac9c45e9ecc20382e7b5b6))
* **memory:** MCP_MEMORY_SQLITE_PATH 환경변수 수정 및 memorygraph 참조 전면 정리 ([d2683c8](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/d2683c8898d7aed156166dda570295f997363222))


### Refactoring

* .gsd/ 에서 templates/와 examples/만 버전 관리 ([087d5bf](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/087d5bfdb60312227060c11ee84c16de5d80909f))
* Agent-Skill 래핑 구조 개편 및 디렉토리 통합 ([96a4d32](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/96a4d326480333d5a6b15aafd5c67951784e4421))
* remove legacy .agent/workflows/ and skills symlink ([60db650](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/60db65009e0d3e507145f6de17b420a2e2cbf495))
* 디렉토리 통합 및 CHANGELOG 아카이빙 버그 수정 ([5ac44d1](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/5ac44d1ceca3582ec9511c2d79ab4fef4a78645b))


### Documentation

* **changelog:** 세션 로그 정리 — 중복 제거 및 커밋 단위 통합 ([b8ee3ae](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/b8ee3ae5f771d5d6e43874b3188e552a61752da4))
* **spec:** SC[#2](https://github.com/SukbeomH/LLM_Bolierplate_Pack/issues/2) qlty init Node.js 검증 완료 주석 업데이트 ([e1a2e3a](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/e1a2e3ad2278257b51c9c2f265c49ce9716efd31))

## [1.6.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.5.1...gsd-plugin-v1.6.0) (2026-01-30)


### Features

* **antigravity:** 스킬에 에이전트 모델 설정 주입 ([2ee2082](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/2ee2082f6bcd540a0abbad86a3b00ec25465c764))
* **hooks:** hook 자동화 경량화 및 MCP 메모리 저장 추가 ([c482d6d](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/c482d6da72694db32bbd56a7e8efd049a5186190))
* **multi-lang:** integrate Qlty CLI for multi-language bootstrap support ([7eb244a](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/7eb244aa5f981ace83cf172678969cac68a24cfa))
* **opencode:** OpenCode 빌드 스크립트 추가 ([c30f3c2](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/c30f3c27ada990849c1470b72d8adfd4fa1f9dea))


### Bug Fixes

* **antigravity:** CRLF 줄바꿈 파일 frontmatter 파싱 수정 ([d9c4b40](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/d9c4b40b3484c8653a0996cc95b47fd044a1b991))


### Documentation

* **gsd:** update SPEC.md and CHANGELOG.md for multi-language support ([9aae902](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/9aae902191fc2312c911e252d3221ee8059b925f))
* **research:** add multi-language support research documents ([5f4d983](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/5f4d983fc31a89c7ffdd299a75aac7c92034ef84))
* **research:** LLM 에이전트용 Bash CLI 도구 리서치 ([212c0c5](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/212c0c58579837943ceb90c326d2961c71907f5f))

## [1.5.1](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.5.0...gsd-plugin-v1.5.1) (2026-01-30)


### Bug Fixes

* **ci:** add --repo flag to gh release view for workflow_dispatch ([f38186b](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/f38186babfe38b579399961b43234d573f1e1b7a))
* **ci:** fix release outputs and add workflow_dispatch build ([f1a8d7d](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/f1a8d7d4f7135395961db54e3090116f9e9de225))

## [1.5.0](https://github.com/SukbeomH/LLM_Bolierplate_Pack/compare/gsd-plugin-v1.4.0...gsd-plugin-v1.5.0) (2026-01-30)


### Features

* **antigravity:** align with Antigravity IDE guidelines ([0c7a4c4](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/0c7a4c4ab6b3dc71a6117c8e7950667c1d227615))
* **gsd-plugin:** track root path for release-please ([908496b](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/908496bb86dd7e9c01853ebc384b95e2820f954d))
* **hooks:** add CRLF→LF auto-conversion to lint hook ([710488f](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/710488fd6361dfe6b532de75ee958aee5f9540df))


### Bug Fixes

* add .gitattributes to enforce LF line endings ([9798eda](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/9798eda84f90891163dc5a7bdfe0c157dec8a988))
* **hooks:** convert CRLF to LF line endings ([06e1b84](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/06e1b844e16add284d3eff1f0baaf7beb4215d6c))


### Documentation

* update Antigravity documentation ([f926955](https://github.com/SukbeomH/LLM_Bolierplate_Pack/commit/f926955cb808e577ff305d8e8479922935eb6f4e))
