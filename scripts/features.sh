#!/usr/bin/env bash
# features.sh — list, revert, and squash-merge feature branches on main.
#
# Each squash-merge commit produced by `features.sh merge` carries a git
# trailer "Source-branch: <name>", which `list` and `revert` use to identify
# features. Manual squash merges that include the same trailer also work.

set -euo pipefail

TRAILER_KEY="Source-branch"
MAIN_BRANCH="${MAIN_BRANCH:-main}"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  list                          List squash-merged feature branches on $MAIN_BRANCH
  revert <issue|sha|branch>     Revert a feature (creates a new revert commit)
  merge <branch>                Squash-merge a branch into $MAIN_BRANCH with tracking trailer
  help                          Show this help

Examples:
  $(basename "$0") list
  $(basename "$0") revert 56
  $(basename "$0") revert claude/issue-56-20260503-2209
  $(basename "$0") merge claude/issue-56-20260503-2209
EOF
}

extract_issue() {
    # claude/issue-56-20260503-2209 -> 56
    printf '%s' "$1" | sed -nE 's|.*claude/issue-([0-9]+).*|\1|p'
}

is_reverted() {
    local sha="$1"
    git log "$MAIN_BRANCH" --grep="This reverts commit $sha" --format=%H 2>/dev/null | grep -q .
}

cmd_list() {
    if ! git rev-parse --verify "$MAIN_BRANCH" >/dev/null 2>&1; then
        echo "Branch '$MAIN_BRANCH' not found." >&2
        exit 1
    fi

    local fmt
    fmt='%H%x09%cs%x09%(trailers:key='"$TRAILER_KEY"',valueonly,separator=%x20%x20)%x09%s'

    local rows
    rows=$(git log "$MAIN_BRANCH" --format="$fmt" | awk -F'\t' '$3 != ""')

    if [ -z "$rows" ]; then
        echo "No squash-merged feature commits found on '$MAIN_BRANCH'."
        echo "(Looking for commits with a '$TRAILER_KEY:' trailer.)"
        return 0
    fi

    printf '%-9s  %-6s  %-10s  %-10s  %s\n' "STATUS" "ISSUE" "DATE" "SHA" "SUBJECT"
    while IFS=$'\t' read -r sha date branch subject; do
        local issue status
        issue=$(extract_issue "$branch")
        if is_reverted "$sha"; then
            status="REVERTED"
        else
            status="ACTIVE"
        fi
        printf '%-9s  #%-5s  %-10s  %-10s  %s\n' \
            "$status" "${issue:--}" "$date" "${sha:0:10}" "$subject"
    done <<< "$rows"
}

resolve_sha() {
    # input: issue number, full/short sha, branch name, or anything matching the trailer
    local id="$1" sha
    if printf '%s' "$id" | grep -qE '^[0-9a-f]{7,40}$' && git cat-file -e "$id^{commit}" 2>/dev/null; then
        # Looks like a SHA and it exists
        sha=$(git rev-parse "$id")
        printf '%s' "$sha"
        return 0
    fi
    # Match by trailer
    local needle="$id"
    if printf '%s' "$id" | grep -qE '^[0-9]+$'; then
        # Issue number — match claude/issue-NN-...
        needle="claude/issue-$id-"
    fi
    git log "$MAIN_BRANCH" \
        --format="%H%x09%(trailers:key=$TRAILER_KEY,valueonly,separator=%x20%x20)" \
        | awk -F'\t' -v needle="$needle" '$2 ~ needle {print $1; exit}'
}

cmd_revert() {
    local id="${1:-}"
    if [ -z "$id" ]; then
        echo "Usage: $(basename "$0") revert <issue|sha|branch>" >&2
        exit 1
    fi
    local sha
    sha=$(resolve_sha "$id")
    if [ -z "$sha" ]; then
        echo "No matching feature commit on '$MAIN_BRANCH' for: $id" >&2
        echo "Run '$(basename "$0") list' to see what's available." >&2
        exit 1
    fi
    if is_reverted "$sha"; then
        echo "Already reverted: $(git log -1 --format='%h %s' "$sha")" >&2
        echo "Run 'git revert $(git log "$MAIN_BRANCH" --grep="This reverts commit $sha" --format=%h | head -1)' to undo the revert." >&2
        exit 1
    fi
    local current
    current=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current" != "$MAIN_BRANCH" ]; then
        echo "Switch to '$MAIN_BRANCH' first (currently on '$current')." >&2
        exit 1
    fi
    echo "Reverting: $(git log -1 --format='%h %s' "$sha")"
    git revert --no-edit "$sha"
}

cmd_merge() {
    local branch="${1:-}"
    if [ -z "$branch" ]; then
        echo "Usage: $(basename "$0") merge <branch>" >&2
        exit 1
    fi
    local current
    current=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current" != "$MAIN_BRANCH" ]; then
        echo "Switch to '$MAIN_BRANCH' first (currently on '$current')." >&2
        exit 1
    fi
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Working tree is dirty. Commit or stash first." >&2
        exit 1
    fi

    # Resolve branch ref: local first, then origin/<branch>
    local ref="$branch"
    if ! git rev-parse --verify --quiet "$ref" >/dev/null; then
        if git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
            ref="origin/$branch"
        else
            echo "Branch not found locally or on origin: $branch" >&2
            exit 1
        fi
    fi

    # Pick a subject: prefer the OLDEST commit on the branch not yet on main
    # (the feature commit), falling back to the branch tip if there's just one.
    local subject
    subject=$(git log "$ref" --not "$MAIN_BRANCH" --format=%s --reverse | head -1)
    [ -z "$subject" ] && subject=$(git log -1 --format=%s "$ref")

    git merge --squash "$ref"
    if git diff --cached --quiet; then
        echo "Nothing to merge from '$ref' (already in $MAIN_BRANCH?)." >&2
        return 1
    fi

    git commit -m "$subject" -m "$TRAILER_KEY: ${branch#origin/}"
    echo "Squash-merged '${branch#origin/}' as $(git log -1 --format='%h')."
}

cmd="${1:-help}"
shift || true
case "$cmd" in
    list)         cmd_list "$@" ;;
    revert)       cmd_revert "$@" ;;
    merge)        cmd_merge "$@" ;;
    help|-h|--help) usage ;;
    *) usage >&2; exit 1 ;;
esac
