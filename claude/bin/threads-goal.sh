#!/bin/bash
# threads-goal.sh - Goal creation and management
# Usage: threads goal <command> [options]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m'

# Find .threads directory
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
    echo "Run 'threads init' first"
    exit 1
}

PROJECT_DIR="$(dirname "$THREADS_DIR")"

# Helper functions
generate_goal_id() {
    local title="$1"
    local date_part=$(date +%Y%m%d)
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-30)
    echo "g-${date_part}-${slug}"
}

yaml_get() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

yaml_get_nested() {
    local file="$1"
    local key="$2"
    local subkey="$3"
    awk "/^${key}:/{found=1; next} found && /^  ${subkey}:/{print; exit} found && /^[^ ]/{exit}" "$file" 2>/dev/null | sed "s/^  ${subkey}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# Commands
cmd_new() {
    local title="$1"

    if [[ -z "$title" ]]; then
        echo -e "${RED}Error: Goal title required${NC}"
        echo "Usage: threads goal new \"Title of the goal\""
        exit 1
    fi

    local goal_id=$(generate_goal_id "$title")
    local goal_dir="$THREADS_DIR/goals/$goal_id"
    local goal_file="$goal_dir/goal.yaml"

    # Check if already exists
    if [[ -d "$goal_dir" ]]; then
        echo -e "${YELLOW}Warning: Goal directory already exists${NC}"
        read -p "Overwrite? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Create directory structure
    mkdir -p "$goal_dir/plans"

    # Create goal.yaml
    cat > "$goal_file" << EOF
# Goal: $title
id: "$goal_id"
type: goal
created: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
updated: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

title: "$title"
description: |
  Describe what you want to accomplish.
  Add context to help the AI understand the scope.

success_criteria: []
# - "First success criterion"
# - "Second success criterion"

human_context:
  requirements: []
  constraints: []
  preferences: []

sizing:
  estimated_scope: null  # trivial | small | medium | large
  estimated_hours: null
  complexity_factors: []

status: not_started

progress:
  plans_total: 0
  plans_completed: 0
  current_plan_id: null
  percent_complete: 0

confidence:
  understanding: null
  approach: null
  feasibility: null
  overall: null

uncertainties: []

validation:
  automated: []
  human_required:
    before_complete: true
    review_points: []

plans: []

checkpoints: []

metadata:
  tags: []
  priority: null
  deadline: null
EOF

    # Create goal context file
    cat > "$goal_dir/context.yaml" << EOF
# Context for goal: $title
type: goal_context
goal_id: "$goal_id"

# Knowledge specific to this goal
discovered:
  relevant_files: []
  patterns: []
  constraints: []

# Decisions made during this goal
decisions: []

# Learnings from working on this goal
learnings: []
EOF

    # Update current.yaml to point to new goal
    local current_file="$THREADS_DIR/current.yaml"
    cat > "$current_file" << EOF
# Current Active Context
# Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

active:
  goal_id: $goal_id
  plan_id: null
  task_id: null
  action_id: null

session:
  id: sess-$(date +%Y%m%d%H%M%S)
  started: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  last_activity: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

status:
  summary: "New goal created: $title"
  phase: planning
  blocker: null

resume_context: |
  NEW GOAL: $title

  Next steps:
  1. Edit the goal file to add description and success criteria
  2. Create plans to break down the approach
  3. Create tasks within each plan

  Goal file: $goal_file
EOF

    echo ""
    echo -e "${GREEN}✓ Goal created: $goal_id${NC}"
    echo ""
    echo -e "${GRAY}Location:${NC} $goal_file"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Edit the goal file to add:"
    echo "     - Description"
    echo "     - Success criteria"
    echo "     - Requirements and constraints"
    echo ""
    echo "  2. Create a plan:"
    echo "     threads plan new \"Plan title\""
    echo ""
}

cmd_list() {
    echo ""
    echo -e "${BOLD}Goals:${NC}"
    echo ""

    local count=0
    for goal_dir in "$THREADS_DIR/goals"/*/; do
        if [[ -d "$goal_dir" ]]; then
            local goal_id=$(basename "$goal_dir")
            local goal_file="$goal_dir/goal.yaml"

            if [[ -f "$goal_file" ]]; then
                local title=$(yaml_get "$goal_file" "title")
                local status=$(yaml_get "$goal_file" "status")
                local progress=$(yaml_get_nested "$goal_file" "progress" "percent_complete")

                case "$status" in
                    completed) STATUS_ICON="✅"; STATUS_COLOR="$GREEN" ;;
                    in_progress) STATUS_ICON="🔄"; STATUS_COLOR="$CYAN" ;;
                    blocked) STATUS_ICON="❌"; STATUS_COLOR="$RED" ;;
                    abandoned) STATUS_ICON="⏹"; STATUS_COLOR="$GRAY" ;;
                    *) STATUS_ICON="⬜"; STATUS_COLOR="$GRAY" ;;
                esac

                echo -e "  ${STATUS_COLOR}${STATUS_ICON}${NC} ${BOLD}$title${NC}"
                echo -e "     ${GRAY}ID:${NC} $goal_id"
                echo -e "     ${GRAY}Status:${NC} $status | ${GRAY}Progress:${NC} ${progress:-0}%"
                echo ""
                ((count++))
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${GRAY}No goals found${NC}"
        echo ""
        echo "  Create one with: threads goal new \"Goal title\""
    fi
    echo ""
}

cmd_show() {
    local goal_id="$1"

    # If no goal specified, use current
    if [[ -z "$goal_id" ]]; then
        local current_file="$THREADS_DIR/current.yaml"
        goal_id=$(yaml_get_nested "$current_file" "active" "goal_id")
    fi

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${YELLOW}No goal specified and no active goal${NC}"
        exit 1
    fi

    local goal_file="$THREADS_DIR/goals/$goal_id/goal.yaml"

    if [[ ! -f "$goal_file" ]]; then
        echo -e "${RED}Goal not found: $goal_id${NC}"
        exit 1
    fi

    # Display goal details
    local title=$(yaml_get "$goal_file" "title")
    local status=$(yaml_get "$goal_file" "status")
    local created=$(yaml_get "$goal_file" "created")
    local progress=$(yaml_get_nested "$goal_file" "progress" "percent_complete")
    local plans_total=$(yaml_get_nested "$goal_file" "progress" "plans_total")
    local plans_completed=$(yaml_get_nested "$goal_file" "progress" "plans_completed")

    echo ""
    echo -e "${BOLD}$title${NC}"
    echo -e "${GRAY}ID: $goal_id${NC}"
    echo ""
    echo -e "${GRAY}Status:${NC}   $status"
    echo -e "${GRAY}Progress:${NC} ${progress:-0}%"
    echo -e "${GRAY}Plans:${NC}    ${plans_completed:-0}/${plans_total:-0} complete"
    echo -e "${GRAY}Created:${NC}  $created"
    echo ""

    # Show description
    echo -e "${BOLD}Description:${NC}"
    awk '/^description:/{found=1; if(/\|/){next}} found && /^[^ ]/{exit} found{gsub(/^  /,"  "); print}' "$goal_file"
    echo ""

    # Show success criteria
    echo -e "${BOLD}Success Criteria:${NC}"
    awk '/^success_criteria:/,/^[^ ]/' "$goal_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*/  • /' | sed 's/"//g'
    echo ""

    # Show plans
    echo -e "${BOLD}Plans:${NC}"
    local plans=$(awk '/^plans:/,/^[^ ]/' "$goal_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/"//g')
    if [[ -n "$plans" ]]; then
        for plan_id in $plans; do
            local plan_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/plan.yaml"
            if [[ -f "$plan_file" ]]; then
                local plan_title=$(yaml_get "$plan_file" "title")
                local plan_status=$(yaml_get "$plan_file" "status")

                case "$plan_status" in
                    completed) ICON="✅" ;;
                    in_progress) ICON="🔄" ;;
                    blocked) ICON="❌" ;;
                    *) ICON="⬜" ;;
                esac

                echo "  $ICON $plan_title ($plan_id)"
            fi
        done
    else
        echo -e "  ${GRAY}No plans yet${NC}"
    fi
    echo ""
}

