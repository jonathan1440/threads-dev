#!/bin/bash
# threads-status.sh - Display current Threads workflow state
# Usage: threads-status.sh [--detail | --json | --brief]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

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
    echo "Run 'threads init' to initialize Threads in this project"
    exit 1
}

PROJECT_DIR="$(dirname "$THREADS_DIR")"

# Parse arguments
DETAIL_LEVEL="normal"
OUTPUT_FORMAT="pretty"

while [[ $# -gt 0 ]]; do
    case $1 in
        --detail|-d)
            DETAIL_LEVEL="detail"
            shift
            ;;
        --brief|-b)
            DETAIL_LEVEL="brief"
            shift
            ;;
        --json|-j)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            echo "Usage: threads-status.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -b, --brief    Show minimal status (one line)"
            echo "  -d, --detail   Show detailed status with actions"
            echo "  -j, --json     Output as JSON"
            echo "  -h, --help     Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper to read YAML values (simple implementation)
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

# Read current state
CURRENT_FILE="$THREADS_DIR/current.yaml"

if [[ ! -f "$CURRENT_FILE" ]]; then
    echo -e "${YELLOW}No current.yaml found - Threads not properly initialized${NC}"
    exit 1
fi

# Extract current context
GOAL_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "goal_id")
PLAN_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "plan_id")
TASK_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "task_id")
PHASE=$(yaml_get_nested "$CURRENT_FILE" "status" "phase")
SUMMARY=$(yaml_get_nested "$CURRENT_FILE" "status" "summary")
BLOCKER=$(yaml_get_nested "$CURRENT_FILE" "status" "blocker")

# JSON output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    cat << EOF
{
  "threads_dir": "$THREADS_DIR",
  "active": {
    "goal_id": ${GOAL_ID:-null},
    "plan_id": ${PLAN_ID:-null},
    "task_id": ${TASK_ID:-null}
  },
  "status": {
    "phase": "${PHASE:-idle}",
    "summary": "${SUMMARY:-No active work}",
    "blocker": ${BLOCKER:-null}
  }
}
EOF
    exit 0
fi

# Brief output
if [[ "$DETAIL_LEVEL" == "brief" ]]; then
    if [[ "$GOAL_ID" == "null" ]] || [[ -z "$GOAL_ID" ]]; then
        echo -e "${GRAY}idle${NC} - No active work"
    else
        echo -e "${CYAN}${PHASE}${NC} - ${SUMMARY}"
    fi
    exit 0
fi

# Pretty output header
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  THREADS STATUS${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Check if idle
if [[ "$GOAL_ID" == "null" ]] || [[ -z "$GOAL_ID" ]]; then
    echo -e "  ${GRAY}Phase:${NC}  ${YELLOW}idle${NC}"
    echo -e "  ${GRAY}Status:${NC} No active work"
    echo ""
    echo -e "  ${GRAY}Ready to start a new goal.${NC}"
    echo ""
    exit 0
fi

# Display phase with color
case "$PHASE" in
    idle)
        PHASE_COLOR="$GRAY"
        ;;
    planning)
        PHASE_COLOR="$PURPLE"
        ;;
    executing)
        PHASE_COLOR="$CYAN"
        ;;
    validating)
        PHASE_COLOR="$BLUE"
        ;;
    blocked)
        PHASE_COLOR="$RED"
        ;;
    *)
        PHASE_COLOR="$NC"
        ;;
esac

echo -e "  ${GRAY}Phase:${NC}   ${PHASE_COLOR}${PHASE}${NC}"
echo -e "  ${GRAY}Summary:${NC} ${SUMMARY}"

if [[ -n "$BLOCKER" ]] && [[ "$BLOCKER" != "null" ]]; then
    echo -e "  ${RED}Blocker:${NC} ${BLOCKER}"
fi

echo ""

# Load goal info
GOAL_FILE="$THREADS_DIR/goals/$GOAL_ID/goal.yaml"
if [[ -f "$GOAL_FILE" ]]; then
    GOAL_TITLE=$(yaml_get "$GOAL_FILE" "title")
    GOAL_STATUS=$(yaml_get "$GOAL_FILE" "status")
    GOAL_PROGRESS=$(yaml_get_nested "$GOAL_FILE" "progress" "percent_complete")
    PLANS_TOTAL=$(yaml_get_nested "$GOAL_FILE" "progress" "plans_total")
    PLANS_COMPLETED=$(yaml_get_nested "$GOAL_FILE" "progress" "plans_completed")

    # Progress bar
    PROGRESS_NUM=${GOAL_PROGRESS:-0}
    FILLED=$((PROGRESS_NUM / 5))
    EMPTY=$((20 - FILLED))
    PROGRESS_BAR=$(printf '█%.0s' $(seq 1 $FILLED 2>/dev/null) || echo "")
    PROGRESS_BAR+=$(printf '░%.0s' $(seq 1 $EMPTY 2>/dev/null) || echo "░░░░░░░░░░░░░░░░░░░░")

    echo -e "${BOLD}GOAL:${NC} $GOAL_TITLE"
    echo -e "  ${GRAY}Progress:${NC} ${PROGRESS_BAR} ${PROGRESS_NUM}%"
    echo -e "  ${GRAY}Plans:${NC}    ${PLANS_COMPLETED:-0}/${PLANS_TOTAL:-0} complete"
    echo ""
