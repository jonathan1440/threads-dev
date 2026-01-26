#!/bin/bash
# threads-plan.sh - Plan creation and management
# Usage: threads plan <command> [options]

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
    exit 1
}

PROJECT_DIR="$(dirname "$THREADS_DIR")"

# Helper functions
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

get_current_goal() {
    local current_file="$THREADS_DIR/current.yaml"
    yaml_get_nested "$current_file" "active" "goal_id"
}

generate_plan_id() {
    local goal_id="$1"
    local title="$2"
    local goal_dir="$THREADS_DIR/goals/$goal_id"

    # Count existing plans
    local count=$(ls -1 "$goal_dir/plans" 2>/dev/null | wc -l | tr -d ' ')
    local num=$(printf "%03d" $((count + 1)))

    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-20)
    echo "p-${num}-${slug}"
}

# Commands
cmd_new() {
    local title="$1"

    if [[ -z "$title" ]]; then
        echo -e "${RED}Error: Plan title required${NC}"
        echo "Usage: threads plan new \"Title of the plan\""
        exit 1
    fi

    local goal_id=$(get_current_goal)

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${RED}No active goal. Create or select a goal first.${NC}"
        echo "  threads goal new \"Goal title\""
        echo "  threads goal select <goal-id>"
        exit 1
    fi

    local goal_dir="$THREADS_DIR/goals/$goal_id"
    local goal_file="$goal_dir/goal.yaml"

    if [[ ! -f "$goal_file" ]]; then
        echo -e "${RED}Goal not found: $goal_id${NC}"
        exit 1
    fi

    local plan_id=$(generate_plan_id "$goal_id" "$title")
    local plan_dir="$goal_dir/plans/$plan_id"
    local plan_file="$plan_dir/plan.yaml"

    # Create directory structure
    mkdir -p "$plan_dir/tasks"

    # Create plan.yaml
    cat > "$plan_file" << EOF
# Plan: $title
id: "$plan_id"
type: plan
goal_id: "$goal_id"
created: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
updated: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

title: "$title"
description: |
  Describe what this plan will accomplish.

approach: |
  Describe the technical approach:
  1. First, we'll...
  2. Then, we'll...
  3. Finally, we'll...

rationale: |
  Explain why this approach makes sense.

alternatives_considered: []
# - name: "Alternative approach"
#   description: "What it would involve"
#   rejected_because: "Why we didn't choose it"

status: proposed  # proposed | approved | in_progress | blocked | completed | abandoned
approved_by: null
approved_at: null

progress:
  tasks_total: 0
  tasks_completed: 0
  current_task_id: null
  percent_complete: 0

depends_on: []
blocks: []

confidence:
  approach: null
  completeness: null
  risk_level: null

risks: []
# - description: "Potential risk"
#   likelihood: medium
#   impact: high
#   mitigation: "How to handle it"

tasks: []

estimate:
  hours_min: null
  hours_max: null
  complexity: null  # low | medium | high

context:
  relevant_files: []
  key_decisions: []
  learnings: []

checkpoints: []
EOF

    # Add plan to goal's plan list
    if grep -q "^plans: \[\]" "$goal_file" 2>/dev/null; then
        sed -i.bak "s/^plans: \[\]/plans:\n  - $plan_id/" "$goal_file" && rm -f "$goal_file.bak"
    else
        sed -i.bak "/^plans:/a\\
  - $plan_id" "$goal_file" && rm -f "$goal_file.bak"
    fi

    # Update goal's plan count
    local plans_total=$(grep -c "^  - p-" "$goal_file" 2>/dev/null || echo "1")
    sed -i.bak "s/plans_total: .*/plans_total: $plans_total/" "$goal_file" && rm -f "$goal_file.bak"

    # Update current.yaml
    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/plan_id: .*/plan_id: $plan_id/" "$current_file" && rm -f "$current_file.bak"
    sed -i.bak "s/phase: .*/phase: planning/" "$current_file" && rm -f "$current_file.bak"

    echo ""
    echo -e "${GREEN}✓ Plan created: $plan_id${NC}"
    echo ""
    echo -e "${GRAY}Location:${NC} $plan_file"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Edit the plan file to add:"
    echo "     - Description and approach"
    echo "     - Rationale"
    echo "     - Risks (if any)"
    echo ""
    echo "  2. Get plan approved, then create tasks:"
    echo "     threads plan approve"
    echo "     threads task new \"Task title\""
    echo ""
}

