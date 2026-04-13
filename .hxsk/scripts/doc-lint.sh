#!/usr/bin/env bash

# Document consistency checker for HExoskeleton.
# Verifies structural integrity of all .md files:
# links, INDEX sync, counts, path references, orphans, duplicates.
#
# Usage: bash .hxsk/scripts/doc-lint.sh [--rule RULE-ID]
#
# Exit 0: All checks pass
# Exit 1: One or more checks failed

set -o errexit
set -o nounset
set -o pipefail

# ─────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

FAIL_COUNT=0
PASS_COUNT=0
TARGET_RULE="${1:-}"
RULE_ARG=""

if [[ "$TARGET_RULE" == "--rule" ]]; then
    RULE_ARG="${2:-}"
    if [[ -z "$RULE_ARG" ]]; then
        echo "Usage: doc-lint.sh --rule RULE-ID"
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "[PASS] $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "[FAIL] $1"
}

detail() {
    echo "         $1"
}

should_run() {
    [[ -z "$RULE_ARG" ]] || [[ "$RULE_ARG" == "$1" ]]
}

# Collect all .md files (exclude .git, follow no symlinks, skip gitignored runtime dirs)
mapfile -t ALL_MD < <(
    find . -name "*.md" \
        -not -path "./.git/*" \
        -not -path "./node_modules/*" \
        -not -path "./.hxsk/memories/*" \
        -not -path "./.hxsk/archive/*" \
        -not -path "./.hxsk/reports/*" \
        -not -type l | sort
)

# Gitignored 상태 파일 제외 (훅이 재생성 — orphan 의미 없음)
GITIGNORED_FILES="./.hxsk/CURRENT.md ./.hxsk/STATE.md ./.hxsk/JOURNAL.md ./.hxsk/SESSION_HANDOFF.md"
declare -a FILTERED_MD=()
for md in "${ALL_MD[@]}"; do
    skip=0
    for ign in $GITIGNORED_FILES; do
        [[ "$md" == "$ign" ]] && skip=1 && break
    done
    [[ $skip -eq 0 ]] && FILTERED_MD+=("$md")
done
ALL_MD=("${FILTERED_MD[@]}")

# Directories excluded from orphan detection (no INDEX, managed differently)
# research/는 INDEX 있지만 각 문서 plain-text로만 언급하므로 별도 exclude
ORPHAN_EXCLUDE_DIRS="./.hxsk/memories ./.hxsk/templates ./.hxsk/archive ./.hxsk/issues ./.hxsk/examples ./docs/plans ./.hxsk/docs/plans ./.hxsk/reports ./.hxsk/research"

# Directories excluded from LINK-01 (과거 계획 문서/research 링크는 역사적 기록으로 허용)
LINK_EXCLUDE_DIRS="./.hxsk/docs/plans ./docs/plans ./.hxsk/research"

# ─────────────────────────────────────────────────────
# LINK-01: 상대 링크 유효성
# ─────────────────────────────────────────────────────

