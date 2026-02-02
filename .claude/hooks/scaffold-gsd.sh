#!/usr/bin/env bash
#
# scaffold-gsd.sh - Initialize GSD document structure in a project
#
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TARGET="$PROJECT_DIR/.gsd"
TEMPLATES_SRC="$PROJECT_DIR/.gsd/templates"

echo "Scaffolding GSD documents..."
echo "  Target: ${TARGET}"
echo ""

# Create directories
mkdir -p "$TARGET" "$TARGET/templates" "$TARGET/examples" "$TARGET/archive" "$TARGET/reports" "$TARGET/research"

echo ""
echo "GSD scaffolding complete!"
echo "  Working docs: .gsd/{SPEC,DECISIONS,JOURNAL,ROADMAP,PATTERNS,STATE,TODO,STACK,CHANGELOG}.md"
echo "  Config:       .gsd/context-config.yaml"
echo "  Templates:    .gsd/templates/"
echo "  Examples:     .gsd/examples/"
echo "  Directories:  .gsd/{archive,reports,research}/"
