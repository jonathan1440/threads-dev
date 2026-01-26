#!/bin/bash
# threads-context.sh - Context management
# Usage: threads context <command> [options]

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

cmd_show() {
    echo ""
    echo -e "${BOLD}ACCUMULATED CONTEXT${NC}"
    echo ""

    local project_file="$THREADS_DIR/context/project.yaml"
    if [[ -f "$project_file" ]]; then
        echo -e "${CYAN}Stack:${NC}"
        awk '/stack:/,/^  [^ ]/' "$project_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*/  • /' | sed 's/"//g'
        echo ""

        echo -e "${CYAN}Patterns:${NC}"
        awk '/patterns:/,/^  [^ ]/' "$project_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*/  • /' | sed 's/"//g'
        echo ""

        echo -e "${CYAN}Constraints:${NC}"
        awk '/constraints:/,/^  [^ ]/' "$project_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*/  • /' | sed 's/"//g'
        echo ""
    fi
}

cmd_add() {
    local category="$1"
    local value="$2"

    if [[ -z "$category" ]] || [[ -z "$value" ]]; then
        echo -e "${RED}Usage: threads context add <category> \"value\"${NC}"
        echo "Categories: stack, pattern, constraint"
        exit 1
    fi

    local target_file="$THREADS_DIR/context/project.yaml"

    case "$category" in
        stack)
            sed -i.bak "/^  stack:/a\\
    - \"$value\"" "$target_file" && rm -f "$target_file.bak"
            echo -e "${GREEN}✓ Added to stack: $value${NC}"
            ;;
        pattern|patterns)
            sed -i.bak "/^  patterns:/a\\
    - \"$value\"" "$target_file" && rm -f "$target_file.bak"
            echo -e "${GREEN}✓ Added pattern: $value${NC}"
            ;;
        constraint|constraints)
            sed -i.bak "/^  constraints:/a\\
    - \"$value\"" "$target_file" && rm -f "$target_file.bak"
            echo -e "${GREEN}✓ Added constraint: $value${NC}"
            ;;
        *)
            echo -e "${RED}Unknown category: $category${NC}"
            exit 1
            ;;
    esac
}

cmd_decide() {
    local decision="$1"
    local rationale="$2"

    if [[ -z "$decision" ]]; then
        echo -e "${RED}Usage: threads context decide \"decision\" [\"rationale\"]${NC}"
        exit 1
    fi

    local target_file="$THREADS_DIR/context/project.yaml"
    local dec_id="d-$(date +%Y%m%d%H%M%S)"

    cat >> "$target_file" << EOF

  - id: "$dec_id"
    date: "$(date +%Y-%m-%d)"
    decision: "$decision"
    rationale: "${rationale:-No rationale provided}"
EOF

    echo -e "${GREEN}✓ Decision recorded: $decision${NC}"
}

show_help() {
    echo "Usage: threads context <command> [options]"
    echo ""
    echo "Commands:"
    echo "  show                  Show accumulated context"
    echo "  add <cat> \"value\"     Add to context (stack/pattern/constraint)"
    echo "  decide \"dec\" [\"why\"]  Record a decision"
}

case "${1:-}" in
    show) cmd_show ;;
    add) shift; cmd_add "$@" ;;
    decide) shift; cmd_decide "$@" ;;
    help|--help|-h|"") show_help ;;
    *) echo -e "${RED}Unknown: $1${NC}"; exit 1 ;;
esac
