#!/bin/bash
# threads-diagram.sh - Generate Mermaid diagrams of workflow state
# Usage: threads-diagram.sh [--flowchart | --gantt | --state] [-o file]

set -e

# Colors for terminal output (used for messages only)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
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
    echo -e "${RED}Error: No .threads directory found${NC}" >&2
    exit 1
}

PROJECT_DIR="$(dirname "$THREADS_DIR")"
PROJECT_NAME=$(basename "$PROJECT_DIR")

# Parse arguments
DIAGRAM_TYPE="flowchart"
OUTPUT_FILE=""
GOAL_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --flowchart|-f)
            DIAGRAM_TYPE="flowchart"
            shift
            ;;
        --gantt|-g)
            DIAGRAM_TYPE="gantt"
            shift
            ;;
        --state|-s)
            DIAGRAM_TYPE="state"
            shift
            ;;
        --goal)
            GOAL_FILTER="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: threads diagram [OPTIONS]"
            echo ""
            echo "Generate Mermaid diagrams of the workflow state."
            echo ""
            echo "Diagram Types:"
            echo "  -f, --flowchart   Hierarchical flowchart (default)"
            echo "  -g, --gantt       Gantt chart of progress"
            echo "  -s, --state       State diagram of current status"
            echo ""
            echo "Options:"
            echo "  --goal <id>       Filter to specific goal"
            echo "  -o, --output      Write to file instead of stdout"
            echo "  -h, --help        Show this help"
            echo ""
            echo "Examples:"
            echo "  threads diagram                    # Flowchart to stdout"
            echo "  threads diagram -o workflow.md    # Save to file"
            echo "  threads diagram --gantt           # Progress as Gantt"
            echo "  threads diagram --goal g-001      # Specific goal only"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Helper to read YAML values
yaml_get() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//"
}

