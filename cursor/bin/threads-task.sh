#!/bin/bash
# threads-task.sh - Task creation and management
# Usage: threads task <command> [options]

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

get_current_context() {
    local current_file="$THREADS_DIR/current.yaml"
    GOAL_ID=$(yaml_get_nested "$current_file" "active" "goal_id")
    PLAN_ID=$(yaml_get_nested "$current_file" "active" "plan_id")
    TASK_ID=$(yaml_get_nested "$current_file" "active" "task_id")
}

generate_task_id() {
    local plan_dir="$1"
    local title="$2"

    local count=$(ls -1 "$plan_dir/tasks" 2>/dev/null | wc -l | tr -d ' ')
    local num=$(printf "%03d" $((count + 1)))

    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-20)
    echo "t-${num}-${slug}"
}

cmd_new() {
    local title="$1"

    if [[ -z "$title" ]]; then
        echo -e "${RED}Error: Task title required${NC}"
        echo "Usage: threads task new \"Title of the task\""
        exit 1
    fi

    get_current_context

    if [[ -z "$GOAL_ID" ]] || [[ "$GOAL_ID" == "null" ]]; then
        echo -e "${RED}No active goal${NC}"
        exit 1
    fi

    if [[ -z "$PLAN_ID" ]] || [[ "$PLAN_ID" == "null" ]]; then
        echo -e "${RED}No active plan. Create or select a plan first.${NC}"
        exit 1
    fi

    local plan_dir="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID"
    local plan_file="$plan_dir/plan.yaml"

    local task_id=$(generate_task_id "$plan_dir" "$title")
    local task_dir="$plan_dir/tasks/$task_id"
    local task_file="$task_dir/task.yaml"

    mkdir -p "$task_dir/actions"

    cat > "$task_file" << EOF
# Task: $title
id: "$task_id"
type: task
plan_id: "$PLAN_ID"
goal_id: "$GOAL_ID"
created: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
updated: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

title: "$title"
description: |
  Describe what this task will accomplish.

why: |
  Explain how this task contributes to the plan.

deliverables: []

acceptance_criteria: []

affected_files:
  create: []
  modify: []
  delete: []

depends_on: []
blocks: []

status: pending

progress:
  actions_total: 0
  actions_completed: 0
  current_action_id: null

blocker: null

confidence:
  pre_start: null
  current: null
  approach_clear: null

uncertainties: []

validation:
  automated:
    checks: []
  human_required: false
  human_review_notes: null

actions: []

timing:
  started: null
  completed: null
  estimated_minutes: null
  actual_minutes: null

checkpoint_before: null
checkpoint_after: null

context:
  relevant_code: []
  decisions_made: []
  learnings: []
EOF

    # Add task to plan
    if grep -q "^tasks: \[\]" "$plan_file" 2>/dev/null; then
        sed -i.bak "s/^tasks: \[\]/tasks:\n  - $task_id/" "$plan_file" && rm -f "$plan_file.bak"
    else
        sed -i.bak "/^tasks:/a\\
  - $task_id" "$plan_file" && rm -f "$plan_file.bak"
    fi

    local tasks_total=$(grep -c "^  - t-" "$plan_file" 2>/dev/null || echo "1")
    sed -i.bak "s/tasks_total: .*/tasks_total: $tasks_total/" "$plan_file" && rm -f "$plan_file.bak"

    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/task_id: .*/task_id: $task_id/" "$current_file" && rm -f "$current_file.bak"

    echo ""
    echo -e "${GREEN}✓ Task created: $task_id${NC}"
    echo ""
    echo -e "${GRAY}Location:${NC} $task_file"
    echo ""
    echo "Next: threads task start"
}

