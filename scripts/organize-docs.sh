#!/usr/bin/env bash
# Canonical: .hxsk/hooks/organize-docs.sh
exec "$(cd "$(dirname "$0")/../.hxsk/hooks" && pwd)/$(basename "$0")" "$@"