cmd_list() {
    local goal_id=$(get_current_goal)

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${YELLOW}No active goal${NC}"
        exit 1
    fi

    local goal_file="$THREADS_DIR/goals/$goal_id/goal.yaml"
    local goal_title=$(yaml_get "$goal_file" "title")

    echo ""
    echo -e "${BOLD}Plans for: $goal_title${NC}"
    echo -e "${GRAY}Goal ID: $goal_id${NC}"
    echo ""

    local count=0
    for plan_dir in "$THREADS_DIR/goals/$goal_id/plans"/*/; do
        if [[ -d "$plan_dir" ]]; then
            local plan_id=$(basename "$plan_dir")
            local plan_file="$plan_dir/plan.yaml"

            if [[ -f "$plan_file" ]]; then
                local title=$(yaml_get "$plan_file" "title")
                local status=$(yaml_get "$plan_file" "status")
                local progress=$(yaml_get_nested "$plan_file" "progress" "percent_complete")
                local tasks_total=$(yaml_get_nested "$plan_file" "progress" "tasks_total")
                local tasks_completed=$(yaml_get_nested "$plan_file" "progress" "tasks_completed")

                case "$status" in
                    completed) ICON="✅" ;;
                    in_progress) ICON="🔄" ;;
                    approved) ICON="✔️" ;;
                    blocked) ICON="❌" ;;
                    proposed) ICON="📝" ;;
                    *) ICON="⬜" ;;
                esac

                echo -e "  $ICON ${BOLD}$title${NC}"
                echo -e "     ${GRAY}ID:${NC} $plan_id"
                echo -e "     ${GRAY}Status:${NC} $status | ${GRAY}Tasks:${NC} ${tasks_completed:-0}/${tasks_total:-0}"
                echo ""
                ((count++))
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${GRAY}No plans yet${NC}"
        echo ""
        echo "  Create one with: threads plan new \"Plan title\""
    fi
    echo ""
}

cmd_show() {
    local plan_id="$1"
    local goal_id=$(get_current_goal)

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${RED}No active goal${NC}"
        exit 1
    fi

    # If no plan specified, use current
    if [[ -z "$plan_id" ]]; then
        local current_file="$THREADS_DIR/current.yaml"
        plan_id=$(yaml_get_nested "$current_file" "active" "plan_id")
    fi

    if [[ -z "$plan_id" ]] || [[ "$plan_id" == "null" ]]; then
        echo -e "${YELLOW}No plan specified and no active plan${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/plan.yaml"

    if [[ ! -f "$plan_file" ]]; then
        echo -e "${RED}Plan not found: $plan_id${NC}"
        exit 1
    fi

    local title=$(yaml_get "$plan_file" "title")
    local status=$(yaml_get "$plan_file" "status")
    local progress=$(yaml_get_nested "$plan_file" "progress" "percent_complete")

    echo ""
    echo -e "${BOLD}$title${NC}"
    echo -e "${GRAY}ID: $plan_id${NC}"
    echo ""
    echo -e "${GRAY}Status:${NC} $status | ${GRAY}Progress:${NC} ${progress:-0}%"
    echo ""

    # Show approach
    echo -e "${BOLD}Approach:${NC}"
    awk '/^approach:/{found=1; if(/\|/){next}} found && /^[^ ]/{exit} found{gsub(/^  /,"  "); print}' "$plan_file"
    echo ""

    # Show tasks
    echo -e "${BOLD}Tasks:${NC}"
    local tasks=$(awk '/^tasks:/,/^[^ ]/' "$plan_file" | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/"//g')
    if [[ -n "$tasks" ]]; then
        for task_id in $tasks; do
            local task_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/tasks/$task_id/task.yaml"
            if [[ -f "$task_file" ]]; then
                local task_title=$(yaml_get "$task_file" "title")
                local task_status=$(yaml_get "$task_file" "status")

                case "$task_status" in
                    completed) ICON="✅" ;;
                    in_progress) ICON="🔄" ;;
                    blocked) ICON="❌" ;;
                    failed) ICON="💥" ;;
                    *) ICON="⬜" ;;
                esac

                echo "  $ICON $task_title ($task_id)"
            fi
        done
    else
        echo -e "  ${GRAY}No tasks yet${NC}"
    fi
    echo ""
}

cmd_select() {
    local plan_id="$1"
    local goal_id=$(get_current_goal)

    if [[ -z "$goal_id" ]] || [[ "$goal_id" == "null" ]]; then
        echo -e "${RED}No active goal${NC}"
        exit 1
    fi

    if [[ -z "$plan_id" ]]; then
        echo -e "${RED}Error: Plan ID required${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/plan.yaml"

    if [[ ! -f "$plan_file" ]]; then
        echo -e "${RED}Plan not found: $plan_id${NC}"
        exit 1
    fi

    local title=$(yaml_get "$plan_file" "title")

    # Update current.yaml
    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/plan_id: .*/plan_id: $plan_id/" "$current_file" && rm -f "$current_file.bak"
    sed -i.bak "s/task_id: .*/task_id: null/" "$current_file" && rm -f "$current_file.bak"

    echo -e "${GREEN}✓ Switched to plan: $title${NC}"
}