fi

# Load plan info
if [[ -n "$PLAN_ID" ]] && [[ "$PLAN_ID" != "null" ]]; then
    PLAN_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    if [[ -f "$PLAN_FILE" ]]; then
        PLAN_TITLE=$(yaml_get "$PLAN_FILE" "title")
        PLAN_STATUS=$(yaml_get "$PLAN_FILE" "status")
        PLAN_PROGRESS=$(yaml_get_nested "$PLAN_FILE" "progress" "percent_complete")
        TASKS_TOTAL=$(yaml_get_nested "$PLAN_FILE" "progress" "tasks_total")
        TASKS_COMPLETED=$(yaml_get_nested "$PLAN_FILE" "progress" "tasks_completed")

        case "$PLAN_STATUS" in
            completed) STATUS_ICON="✓"; STATUS_COLOR="$GREEN" ;;
            in_progress) STATUS_ICON="◐"; STATUS_COLOR="$CYAN" ;;
            blocked) STATUS_ICON="✗"; STATUS_COLOR="$RED" ;;
            *) STATUS_ICON="○"; STATUS_COLOR="$GRAY" ;;
        esac

        echo -e "${BOLD}PLAN:${NC} $PLAN_TITLE"
        echo -e "  ${GRAY}Status:${NC}  ${STATUS_COLOR}${STATUS_ICON} ${PLAN_STATUS}${NC}"
        echo -e "  ${GRAY}Tasks:${NC}   ${TASKS_COMPLETED:-0}/${TASKS_TOTAL:-0} complete"
        echo ""
    fi
fi

# Load task info
if [[ -n "$TASK_ID" ]] && [[ "$TASK_ID" != "null" ]]; then
    TASK_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"
    if [[ -f "$TASK_FILE" ]]; then
        TASK_TITLE=$(yaml_get "$TASK_FILE" "title")
        TASK_STATUS=$(yaml_get "$TASK_FILE" "status")
        ACTIONS_TOTAL=$(yaml_get_nested "$TASK_FILE" "progress" "actions_total")
        ACTIONS_COMPLETED=$(yaml_get_nested "$TASK_FILE" "progress" "actions_completed")

        case "$TASK_STATUS" in
            completed) STATUS_ICON="✓"; STATUS_COLOR="$GREEN" ;;
            in_progress) STATUS_ICON="◐"; STATUS_COLOR="$CYAN" ;;
            blocked) STATUS_ICON="✗"; STATUS_COLOR="$RED" ;;
            failed) STATUS_ICON="✗"; STATUS_COLOR="$RED" ;;
            *) STATUS_ICON="○"; STATUS_COLOR="$GRAY" ;;
        esac

        echo -e "${BOLD}TASK:${NC} $TASK_TITLE"
        echo -e "  ${GRAY}Status:${NC}  ${STATUS_COLOR}${STATUS_ICON} ${TASK_STATUS}${NC}"
        echo -e "  ${GRAY}Actions:${NC} ${ACTIONS_COMPLETED:-0}/${ACTIONS_TOTAL:-0} complete"
        echo ""

        # Show actions in detail mode
        if [[ "$DETAIL_LEVEL" == "detail" ]]; then
            ACTIONS_DIR="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/actions"
            if [[ -d "$ACTIONS_DIR" ]]; then
                echo -e "  ${BOLD}Actions:${NC}"
                for action_file in "$ACTIONS_DIR"/*.yaml; do
                    if [[ -f "$action_file" ]]; then
                        ACTION_ID=$(yaml_get "$action_file" "id")
                        ACTION_TITLE=$(yaml_get "$action_file" "title")
                        ACTION_STATUS=$(yaml_get "$action_file" "status")

                        case "$ACTION_STATUS" in
                            completed) STATUS_ICON="✓"; STATUS_COLOR="$GREEN" ;;
                            in_progress) STATUS_ICON="◐"; STATUS_COLOR="$CYAN" ;;
                            failed) STATUS_ICON="✗"; STATUS_COLOR="$RED" ;;
                            *) STATUS_ICON="○"; STATUS_COLOR="$GRAY" ;;
                        esac

                        echo -e "    ${STATUS_COLOR}${STATUS_ICON}${NC} ${ACTION_ID}: ${ACTION_TITLE}"
                    fi
                done
                echo ""
            fi
        fi
    fi
fi

# Show confidence if in detail mode
if [[ "$DETAIL_LEVEL" == "detail" ]] && [[ -f "$GOAL_FILE" ]]; then
    CONFIDENCE=$(yaml_get_nested "$GOAL_FILE" "confidence" "overall")
    if [[ -n "$CONFIDENCE" ]] && [[ "$CONFIDENCE" != "null" ]]; then
        # Convert to percentage
        CONF_PCT=$(echo "$CONFIDENCE * 100" | bc 2>/dev/null || echo "?")
        echo -e "${GRAY}Confidence:${NC} ${CONF_PCT}%"
        echo ""
    fi
fi

# Show resume context
echo -e "${GRAY}───────────────────────────────────────────────────────────${NC}"
echo -e "${GRAY}Resume Context:${NC}"
# Extract multi-line resume_context
awk '/^resume_context:/{found=1; next} found && /^[^ ]/{exit} found{print "  " $0}' "$CURRENT_FILE" | head -20
echo ""