cmd_list() {
    get_current_context

    if [[ -z "$PLAN_ID" ]] || [[ "$PLAN_ID" == "null" ]]; then
        echo -e "${YELLOW}No active plan${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    local plan_title=$(yaml_get "$plan_file" "title")

    echo ""
    echo -e "${BOLD}Tasks for: $plan_title${NC}"
    echo ""

    local count=0
    for task_dir in "$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks"/*/; do
        if [[ -d "$task_dir" ]]; then
            local task_id=$(basename "$task_dir")
            local task_file="$task_dir/task.yaml"

            if [[ -f "$task_file" ]]; then
                local title=$(yaml_get "$task_file" "title")
                local status=$(yaml_get "$task_file" "status")

                case "$status" in
                    completed) ICON="✅" ;;
                    in_progress) ICON="🔄" ;;
                    blocked) ICON="❌" ;;
                    failed) ICON="💥" ;;
                    *) ICON="⬜" ;;
                esac

                if [[ "$task_id" == "$TASK_ID" ]]; then
                    echo -e "  $ICON ${BOLD}$title${NC} ${CYAN}← current${NC}"
                else
                    echo -e "  $ICON ${BOLD}$title${NC}"
                fi
                echo -e "     ${GRAY}ID:${NC} $task_id | ${GRAY}Status:${NC} $status"
                echo ""
                ((count++))
            fi
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "  ${GRAY}No tasks yet${NC}"
        echo ""
        echo "  Create one with: threads task new \"Task title\""
    fi
    echo ""
}

cmd_select() {
    local task_id="$1"
    get_current_context

    if [[ -z "$task_id" ]]; then
        echo -e "${RED}Error: Task ID required${NC}"
        exit 1
    fi

    local task_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$task_id/task.yaml"

    if [[ ! -f "$task_file" ]]; then
        echo -e "${RED}Task not found: $task_id${NC}"
        exit 1
    fi

    local title=$(yaml_get "$task_file" "title")
    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/task_id: .*/task_id: $task_id/" "$current_file" && rm -f "$current_file.bak"

    echo -e "${GREEN}✓ Switched to task: $title${NC}"
}

cmd_start() {
    get_current_context

    if [[ -z "$TASK_ID" ]] || [[ "$TASK_ID" == "null" ]]; then
        echo -e "${RED}No active task${NC}"
        exit 1
    fi

    local task_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"

    sed -i.bak "s/^status: .*/status: in_progress/" "$task_file" && rm -f "$task_file.bak"
    sed -i.bak "s/started: null/started: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$task_file" && rm -f "$task_file.bak"

    local plan_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    local plan_status=$(yaml_get "$plan_file" "status")
    if [[ "$plan_status" == "approved" ]]; then
        sed -i.bak "s/^status: approved/status: in_progress/" "$plan_file" && rm -f "$plan_file.bak"
    fi
    sed -i.bak "s/current_task_id: .*/current_task_id: $TASK_ID/" "$plan_file" && rm -f "$plan_file.bak"

    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/phase: .*/phase: executing/" "$current_file" && rm -f "$current_file.bak"

    local title=$(yaml_get "$task_file" "title")
    echo -e "${GREEN}✓ Started task: $title${NC}"
}

cmd_next() {
    get_current_context

    if [[ -z "$PLAN_ID" ]] || [[ "$PLAN_ID" == "null" ]]; then
        echo -e "${RED}No active plan${NC}"
        exit 1
    fi

    for task_dir in "$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks"/*/; do
        if [[ -d "$task_dir" ]]; then
            local task_id=$(basename "$task_dir")
            local task_file="$task_dir/task.yaml"

            if [[ -f "$task_file" ]]; then
                local status=$(yaml_get "$task_file" "status")
                if [[ "$status" == "pending" ]]; then
                    cmd_select "$task_id"
                    return 0
                fi
            fi
        fi
    done

    echo -e "${YELLOW}No pending tasks found${NC}"
}

show_help() {
    echo "Usage: threads task <command> [options]"
    echo ""
    echo "Commands:"
    echo "  new <title>        Create a new task"
    echo "  list               List all tasks"
    echo "  select <task-id>   Switch to a task"
    echo "  start              Start current task"
    echo "  next               Select next pending task"
}

case "${1:-}" in
    new) shift; cmd_new "$@" ;;
    list|ls) cmd_list ;;
    select|switch) shift; cmd_select "$@" ;;
    start) cmd_start ;;
    next) cmd_next ;;
    help|--help|-h|"") show_help ;;
    *) echo -e "${RED}Unknown command: $1${NC}"; show_help; exit 1 ;;
esac