yaml_get_nested() {
    local file="$1"
    local key="$2"
    local subkey="$3"
    awk "/^${key}:/{found=1; next} found && /^  ${subkey}:/{print; exit} found && /^[^ ]/{exit}" "$file" 2>/dev/null | sed "s/^  ${subkey}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# Sanitize text for Mermaid (escape special chars)
sanitize() {
    echo "$1" | sed 's/"/\\"/g' | sed 's/[<>]//g' | tr -d '\n' | cut -c1-50
}

# Read current state
CURRENT_FILE="$THREADS_DIR/current.yaml"
CURRENT_GOAL=""
CURRENT_PLAN=""
CURRENT_TASK=""

if [[ -f "$CURRENT_FILE" ]]; then
    CURRENT_GOAL=$(yaml_get_nested "$CURRENT_FILE" "active" "goal_id")
    CURRENT_PLAN=$(yaml_get_nested "$CURRENT_FILE" "active" "plan_id")
    CURRENT_TASK=$(yaml_get_nested "$CURRENT_FILE" "active" "task_id")
fi

# Generate flowchart
generate_flowchart() {
    echo '```mermaid'
    echo 'flowchart TD'
    echo "    subgraph project[\"$PROJECT_NAME\"]"

    # List all goals
    GOALS_DIR="$THREADS_DIR/goals"
    goal_num=0

    if [[ -d "$GOALS_DIR" ]]; then
        for goal_dir in "$GOALS_DIR"/g-*; do
            [[ -d "$goal_dir" ]] || continue

            goal_id=$(basename "$goal_dir")

            # Filter if specified
            if [[ -n "$GOAL_FILTER" ]] && [[ "$goal_id" != "$GOAL_FILTER" ]]; then
                continue
            fi

            goal_file="$goal_dir/goal.yaml"
            [[ -f "$goal_file" ]] || continue

            goal_num=$((goal_num + 1))
            goal_title=$(sanitize "$(yaml_get "$goal_file" "title")")
            goal_status=$(yaml_get "$goal_file" "status")

            # Node ID (sanitized)
            g_node="G${goal_num}"

            # Style based on status
            case "$goal_status" in
                completed) g_style=":::completed" ;;
                in_progress) g_style=":::inprogress" ;;
                blocked) g_style=":::blocked" ;;
                *) g_style=":::pending" ;;
            esac

            # Current marker
            if [[ "$goal_id" == "$CURRENT_GOAL" ]]; then
                g_style=":::current"
            fi

            echo "        ${g_node}[\"🎯 ${goal_title}\"]${g_style}"

            # List plans under this goal
            PLANS_DIR="$goal_dir/plans"
            plan_num=0

            if [[ -d "$PLANS_DIR" ]]; then
                for plan_dir in "$PLANS_DIR"/p-*; do
                    [[ -d "$plan_dir" ]] || continue

                    plan_id=$(basename "$plan_dir")
                    plan_file="$plan_dir/plan.yaml"
                    [[ -f "$plan_file" ]] || continue

                    plan_num=$((plan_num + 1))
                    plan_title=$(sanitize "$(yaml_get "$plan_file" "title")")
                    plan_status=$(yaml_get "$plan_file" "status")

                    p_node="G${goal_num}P${plan_num}"

                    case "$plan_status" in
                        completed) p_style=":::completed" ;;
                        in_progress) p_style=":::inprogress" ;;
                        approved) p_style=":::approved" ;;
                        blocked) p_style=":::blocked" ;;
                        *) p_style=":::pending" ;;
                    esac

                    if [[ "$plan_id" == "$CURRENT_PLAN" ]]; then
                        p_style=":::current"
                    fi

                    echo "        ${p_node}[\"📋 ${plan_title}\"]${p_style}"
                    echo "        ${g_node} --> ${p_node}"

                    # List tasks under this plan
                    TASKS_DIR="$plan_dir/tasks"
                    task_num=0

                    if [[ -d "$TASKS_DIR" ]]; then
                        for task_dir in "$TASKS_DIR"/t-*; do
                            [[ -d "$task_dir" ]] || continue

                            task_id=$(basename "$task_dir")
                            task_file="$task_dir/task.yaml"
                            [[ -f "$task_file" ]] || continue

                            task_num=$((task_num + 1))
                            task_title=$(sanitize "$(yaml_get "$task_file" "title")")
                            task_status=$(yaml_get "$task_file" "status")

                            t_node="G${goal_num}P${plan_num}T${task_num}"

                            case "$task_status" in
                                completed) t_style=":::completed" ;;
                                in_progress) t_style=":::inprogress" ;;
                                blocked|failed) t_style=":::blocked" ;;
                                *) t_style=":::pending" ;;
                            esac

                            if [[ "$task_id" == "$CURRENT_TASK" ]]; then
                                t_style=":::current"
                            fi

                            echo "        ${t_node}([\"${task_title}\"])${t_style}"
                            echo "        ${p_node} --> ${t_node}"
                        done
                    fi
                done
            fi
        done
    fi

    if [[ $goal_num -eq 0 ]]; then
        echo "        empty[\"No goals yet\"]:::pending"
    fi

    echo "    end"
    echo ""
    echo "    %% Styles"
    echo "    classDef pending fill:#f5f5f5,stroke:#999,color:#666"
    echo "    classDef inprogress fill:#e3f2fd,stroke:#1976d2,color:#1565c0"
    echo "    classDef completed fill:#e8f5e9,stroke:#4caf50,color:#2e7d32"
    echo "    classDef blocked fill:#ffebee,stroke:#f44336,color:#c62828"
    echo "    classDef approved fill:#fff3e0,stroke:#ff9800,color:#e65100"
    echo "    classDef current fill:#fff9c4,stroke:#fbc02d,color:#f57f17,stroke-width:3px"
    echo '```'
}

