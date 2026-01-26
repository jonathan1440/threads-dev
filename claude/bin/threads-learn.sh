#!/bin/bash
# threads-learn.sh - Capture learnings
# Usage: threads learn "learning" [--source "source"]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

find_threads_dir() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.threads" ]]; then
            echo "$dir/.threads"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

THREADS_DIR=$(find_threads_dir) || {
    echo -e "${RED}Error: No .threads directory found${NC}"
    exit 1
}

cmd_add() {
    local learning="$1"
    local source="${2:-Manual entry}"

    if [[ -z "$learning" ]]; then
        echo -e "${RED}Usage: threads learn \"What you learned\" [--source \"where\"]${NC}"
        exit 1
    fi

    local learn_id="l-$(date +%Y%m%d%H%M%S)"
    local project_file="$THREADS_DIR/context/project.yaml"

    if grep -q "^learnings: \[\]" "$project_file" 2>/dev/null; then
        sed -i.bak "s/^learnings: \[\]/learnings:/" "$project_file" && rm -f "$project_file.bak"
    fi

    cat >> "$project_file" << EOF

  - id: "$learn_id"
    date: "$(date +%Y-%m-%d)"
    learning: "$learning"
    source: "$source"
    still_valid: true
EOF

    echo -e "${GREEN}✓ Learning captured${NC}"
    echo -e "${GRAY}ID:${NC} $learn_id"
    echo -e "${GRAY}Learning:${NC} $learning"
}

cmd_list() {
    local project_file="$THREADS_DIR/context/project.yaml"

    echo ""
    echo -e "${BOLD}Captured Learnings${NC}"
    echo ""

    awk '/^learnings:/,/^[^ ]/' "$project_file" | while IFS= read -r line; do
        if [[ "$line" =~ id:.*\"(.*)\" ]]; then
            id="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ date:.*\"(.*)\" ]]; then
            date="${BASH_REMATCH[1]}"
        elif [[ "$line" =~ learning:.*\"(.*)\" ]]; then
            learning="${BASH_REMATCH[1]}"
            echo -e "  ${CYAN}$id${NC} ($date)"
            echo -e "    $learning"
            echo ""
        fi
    done
}

show_help() {
    echo "Usage: threads learn <learning|command> [options]"
    echo ""
    echo "Commands:"
    echo "  \"learning text\"    Add a new learning"
    echo "  list               List all learnings"
    echo ""
    echo "Options:"
    echo "  --source \"src\"     Specify source"
}

case "${1:-}" in
    list|ls) cmd_list ;;
    help|--help|-h) show_help ;;
    "") show_help ;;
    *)
        learning="$1"
        shift
        source=""
        while [[ $# -gt 0 ]]; do
            case $1 in
                --source|-s) source="$2"; shift 2 ;;
                *) shift ;;
            esac
        done
        cmd_add "$learning" "$source"
        ;;
esac