rule_link_01() {
    local total=0
    local broken=0
    local broken_list=()

    for md in "${ALL_MD[@]}"; do
        # LINK_EXCLUDE_DIRS는 검사 스킵 (역사적 기록)
        local skip_file=0
        for exc_dir in $LINK_EXCLUDE_DIRS; do
            if [[ "$md" == "${exc_dir}"/* ]]; then
                skip_file=1
                break
            fi
        done
        [[ $skip_file -eq 1 ]] && continue

        local dir
        dir="$(dirname "$md")"

        # Extract markdown links: [text](path)
        while IFS= read -r line_info; do
            [[ -z "$line_info" ]] && continue
            local lineno="${line_info%%:*}"
            local link="${line_info#*:}"

            # Skip empty, http, mailto
            [[ -z "$link" ]] && continue
            [[ "$link" =~ ^https?:// ]] && continue
            [[ "$link" =~ ^mailto: ]] && continue
            # Skip template variables (e.g. ${CLAUDE_PLUGIN_ROOT}/path)
            [[ "$link" =~ \$\{ ]] && continue

            # Strip anchor (file.md#section → file.md)
            local file_part="${link%%#*}"
            [[ -z "$file_part" ]] && continue

            total=$((total + 1))

            if [[ ! -e "$dir/$file_part" ]]; then
                broken=$((broken + 1))
                broken_list+=("$md:$lineno → $link")
            fi
        done < <(perl -ne 'while (/\[([^\]]*)\]\(([^)]+)\)/g) { print "$.:$2\n" }' "$md" 2>/dev/null || true)
    done

    local valid=$((total - broken))
    if [[ $broken -eq 0 ]]; then
        pass "LINK-01: 상대 링크 유효성 ($valid/$total)"
    else
        fail "LINK-01: 상대 링크 깨짐 ${broken}건 (유효 $valid/$total)"
        for item in "${broken_list[@]}"; do
            detail "$item"
        done
    fi
}

# ─────────────────────────────────────────────────────
# INDEX-01: INDEX.md 목록 vs 실제 파일 차집합
# ─────────────────────────────────────────────────────

rule_index_01() {
    local total_missing=0
    local total_extra=0
    local has_failure=0

    # Directories that have INDEX.md
    local index_dirs=()
    while IFS= read -r idx; do
        index_dirs+=("$(dirname "$idx")")
    done < <(find .hxsk -name "INDEX.md" 2>/dev/null | sort)

    if [[ ${#index_dirs[@]} -eq 0 ]]; then
        pass "INDEX-01: INDEX.md 없음 — 건너뜀"
        return
    fi

    for dir in "${index_dirs[@]}"; do
        local index_file="$dir/INDEX.md"

        # Extract referenced .md files from INDEX.md
        # 3가지 형식 모두 지원: [text](path.md), `path.md`, 또는 plain filename.md
        local indexed_str
        indexed_str=$({
            grep -oE '\([^)]+\.md[^)]*\)' "$index_file" 2>/dev/null | \
                sed 's/^(//;s/)$//' | sed 's/#.*//'
            grep -oE '`[^`]+\.md`' "$index_file" 2>/dev/null | \
                sed 's/^`//;s/`$//'
            grep -oE '[A-Za-z0-9_.-]+\.md' "$index_file" 2>/dev/null
        } | sort -u || true)

        # Actual .md files in directory (excluding INDEX.md itself)
        # SKILL.md가 있는 하위 디렉토리는 SKILL.md만 대표 — 같은 dir의 보조 문서는 제외
        local actual_str
        actual_str=$({
            find "$dir" -name "*.md" -not -name "INDEX.md" 2>/dev/null | \
                while IFS= read -r f; do
                    fdir="$(dirname "$f")"
                    fbase="$(basename "$f")"
                    # 같은 sub-dir에 SKILL.md가 있고 본인은 SKILL.md가 아니면 보조 문서
                    if [[ -f "$fdir/SKILL.md" && "$fbase" != "SKILL.md" ]]; then
                        continue
                    fi
                    echo "$f"
                done
        } | sed "s|^$dir/||" | sort || true)

        [[ -z "$actual_str" ]] && continue

        # Find files in actual but not in index
        local missing_count=0
        local missing_items=""
        while IFS= read -r actual; do
            [[ -z "$actual" ]] && continue
            local found=0
            local actual_base
            actual_base="$(basename "$actual")"

            while IFS= read -r indexed; do
                [[ -z "$indexed" ]] && continue
                if [[ "$indexed" == "$actual" ]] || [[ "$indexed" == "./$actual" ]] || \
                   [[ "$(basename "$indexed")" == "$actual_base" ]]; then
                    found=1
                    break
                fi
            done <<< "$indexed_str"

            if [[ $found -eq 0 ]]; then
                missing_count=$((missing_count + 1))
                missing_items="${missing_items}${actual}\n"
            fi
        done <<< "$actual_str"

        if [[ $missing_count -gt 0 ]]; then
            has_failure=1
            fail "INDEX-01: ${index_file} 누락 ${missing_count}건"
            while IFS= read -r m; do
                [[ -n "$m" ]] && detail "- $m"
            done < <(printf '%b' "$missing_items")
        fi
    done

    if [[ $has_failure -eq 0 ]]; then
        pass "INDEX-01: 모든 INDEX.md 동기화 완료 (${#index_dirs[@]}개 INDEX)"
    fi
}

# ─────────────────────────────────────────────────────
# COUNT-01: README 카운트 숫자 vs 실제 파일 수
# ─────────────────────────────────────────────────────

