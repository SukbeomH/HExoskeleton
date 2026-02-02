#!/usr/bin/env bash
#
# scaffold-gsd.sh - Initialize GSD document structure in a project
# 템플릿에서 working docs를 복사하여 초기화. 이미 존재하는 파일은 건너뜀.
#
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TARGET="$PROJECT_DIR/.gsd"
TEMPLATES_SRC="$TARGET/templates"

echo "Scaffolding GSD documents..."
echo "  Target: ${TARGET}"
echo ""

# Create directories
mkdir -p "$TARGET" "$TARGET/templates" "$TARGET/examples" "$TARGET/archive" "$TARGET/reports" "$TARGET/research"

# ── 직접 복사 가능한 템플릿 → UPPERCASE working doc 매핑 ──
# 템플릿 파일명(lowercase) → 대상 파일명(UPPERCASE)
declare -A DIRECT_TEMPLATES=(
    ["spec.md"]="SPEC.md"
    ["decisions.md"]="DECISIONS.md"
    ["journal.md"]="JOURNAL.md"
    ["patterns.md"]="PATTERNS.md"
    ["todo.md"]="TODO.md"
    ["stack.md"]="STACK.md"
    ["current.md"]="CURRENT.md"
)

CREATED=0
SKIPPED=0

for tmpl in "${!DIRECT_TEMPLATES[@]}"; do
    dest="${DIRECT_TEMPLATES[$tmpl]}"
    if [ ! -f "$TARGET/$dest" ]; then
        if [ -f "$TEMPLATES_SRC/$tmpl" ]; then
            cp "$TEMPLATES_SRC/$tmpl" "$TARGET/$dest"
            echo "  [created] $dest (from templates/$tmpl)"
            CREATED=$((CREATED + 1))
        fi
    else
        echo "  [exists]  $dest"
        SKIPPED=$((SKIPPED + 1))
    fi
done

# ── Config 파일 (이름 그대로 복사) ──
if [ ! -f "$TARGET/context-config.yaml" ]; then
    if [ -f "$TEMPLATES_SRC/context-config.yaml" ]; then
        cp "$TEMPLATES_SRC/context-config.yaml" "$TARGET/context-config.yaml"
        echo "  [created] context-config.yaml"
        CREATED=$((CREATED + 1))
    fi
else
    echo "  [exists]  context-config.yaml"
    SKIPPED=$((SKIPPED + 1))
fi

# ── 템플릿이 없는 파일: 최소 헤더로 생성 ──
# STATE.md — state.md 템플릿은 메타(설명) 형식이므로 stub 생성
if [ ! -f "$TARGET/STATE.md" ]; then
    cat > "$TARGET/STATE.md" <<'STATEEOF'
# Project State

## Current Position
**Status:** idle

## Last Action
None — freshly initialized.

## Next Steps
1. Define project spec in SPEC.md
2. Create plan in PLAN.md

## Blockers
None

---

*Last updated: —*
STATEEOF
    echo "  [created] STATE.md (stub)"
    CREATED=$((CREATED + 1))
elif [ -f "$TARGET/STATE.md" ]; then
    echo "  [exists]  STATE.md"
    SKIPPED=$((SKIPPED + 1))
fi

# ROADMAP.md — roadmap.md 템플릿은 메타(설명) 형식이므로 stub 생성
if [ ! -f "$TARGET/ROADMAP.md" ]; then
    cat > "$TARGET/ROADMAP.md" <<'RMEOF'
# Roadmap

> **Current Phase:** —
> **Status:** planning

## Phases

*Phases will be defined after SPEC.md is finalized.*

---

*Last updated: —*
RMEOF
    echo "  [created] ROADMAP.md (stub)"
    CREATED=$((CREATED + 1))
elif [ -f "$TARGET/ROADMAP.md" ]; then
    echo "  [exists]  ROADMAP.md"
    SKIPPED=$((SKIPPED + 1))
fi

# CHANGELOG.md — 훅이 자동 생성하지만, 빈 파일이 없으면 훅이 실패할 수 있음
if [ ! -f "$TARGET/CHANGELOG.md" ]; then
    cat > "$TARGET/CHANGELOG.md" <<'CLEOF'
# Changelog

> Auto-maintained by SessionEnd hook. `.gsd/` 내부 변경은 제외됨.

---
CLEOF
    echo "  [created] CHANGELOG.md (stub)"
    CREATED=$((CREATED + 1))
elif [ -f "$TARGET/CHANGELOG.md" ]; then
    echo "  [exists]  CHANGELOG.md"
    SKIPPED=$((SKIPPED + 1))
fi

echo ""
echo "GSD scaffolding complete! (created: $CREATED, skipped: $SKIPPED)"
echo "  Working docs: .gsd/{SPEC,DECISIONS,JOURNAL,ROADMAP,PATTERNS,STATE,TODO,STACK,CHANGELOG}.md"
echo "  Config:       .gsd/context-config.yaml"
echo "  Templates:    .gsd/templates/"
echo "  Examples:     .gsd/examples/"
echo "  Directories:  .gsd/{archive,reports,research}/"
