#!/usr/bin/env bash
# Canonical: .hxsk/hooks/compact-context.sh
exec "$(cd "$(dirname "$0")/../.hxsk/hooks" && pwd)/$(basename "$0")" "$@"
