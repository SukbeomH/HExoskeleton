#!/usr/bin/env bash
# Canonical: .hxsk/hooks/_json_parse.sh
exec "$(cd "$(dirname "$0")/../.hxsk/hooks" && pwd)/$(basename "$0")" "$@"
