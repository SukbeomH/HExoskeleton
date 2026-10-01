@../AGENTS.md

## Claude Code 전용
- 이 저장소 자체를 플러그인으로 띄워 개발한다: `claude --plugin-dir .` (훅은 플러그인 `hooks/hooks.json`으로만 등록된다).
- 압축(compaction) 시 보존: `.hxsk/.track-modifications.log`의 변경 파일 목록, SPEC.md 목표와 활성 PLAN 태스크, 이 세션의 메모리 검색 결과와 아키텍처 결정.
- 깊은 추론(아키텍처 결정, 근본 원인 디버깅, 리팩터링 영향)은 `empirical-validation` 스킬의 Thinking Budget 섹션을 따른다.
- `--dangerously-skip-permissions` 사용 금지.
