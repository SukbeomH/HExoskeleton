#!/usr/bin/env bash
# Canonical location: .claude/hooks/$(basename "$0")
# This wrapper delegates to the canonical copy.
exec "$(cd "$(dirname "$0")/../.claude/hooks" && pwd)/$(basename "$0")" "$@"
