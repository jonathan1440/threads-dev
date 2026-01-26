#!/bin/bash
# threads-done.sh - Mark items as complete
# Usage: threads done [task|plan|goal] [--failed]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

complete_task() {
    local failed="${1:-false}"
    get_current_context

    if [[ -z "$TASK_ID" ]] || [[ "$TASK_ID" == "null" ]]; then
        echo -e "${RED}No active task${NC}"
        exit 1
    fi

    local task_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"
    local task_title=$(yaml_get "$task_file" "title")

    if [[ "$failed" == true ]]; then
        sed -i.bak "s/^status: .*/status: failed/" "$task_file" && rm -f "$task_file.bak"
        echo -e "${RED}✗ Task marked as failed: $task_title${NC}"
    else
        sed -i.bak "s/^status: .*/status: completed/" "$task_file" && rm -f "$task_file.bak"
        echo -e "${GREEN}✓ Task completed: $task_title${NC}"
    fi

    sed -i.bak "s/completed: null/completed: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$task_file" && rm -f "$task_file.bak"

    # Update plan progress
    local plan_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    local tasks_completed=$(grep -l "^status: completed" "$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks"/*/task.yaml 2>/dev/null | wc -l | tr -d ' ')
    local tasks_total=$(ls -1d "$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks"/*/ 2>/dev/null | wc -l | tr -d ' ')

    sed -i.bak "s/tasks_completed: .*/tasks_completed: $tasks_completed/" "$plan_file" && rm -f "$plan_file.bak"

    if [[ "$tasks_total" -gt 0 ]]; then
        local plan_progress=$((tasks_completed * 100 / tasks_total))
        sed -i.bak "s/percent_complete: .*/percent_complete: $plan_progress/" "$plan_file" && rm -f "$plan_file.bak"
    fi

    # Clear current task
    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/task_id: .*/task_id: null/" "$current_file" && rm -f "$current_file.bak"

    echo ""
    echo "Next: threads task next"
}

complete_plan() {
    local failed="${1:-false}"
    get_current_context

    if [[ -z "$PLAN_ID" ]] || [[ "$PLAN_ID" == "null" ]]; then
        echo -e "${RED}No active plan${NC}"
        exit 1
    fi

    local plan_file="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    local plan_title=$(yaml_get "$plan_file" "title")

    if [[ "$failed" == true ]]; then
        sed -i.bak "s/^status: .*/status: abandoned/" "$plan_file" && rm -f "$plan_file.bak"
        echo -e "${RED}✗ Plan abandoned: $plan_title${NC}"
    else
        sed -i.bak "s/^status: .*/status: completed/" "$plan_file" && rm -f "$plan_file.bak"
        sed -i.bak "s/percent_complete: .*/percent_complete: 100/" "$plan_file" && rm -f "$plan_file.bak"
        echo -e "${GREEN}✓ Plan completed: $plan_title${NC}"
    fi

    # Update goal progress
    local goal_file="$THREADS_DIR/goals/$GOAL_ID/goal.yaml"
    local plans_completed=$(grep -l "^status: completed" "$THREADS_DIR/goals/$GOAL_ID/plans"/*/plan.yaml 2>/dev/null | wc -l | tr -d ' ')
    local plans_total=$(ls -1d "$THREADS_DIR/goals/$GOAL_ID/plans"/*/ 2>/dev/null | wc -l | tr -d ' ')

    sed -i.bak "s/plans_completed: .*/plans_completed: $plans_completed/" "$goal_file" && rm -f "$goal_file.bak"

    if [[ "$plans_total" -gt 0 ]]; then
        local goal_progress=$((plans_completed * 100 / plans_total))
        sed -i.bak "s/percent_complete: .*/percent_complete: $goal_progress/" "$goal_file" && rm -f "$goal_file.bak"
    fi

    local current_file="$THREADS_DIR/current.yaml"
    sed -i.bak "s/plan_id: .*/plan_id: null/" "$current_file" && rm -f "$current_file.bak"
    sed -i.bak "s/task_id: .*/task_id: null/" "$current_file" && rm -f "$current_file.bak"
}

complete_goal() {
    local failed="${1:-false}"
    get_current_context

    if [[ -z "$GOAL_ID" ]] || [[ "$GOAL_ID" == "null" ]]; then
        echo -e "${RED}No active goal${NC}"
        exit 1
    fi

    local goal_file="$THREADS_DIR/goals/$GOAL_ID/goal.yaml"
    local goal_title=$(yaml_get "$goal_file" "title")

    if [[ "$failed" == true ]]; then
        sed -i.bak "s/^status: .*/status: abandoned/" "$goal_file" && rm -f "$goal_file.bak"
        echo -e "${RED}✗ Goal abandoned: $goal_title${NC}"
    else
        sed -i.bak "s/^status: .*/status: completed/" "$goal_file" && rm -f "$goal_file.bak"
        sed -i.bak "s/percent_complete: .*/percent_complete: 100/" "$goal_file" && rm -f "$goal_file.bak"
        echo -e "${GREEN}✓ Goal completed: $goal_title${NC}"
    fi

    local current_file="$THREADS_DIR/current.yaml"
    cat > "$current_file" << EOF
# Current Active Context
active:
  goal_id: null
  plan_id: null
  task_id: null
  action_id: null

session:
  id: null
  started: null
  last_activity: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

status:
  summary: "Goal completed: $goal_title"
  phase: idle
  blocker: null

resume_context: |
  Completed goal: $goal_title
  Ready to start a new goal.
EOF

    echo ""
    echo -e "${CYAN}🎉 Congratulations!${NC}"
}

show_help() {
    echo "Usage: threads done [item] [options]"
    echo ""
    echo "Items: task (default), plan, goal"
    echo "Options: --failed, -f"
}

ITEM="task"
FAILED=false

while [[ $# -gt 0 ]]; do
    case $1 in
        task|plan|goal) ITEM="$1"; shift ;;
        --failed|-f) FAILED=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo -e "${RED}Unknown: $1${NC}"; exit 1 ;;
    esac
done

case "$ITEM" in
    task) complete_task "$FAILED" ;;
    plan) complete_plan "$FAILED" ;;
    goal) complete_goal "$FAILED" ;;
esac
