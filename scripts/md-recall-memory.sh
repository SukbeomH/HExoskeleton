#!/usr/bin/env bash
# Canonical: .hxsk/hooks/md-recall-memory.sh
exec "$(cd "$(dirname "$0")/../.hxsk/hooks" && pwd)/$(basename "$0")" "$@"