cmd_select() {
    local goal_id="$1"

    if [[ -z "$goal_id" ]]; then
        echo -e "${RED}Error: Goal ID required${NC}"
        exit 1
    fi

    local goal_file="$THREADS_DIR/goals/$goal_id/goal.yaml"

    if [[ ! -f "$goal_file" ]]; then
        echo -e "${RED}Goal not found: $goal_id${NC}"
        exit 1
    fi

    local title=$(yaml_get "$goal_file" "title")

    # Update current.yaml
    local current_file="$THREADS_DIR/current.yaml"
    cat > "$current_file" << EOF
# Current Active Context
# Updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

active:
  goal_id: $goal_id
  plan_id: null
  task_id: null
  action_id: null

session:
  id: sess-$(date +%Y%m%d%H%M%S)
  started: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  last_activity: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

status:
  summary: "Switched to goal: $title"
  phase: planning
  blocker: null

resume_context: |
  ACTIVE GOAL: $title
  ID: $goal_id
EOF

    echo -e "${GREEN}✓ Switched to goal: $title${NC}"
}

cmd_update() {
    local field="$1"
    local value="$2"

    # Get current goal
    local current_file="$THREADS_DIR/current.yaml"
    local goal_id=$(yaml_get_nested "$current_file" "active" "goal_id")

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${RED}No active goal${NC}"
        exit 1
    fi

    local goal_file="$THREADS_DIR/goals/$goal_id/goal.yaml"

    case "$field" in
        status)
            if [[ ! "$value" =~ ^(not_started|planning|in_progress|blocked|validating|completed|abandoned)$ ]]; then
                echo -e "${RED}Invalid status: $value${NC}"
                echo "Valid: not_started, planning, in_progress, blocked, validating, completed, abandoned"
                exit 1
            fi
            sed -i.bak "s/^status: .*/status: $value/" "$goal_file" && rm -f "$goal_file.bak"
            echo -e "${GREEN}✓ Status updated to: $value${NC}"
            ;;
        progress)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || [[ "$value" -gt 100 ]]; then
                echo -e "${RED}Invalid progress: $value (must be 0-100)${NC}"
                exit 1
            fi
            sed -i.bak "s/percent_complete: .*/percent_complete: $value/" "$goal_file" && rm -f "$goal_file.bak"
            echo -e "${GREEN}✓ Progress updated to: ${value}%${NC}"
            ;;
        *)
            echo -e "${RED}Unknown field: $field${NC}"
            echo "Supported: status, progress"
            exit 1
            ;;
    esac

    # Update timestamp
    sed -i.bak "s/^updated: .*/updated: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$goal_file" && rm -f "$goal_file.bak"
}

# Help
show_help() {
    echo "Usage: threads goal <command> [options]"
    echo ""
    echo "Commands:"
    echo "  new <title>           Create a new goal"
    echo "  list                  List all goals"
    echo "  show [goal-id]        Show goal details (default: current)"
    echo "  select <goal-id>      Switch to a different goal"
    echo "  update <field> <val>  Update goal field (status, progress)"
    echo ""
    echo "Examples:"
    echo "  threads goal new \"Implement user authentication\""
    echo "  threads goal list"
    echo "  threads goal show"
    echo "  threads goal select g-20250126-user-auth"
    echo "  threads goal update status in_progress"
    echo "  threads goal update progress 50"
}

# Main dispatch
case "${1:-}" in
    new)
        shift
        cmd_new "$@"
        ;;
    list|ls)
        cmd_list
        ;;
    show)
        shift
        cmd_show "$@"
        ;;
    select|switch)
        shift
        cmd_select "$@"
        ;;
    update|set)
        shift
        cmd_update "$@"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