# Generate Gantt chart
generate_gantt() {
    echo '```mermaid'
    echo 'gantt'
    echo "    title $PROJECT_NAME Progress"
    echo '    dateFormat YYYY-MM-DD'
    echo '    axisFormat %m/%d'
    echo ''

    GOALS_DIR="$THREADS_DIR/goals"

    if [[ -d "$GOALS_DIR" ]]; then
        for goal_dir in "$GOALS_DIR"/g-*; do
            [[ -d "$goal_dir" ]] || continue

            goal_id=$(basename "$goal_dir")

            if [[ -n "$GOAL_FILTER" ]] && [[ "$goal_id" != "$GOAL_FILTER" ]]; then
                continue
            fi

            goal_file="$goal_dir/goal.yaml"
            [[ -f "$goal_file" ]] || continue

            goal_title=$(sanitize "$(yaml_get "$goal_file" "title")")
            goal_status=$(yaml_get "$goal_file" "status")
            goal_created=$(yaml_get "$goal_file" "created" | cut -c1-10)

            [[ -z "$goal_created" ]] && goal_created=$(date +%Y-%m-%d)

            echo "    section ${goal_title}"

            PLANS_DIR="$goal_dir/plans"
            if [[ -d "$PLANS_DIR" ]]; then
                for plan_dir in "$PLANS_DIR"/p-*; do
                    [[ -d "$plan_dir" ]] || continue

                    plan_file="$plan_dir/plan.yaml"
                    [[ -f "$plan_file" ]] || continue

                    plan_title=$(sanitize "$(yaml_get "$plan_file" "title")")
                    plan_status=$(yaml_get "$plan_file" "status")
                    plan_progress=$(yaml_get_nested "$plan_file" "progress" "percent_complete")

                    [[ -z "$plan_progress" ]] && plan_progress=0

                    # Determine Gantt status
                    case "$plan_status" in
                        completed) g_status="done," ;;
                        in_progress) g_status="active," ;;
                        blocked) g_status="crit," ;;
                        *) g_status="" ;;
                    esac

                    # Estimate duration based on tasks
                    TASKS_DIR="$plan_dir/tasks"
                    task_count=$(find "$TASKS_DIR" -maxdepth 1 -type d -name "t-*" 2>/dev/null | wc -l || echo 1)
                    duration="${task_count}d"

                    echo "        ${plan_title} :${g_status} ${goal_created}, ${duration}"
                done
            fi
        done
    fi

    echo '```'
}

# Generate state diagram
generate_state() {
    echo '```mermaid'
    echo 'stateDiagram-v2'
    echo ''

    # Current state
    if [[ -z "$CURRENT_GOAL" ]] || [[ "$CURRENT_GOAL" == "null" ]]; then
        echo '    [*] --> Idle'
        echo '    Idle --> Planning: goal new'
    else
        echo '    [*] --> Active'
        echo ''
        echo '    state Active {'

        if [[ -n "$CURRENT_TASK" ]] && [[ "$CURRENT_TASK" != "null" ]]; then
            echo '        [*] --> Executing'
            echo '        Executing --> Validating: task complete'
            echo '        Validating --> Executing: next task'
            echo '        Validating --> [*]: all tasks done'
        elif [[ -n "$CURRENT_PLAN" ]] && [[ "$CURRENT_PLAN" != "null" ]]; then
            echo '        [*] --> Planning'
            echo '        Planning --> Executing: plan approved'
        else
            echo '        [*] --> GoalSet'
            echo '        GoalSet --> Planning: plan new'
        fi

        echo '    }'
    fi

    echo ''
    echo '    note right of Active'
    if [[ -n "$CURRENT_GOAL" ]] && [[ "$CURRENT_GOAL" != "null" ]]; then
        goal_file="$THREADS_DIR/goals/$CURRENT_GOAL/goal.yaml"
        if [[ -f "$goal_file" ]]; then
            goal_title=$(sanitize "$(yaml_get "$goal_file" "title")")
            echo "        Goal: ${goal_title}"
        fi
    fi
    if [[ -n "$CURRENT_PLAN" ]] && [[ "$CURRENT_PLAN" != "null" ]]; then
        plan_file="$THREADS_DIR/goals/$CURRENT_GOAL/plans/$CURRENT_PLAN/plan.yaml"
        if [[ -f "$plan_file" ]]; then
            plan_title=$(sanitize "$(yaml_get "$plan_file" "title")")
            echo "        Plan: ${plan_title}"
        fi
    fi
    if [[ -n "$CURRENT_TASK" ]] && [[ "$CURRENT_TASK" != "null" ]]; then
        task_file="$THREADS_DIR/goals/$CURRENT_GOAL/plans/$CURRENT_PLAN/tasks/$CURRENT_TASK/task.yaml"
        if [[ -f "$task_file" ]]; then
            task_title=$(sanitize "$(yaml_get "$task_file" "title")")
            echo "        Task: ${task_title}"
        fi
    fi
    echo '    end note'

    echo '```'
}

# Generate the diagram
output=""
case "$DIAGRAM_TYPE" in
    flowchart)
        output=$(generate_flowchart)
        ;;
    gantt)
        output=$(generate_gantt)
        ;;
    state)
        output=$(generate_state)
        ;;
esac

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    echo "$output" > "$OUTPUT_FILE"
    echo -e "${GREEN}✓${NC} Diagram written to: $OUTPUT_FILE" >&2
else
    echo "$output"
fi
