#!/usr/bin/env bash
# Pre-commit hook: .md 파일이 스테이징되면 doc-lint 구조적 검사 실행
# 설치: ln -sf ../../.hxsk/hooks/pre-commit-doc-lint.sh .git/hooks/pre-commit
#        (또는 기존 pre-commit에서 이 스크립트를 source)

HXSK_DIR=".hxsk"
DOC_LINT="$HXSK_DIR/scripts/doc-lint.sh"

# 스테이징된 .md 파일 확인
staged_md=$(git diff --cached --name-only --diff-filter=ACMR -- '*.md' 2>/dev/null || true)

if [[ -z "$staged_md" ]]; then
    exit 0
fi

if [[ ! -f "$DOC_LINT" ]]; then
    echo "[doc-lint] $DOC_LINT not found, skipping"
    exit 0
fi

echo "=== doc-lint: .md staged, running checks ==="
bash "$DOC_LINT"
exit_code=$?

if [[ $exit_code -ne 0 ]]; then
    echo ""
    echo "doc-lint FAIL -- fix above issues before committing."
    echo "Skip with: git commit --no-verify"
fi

exit $exit_code