rule_count_01() {
    if [[ ! -f "README.md" ]]; then
        pass "COUNT-01: README.md -- skip"
        return
    fi

    local has_failure=0

    # Helper: extract number before a Korean/English keyword from README
    # Matches patterns like "19개 스킬", "20 skills", "24개 스크립트"
    extract_count() {
        local pattern="$1"
        grep -oE "[0-9]+${pattern}" README.md 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo ""
    }

    # Skills: "N개 스킬" or "N skills"
    local actual_skills
    actual_skills=$(find .hxsk/skills -maxdepth 1 -type d ! -name "skills" 2>/dev/null | wc -l | tr -d ' ')
    local readme_skills
    readme_skills=$(extract_count "(개 스킬| skills)")

    if [[ -n "$readme_skills" ]] && [[ "$readme_skills" != "$actual_skills" ]]; then
        has_failure=1
        fail "COUNT-01: skills (README: ${readme_skills}, actual: ${actual_skills})"
    fi

    # Agents: "N개 에이전트" or "N agents"
    local actual_agents
    actual_agents=$(find .hxsk/agents -name "*.md" ! -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')
    local readme_agents
    readme_agents=$(extract_count "(개 에이전트| agents)")

    if [[ -n "$readme_agents" ]] && [[ "$readme_agents" != "$actual_agents" ]]; then
        has_failure=1
        fail "COUNT-01: agents (README: ${readme_agents}, actual: ${actual_agents})"
    fi

    # Hooks: "N개 스크립트" or "N hooks"
    local actual_hooks
    actual_hooks=$(find .hxsk/hooks -name "*.sh" -o -name "*.py" 2>/dev/null | wc -l | tr -d ' ')
    local readme_hooks
    readme_hooks=$(extract_count "(개 스크립트| hooks)")

    if [[ -n "$readme_hooks" ]] && [[ "$readme_hooks" != "$actual_hooks" ]]; then
        has_failure=1
        fail "COUNT-01: hooks (README: ${readme_hooks}, actual: ${actual_hooks})"
    fi

    # Research: "N개" in research context
    local actual_research
    actual_research=$(find .hxsk/research -name "*.md" ! -name "INDEX.md" 2>/dev/null | wc -l | tr -d ' ')
    local readme_research
    readme_research=$(grep -oE 'research.*([0-9]+개' README.md 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo "")

    if [[ -n "$readme_research" ]] && [[ "$readme_research" != "$actual_research" ]]; then
        has_failure=1
        fail "COUNT-01: research (README: ${readme_research}, actual: ${actual_research})"
    fi

    if [[ $has_failure -eq 0 ]]; then
        pass "COUNT-01: README counts match"
    fi
}

# ─────────────────────────────────────────────────────
# REF-01: CLAUDE.md/AGENTS.md 경로 참조 유효성
# ─────────────────────────────────────────────────────

rule_ref_01() {
    local total=0
    local broken=0
    local broken_list=()
    local l1_docs=("CLAUDE.md" "AGENTS.md")

    for doc in "${l1_docs[@]}"; do
        [[ ! -f "$doc" ]] && continue

        # Extract backtick-quoted paths that look like file paths
        while IFS= read -r path; do
            # Skip patterns with {}, *, or generic descriptions
            [[ "$path" =~ \{ ]] && continue
            [[ "$path" =~ \* ]] && continue
            [[ "$path" =~ ^# ]] && continue

            total=$((total + 1))

            # Check if path exists (file or directory)
            if [[ ! -e "$path" ]]; then
                broken=$((broken + 1))
                broken_list+=("$doc → $path")
            fi
        done < <(grep -oE '`\.[^`]+`' "$doc" 2>/dev/null | \
            sed 's/^`//;s/`$//' | \
            grep -E '^\.' | \
            grep -v '{' | \
            sort -u || true)
    done

    local valid=$((total - broken))
    if [[ $broken -eq 0 ]]; then
        pass "REF-01: L1 문서 경로 참조 유효 ($valid/$total)"
    else
        fail "REF-01: L1 문서 경로 참조 깨짐 ${broken}건 (유효 $valid/$total)"
        for item in "${broken_list[@]}"; do
            detail "$item"
        done
    fi
}

# ─────────────────────────────────────────────────────
# ORPHAN-01: 어떤 문서에서도 참조되지 않는 고아 파일
# ─────────────────────────────────────────────────────

rule_orphan_01() {
    local orphan_count=0
    local orphan_items=""

    # Build a set of all referenced .md basenames across the project
    # 3가지 형식 지원: [text](path), `path`, plain filename
    local combined_refs
    combined_refs=$({
        cat "${ALL_MD[@]}" 2>/dev/null | \
            grep -oE '\([^)]+\.md[^)]*\)' | sed 's/^(//;s/)$//' | sed 's/#.*//' | \
            xargs -I{} basename {} 2>/dev/null
        cat "${ALL_MD[@]}" 2>/dev/null | \
            grep -oE '`[^`]*\.md`' | sed 's/^`//;s/`$//' | \
            xargs -I{} basename {} 2>/dev/null
        cat "${ALL_MD[@]}" 2>/dev/null | \
            grep -oE '[A-Za-z0-9_.-]+\.md' | \
            xargs -I{} basename {} 2>/dev/null
    }) || true
    combined_refs=$(echo "$combined_refs" | sort -u)

    for md in "${ALL_MD[@]}"; do
        local base
        base="$(basename "$md")"

        # Skip well-known root files
        case "$base" in
            README.md|CLAUDE.md|AGENTS.md|GEMINI.md|CHANGELOG.md|INDEX.md|SKILL.md) continue ;;
        esac

        # Skip excluded directories
        local skip=0
        for exc_dir in $ORPHAN_EXCLUDE_DIRS; do
            if [[ "$md" == "${exc_dir}"/* ]]; then
                skip=1
                break
            fi
        done
        [[ $skip -eq 1 ]] && continue

        # Skip if referenced
        if echo "$combined_refs" | grep -qF "$base"; then
            continue
        fi

        orphan_count=$((orphan_count + 1))
        orphan_items="${orphan_items}${md}\n"
    done

    if [[ $orphan_count -eq 0 ]]; then
        pass "ORPHAN-01: 고아 파일 없음"
    else
        fail "ORPHAN-01: 참조되지 않는 파일 ${orphan_count}건"
        while IFS= read -r o; do
            [[ -n "$o" ]] && detail "- $o"
        done < <(printf '%b' "$orphan_items")
    fi
}

# ─────────────────────────────────────────────────────
# DUP-01: 동일 파일명이 여러 위치에 존재
# ─────────────────────────────────────────────────────

rule_dup_01() {
    local dup_count=0
    local dup_items=""

    # Get basenames and their full paths
    local dup_names
    dup_names=$(printf '%s\n' "${ALL_MD[@]}" | xargs -I{} basename {} | sort | uniq -d)

    if [[ -z "$dup_names" ]]; then
        pass "DUP-01: 중복 파일명 없음"
        return
    fi

    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        # Expected duplicates — 의도적 중복은 스킵
        case "$name" in
            INDEX.md|CHANGELOG.md|SKILL.md|README.md) continue ;;
            # AGENTS.md: 루트는 AGENT CLI 진입, .hxsk/docs/는 상세 문서 — 의도적 분리
            AGENTS.md) continue ;;
            # VERIFICATION.md: templates/ 는 템플릿, .hxsk/ 는 실 인스턴스 — 템플릿 시스템 구조
            VERIFICATION.md) continue ;;
            # write-report.md: agents/는 에이전트 정의, examples/는 사용 예시 — 의도적 구분
            write-report.md) continue ;;
        esac

        local locations
        locations=$(printf '%s\n' "${ALL_MD[@]}" | grep "/${name}$" || true)
        local count
        count=$(echo "$locations" | wc -l | tr -d ' ')

        if [[ $count -gt 1 ]]; then
            dup_count=$((dup_count + 1))
            dup_items="${dup_items}${name} (${count}곳): $(echo "$locations" | tr '\n' ', ' | sed 's/,$//')\n"
        fi
    done <<< "$dup_names"

    if [[ $dup_count -eq 0 ]]; then
        pass "DUP-01: 중복 파일명 없음 (예상 중복 제외)"
    else
        fail "DUP-01: 중복 파일명 ${dup_count}건"
        while IFS= read -r d; do
            [[ -n "$d" ]] && detail "- $d"
        done < <(printf '%b' "$dup_items")
    fi
}

# ─────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────

echo "=== doc-lint: 문서 정합성 검사 ==="
echo "대상: ${#ALL_MD[@]}개 .md 파일"
echo ""

should_run "LINK-01"   && rule_link_01
should_run "INDEX-01"  && rule_index_01
should_run "COUNT-01"  && rule_count_01
should_run "REF-01"    && rule_ref_01
should_run "ORPHAN-01" && rule_orphan_01
should_run "DUP-01"    && rule_dup_01

echo ""
echo "=== 결과: PASS ${PASS_COUNT}, FAIL ${FAIL_COUNT} ==="

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
