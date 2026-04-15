#!/bin/bash
# forge-detect.sh — Git 플랫폼 감지 + CLI 추상화
# Usage: source .hxsk/scripts/forge-detect.sh
#
# 제공 함수:
#   detect_forge              → "github" | "gitlab" | "gitea" | "unknown"
#   forge_issue_create        → 이슈 생성, 이슈 번호 반환
#   forge_issue_comment       → 이슈 코멘트 추가
#   forge_issue_close         → 이슈 close
#   forge_pr_create           → PR/MR 생성
#   forge_sub_issue_create    → 하위 이슈 생성 (미지원 플랫폼은 체크리스트 대체)

# ── 플랫폼 감지 ──────────────────────────────────────────────────────────────

detect_forge() {
    local REMOTE
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    case "$REMOTE" in
        *github.com*)             echo "github" ;;
        *gitlab.com*|*gitlab.*)   echo "gitlab" ;;
        *gitea*|*forgejo*|*codeberg*) echo "gitea" ;;
        *)                        echo "unknown" ;;
    esac
}

# ── 이슈 생성 ──────────────────────────────────────────────────────────────

# forge_issue_create <title> <body> [label]
# Returns: issue number (숫자만)
forge_issue_create() {
    local title="$1"
    local body="$2"
    local label="${3:-}"
    local result
    local number

    case $(detect_forge) in
        github)
            if [ -n "$label" ]; then
                result=$(gh issue create --title "$title" --body "$body" --label "$label")
            else
                result=$(gh issue create --title "$title" --body "$body")
            fi
            [ $? -ne 0 ] && return 1
            number=$(echo "$result" | grep -oE '[0-9]+$' | tail -1)
            ;;
        gitlab)
            if [ -n "$label" ]; then
                result=$(glab issue create --title "$title" --description "$body" --label "$label")
            else
                result=$(glab issue create --title "$title" --description "$body")
            fi
            [ $? -ne 0 ] && return 1
            number=$(echo "$result" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
            ;;
        gitea)
            result=$(tea issue create --title "$title" --body "$body")
            [ $? -ne 0 ] && return 1
            number=$(echo "$result" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
            ;;
        *)
            echo "ERROR: unknown forge platform — set git remote origin" >&2
            return 1
            ;;
    esac

    if [ -z "$number" ]; then
        echo "ERROR: failed to parse issue number from forge CLI output" >&2
        return 1
    fi

    echo "$number"
}

# ── 이슈 코멘트 ──────────────────────────────────────────────────────────────

# forge_issue_comment <issue_number> <body>
forge_issue_comment() {
    local number="$1"
    local body="$2"

    case $(detect_forge) in
        github) gh issue comment "$number" --body "$body" ;;
        gitlab) glab issue note "$number" --message "$body" ;;
        gitea)  tea comment create "$number" --body "$body" 2>/dev/null \
                || echo "WARN: tea comment not supported, skipping" >&2 ;;
        *)
            echo "ERROR: unsupported forge '$(detect_forge)'; cannot comment on issue #$number" >&2
            return 1
            ;;
    esac
}

# ── 이슈 close ───────────────────────────────────────────────────────────────

# forge_issue_close <issue_number>
forge_issue_close() {
    local number="$1"

    case $(detect_forge) in
        github) gh issue close "$number" ;;
        gitlab) glab issue close "$number" ;;
        gitea)  tea issue close "$number" 2>/dev/null ;;
        *)
            echo "ERROR: unsupported forge '$(detect_forge)'; cannot close issue #$number" >&2
            return 1
            ;;
    esac
}

# ── PR/MR 생성 ───────────────────────────────────────────────────────────────

# forge_pr_create <title> <body> [base_branch]
forge_pr_create() {
    local title="$1"
    local body="$2"
    local base="${3:-main}"

    case $(detect_forge) in
        github) gh pr create --title "$title" --body "$body" --base "$base" ;;
        gitlab) glab mr create --title "$title" --description "$body" --target-branch "$base" ;;
        gitea)  tea pr create --title "$title" --description "$body" --base "$base" 2>/dev/null ;;
        *)
            echo "ERROR: unsupported forge for PR/MR creation: $(detect_forge)" >&2
            return 1
            ;;
    esac
}

# ── 하위 이슈 생성 ────────────────────────────────────────────────────────────

# forge_sub_issue_create <parent_number> <title> <body>
# Returns: child issue number
forge_sub_issue_create() {
    local parent="$1"
    local title="$2"
    local body="$3"
    local child_num

    case $(detect_forge) in
        github)
            # Sub-Issues GA (2025-01) 네이티브 지원
            child_num=$(gh sub-issue create --parent "$parent" \
                --title "$title" --body "$body" 2>/dev/null \
                | grep -oE '[0-9]+$' | tail -1)
            echo "$child_num"
            ;;
        gitlab|gitea)
            # Sub-Issues 미지원 → 이슈 생성 + 부모에 체크리스트 추가
            child_num=$(forge_issue_create "$title" "$body")
            if [ -n "$child_num" ]; then
                forge_issue_comment "$parent" "- [ ] #${child_num} ${title}"
                echo "$child_num"
            else
                echo "ERROR: sub-issue creation failed — forge_issue_create returned empty" >&2
                return 1
            fi
            ;;
        *)
            echo "ERROR: unsupported forge '$(detect_forge)'; cannot create sub-issue" >&2
            return 1
            ;;
    esac
}

# ── 현재 플랫폼 확인 (디버그용) ──────────────────────────────────────────────

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "Detected forge: $(detect_forge)"
fi
