// OpenCode plugin — HXSK prune integration.
//
// 설치:
//   mkdir -p ~/.config/opencode/plugin
//   cp .hxsk/adapters/opencode-plugin.ts ~/.config/opencode/plugin/hxsk.ts
//
// 또는 프로젝트 로컬:
//   mkdir -p .opencode/plugin && cp .hxsk/adapters/opencode-plugin.ts .opencode/plugin/hxsk.ts
//
// 효과: session.idle 또는 session.compacting 이벤트 시 .hxsk/scripts/prune-memories.sh --auto 실행.

import { $ } from "bun";

export const plugin = {
  name: "hxsk-prune",
  events: {
    async "session.idle"() {
      try {
        await $`bash .hxsk/scripts/prune-memories.sh --auto`.quiet();
      } catch {
        // silent — prune 실패는 세션에 영향 없음
      }
    },
    async "session.compacting"() {
      try {
        await $`bash .hxsk/scripts/prune-memories.sh --auto`.quiet();
      } catch {
        // silent
      }
    },
  },
};