cmd_approve() {
    local goal_id=$(get_current_goal)
    local current_file="$THREADS_DIR/current.yaml"
    local plan_id=$(yaml_get_nested "$current_file" "active" "plan_id")

    if [[ -z "$plan_id" ]] || [[ "$plan_id" == "null" ]]; then
        echo -e "${RED}No active plan${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/plan.yaml"

    sed -i.bak "s/^status: proposed/status: approved/" "$plan_file" && rm -f "$plan_file.bak"
    sed -i.bak "s/^approved_by: null/approved_by: human/" "$plan_file" && rm -f "$plan_file.bak"
    sed -i.bak "s/^approved_at: null/approved_at: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$plan_file" && rm -f "$plan_file.bak"

    local title=$(yaml_get "$plan_file" "title")
    echo -e "${GREEN}✓ Plan approved: $title${NC}"
    echo ""
    echo "Next: Create tasks with 'threads task new \"Task title\"'"
}

cmd_start() {
    local goal_id=$(get_current_goal)
    local current_file="$THREADS_DIR/current.yaml"
    local plan_id=$(yaml_get_nested "$current_file" "active" "plan_id")

    if [[ -z "$plan_id" ]] || [[ "$plan_id" == "null" ]]; then
        echo -e "${RED}No active plan${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$goal_id/plans/$plan_id/plan.yaml"

    sed -i.bak "s/^status: .*/status: in_progress/" "$plan_file" && rm -f "$plan_file.bak"

    # Also update goal status
    local goal_file="$THREADS_DIR/goals/$goal_id/goal.yaml"
    sed -i.bak "s/^status: .*/status: in_progress/" "$goal_file" && rm -f "$goal_file.bak"

    # Update current.yaml phase
    sed -i.bak "s/phase: .*/phase: executing/" "$current_file" && rm -f "$current_file.bak"

    local title=$(yaml_get "$plan_file" "title")
    echo -e "${GREEN}✓ Started work on: $title${NC}"
}

# Help
show_help() {
    echo "Usage: threads plan <command> [options]"
    echo ""
    echo "Commands:"
    echo "  new <title>        Create a new plan under current goal"
    echo "  list               List all plans for current goal"
    echo "  show [plan-id]     Show plan details (default: current)"
    echo "  select <plan-id>   Switch to a different plan"
    echo "  approve            Approve the current plan"
    echo "  start              Start work on current plan"
    echo ""
    echo "Examples:"
    echo "  threads plan new \"Database schema and models\""
    echo "  threads plan list"
    echo "  threads plan approve"
    echo "  threads plan start"
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
    approve)
        cmd_approve
        ;;
    start)
        cmd_start
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
