#!/bin/bash
# threads-export.sh - Export goal/plan/task as readable markdown
# Usage: threads-export.sh [goal-id] [--output file.md] [--format md|html]

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

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
GOAL_ID=""
OUTPUT_FILE=""
FORMAT="md"
INCLUDE_DIAGRAM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --format|-f)
            FORMAT="$2"
            shift 2
            ;;
        --diagram|-d)
            INCLUDE_DIAGRAM=true
            shift
            ;;
        --list|-l)
            echo -e "${BOLD}Available goals:${NC}"
            echo ""
            for goal_dir in "$THREADS_DIR/goals"/*/; do
                if [[ -d "$goal_dir" ]]; then
                    goal_id=$(basename "$goal_dir")
                    goal_file="$goal_dir/goal.yaml"
                    if [[ -f "$goal_file" ]]; then
                        title=$(grep "^title:" "$goal_file" | sed 's/title:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                        status=$(grep "^status:" "$goal_file" | sed 's/status:[[:space:]]*//')
                        echo -e "  ${CYAN}$goal_id${NC}"
                        echo -e "    ${GRAY}Title:${NC} $title"
                        echo -e "    ${GRAY}Status:${NC} $status"
                        echo ""
                    fi
                fi
            done
            exit 0
            ;;
        --help|-h)
            echo "Usage: threads-export.sh [goal-id] [OPTIONS]"
            echo ""
            echo "Export a goal and its plans/tasks as markdown documentation."
            echo ""
            echo "Options:"
            echo "  -l, --list         List available goals"
            echo "  -o, --output FILE  Write to file instead of stdout"
            echo "  -d, --diagram      Include Mermaid diagram in export"
            echo "  -f, --format FMT   Output format: md (default), html"
            echo "  -h, --help         Show this help"
            echo ""
            echo "Examples:"
            echo "  threads-export.sh --list"
            echo "  threads-export.sh g-20250126-add-user-auth"
            echo "  threads-export.sh g-20250126-add-user-auth -o docs/auth-spec.md"
            echo "  threads-export.sh --diagram -o workflow.md"
            exit 0
            ;;
        *)
            GOAL_ID="$1"
            shift
            ;;
    esac
done

# If no goal specified, use current goal
if [[ -z "$GOAL_ID" ]]; then
    CURRENT_FILE="$THREADS_DIR/current.yaml"
    if [[ -f "$CURRENT_FILE" ]]; then
        GOAL_ID=$(awk '/^active:/{found=1; next} found && /^  goal_id:/{print; exit}' "$CURRENT_FILE" | sed 's/.*goal_id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
    fi
fi

if [[ -z "$GOAL_ID" ]] || [[ "$GOAL_ID" == "null" ]]; then
    echo -e "${RED}Error: No goal specified and no active goal${NC}"
    echo "Use --list to see available goals"
    exit 1
fi

GOAL_DIR="$THREADS_DIR/goals/$GOAL_ID"
GOAL_FILE="$GOAL_DIR/goal.yaml"

if [[ ! -f "$GOAL_FILE" ]]; then
    echo -e "${RED}Error: Goal '$GOAL_ID' not found${NC}"
    exit 1
fi

# Helper to extract YAML values
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

yaml_get_list() {
    local file="$1"
    local key="$2"
    awk "/^${key}:/{found=1; next} found && /^[^ ]/{exit} found && /^  -/{gsub(/^  - /,\"\"); gsub(/\"/,\"\"); print}" "$file" 2>/dev/null
}

yaml_get_multiline() {
    local file="$1"
    local key="$2"
    awk "/^${key}:/{found=1; if(/\\|/){next}} found && /^[^ ]/{exit} found{gsub(/^  /,\"\"); print}" "$file" 2>/dev/null
}

# Generate markdown
generate_markdown() {
    # Goal header
    GOAL_TITLE=$(yaml_get "$GOAL_FILE" "title")
    GOAL_STATUS=$(yaml_get "$GOAL_FILE" "status")
    GOAL_CREATED=$(yaml_get "$GOAL_FILE" "created")
    GOAL_PROGRESS=$(yaml_get_nested "$GOAL_FILE" "progress" "percent_complete")

    echo "# $GOAL_TITLE"
    echo ""
    echo "**Status:** $GOAL_STATUS | **Progress:** ${GOAL_PROGRESS:-0}% | **Created:** $GOAL_CREATED"
    echo ""

    # Include diagram if requested
    if [[ "$INCLUDE_DIAGRAM" == true ]]; then
        echo "## Workflow Diagram"
        echo ""
        "$SCRIPT_DIR/threads-diagram.sh" --goal "$GOAL_ID" 2>/dev/null
        echo ""
    fi

    # Description
    DESCRIPTION=$(yaml_get_multiline "$GOAL_FILE" "description")
    if [[ -n "$DESCRIPTION" ]]; then
        echo "## Description"
        echo ""
        echo "$DESCRIPTION"
        echo ""
    fi

    # Success criteria
    echo "## Success Criteria"
    echo ""
    while IFS= read -r criterion; do
        if [[ -n "$criterion" ]]; then
            echo "- [ ] $criterion"
        fi
    done < <(yaml_get_list "$GOAL_FILE" "success_criteria")
    echo ""

    # Human context
    echo "## Requirements & Constraints"
    echo ""
    echo "### Requirements"
    while IFS= read -r req; do
        if [[ -n "$req" ]]; then
            echo "- $req"
        fi
    done < <(awk '/^human_context:/,/^[^ ]/' "$GOAL_FILE" | awk '/requirements:/,/^  [^ ]/' | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*//')
    echo ""

    echo "### Constraints"
    while IFS= read -r con; do
        if [[ -n "$con" ]]; then
            echo "- $con"
        fi
    done < <(awk '/^human_context:/,/^[^ ]/' "$GOAL_FILE" | awk '/constraints:/,/^  [^ ]/' | grep '^\s*-' | sed 's/^[[:space:]]*-[[:space:]]*//')
    echo ""

    # Confidence
    CONF_UNDERSTANDING=$(yaml_get_nested "$GOAL_FILE" "confidence" "understanding")
    CONF_APPROACH=$(yaml_get_nested "$GOAL_FILE" "confidence" "approach")
    CONF_OVERALL=$(yaml_get_nested "$GOAL_FILE" "confidence" "overall")

    if [[ -n "$CONF_OVERALL" ]] && [[ "$CONF_OVERALL" != "null" ]]; then
        echo "## Confidence"
        echo ""
        echo "| Aspect | Score |"
        echo "|--------|-------|"
        echo "| Understanding | ${CONF_UNDERSTANDING:-?} |"
        echo "| Approach | ${CONF_APPROACH:-?} |"
        echo "| **Overall** | **${CONF_OVERALL}** |"
        echo ""
    fi

    # Plans
    echo "---"
    echo ""
    echo "## Plans"
    echo ""

    PLANS=$(yaml_get_list "$GOAL_FILE" "plans")
    for plan_id in $PLANS; do
        PLAN_FILE="$GOAL_DIR/plans/$plan_id/plan.yaml"
        if [[ -f "$PLAN_FILE" ]]; then
            PLAN_TITLE=$(yaml_get "$PLAN_FILE" "title")
            PLAN_STATUS=$(yaml_get "$PLAN_FILE" "status")
            PLAN_PROGRESS=$(yaml_get_nested "$PLAN_FILE" "progress" "percent_complete")

            case "$PLAN_STATUS" in
                completed) STATUS_ICON="✅" ;;
                in_progress) STATUS_ICON="🔄" ;;
                blocked) STATUS_ICON="❌" ;;
                *) STATUS_ICON="⬜" ;;
            esac

            echo "### $STATUS_ICON $PLAN_TITLE"
            echo ""
            echo "**ID:** \`$plan_id\` | **Status:** $PLAN_STATUS | **Progress:** ${PLAN_PROGRESS:-0}%"
            echo ""

            # Approach
            APPROACH=$(yaml_get_multiline "$PLAN_FILE" "approach")
            if [[ -n "$APPROACH" ]]; then
                echo "**Approach:**"
                echo ""
                echo "$APPROACH"
                echo ""
            fi

            # Rationale
            RATIONALE=$(yaml_get_multiline "$PLAN_FILE" "rationale")
            if [[ -n "$RATIONALE" ]]; then
                echo "**Rationale:** $RATIONALE"
                echo ""
            fi

            # Tasks
            echo "#### Tasks"
            echo ""

            TASKS=$(yaml_get_list "$PLAN_FILE" "tasks")
            for task_id in $TASKS; do
                TASK_FILE="$GOAL_DIR/plans/$plan_id/tasks/$task_id/task.yaml"
                if [[ -f "$TASK_FILE" ]]; then
                    TASK_TITLE=$(yaml_get "$TASK_FILE" "title")
                    TASK_STATUS=$(yaml_get "$TASK_FILE" "status")

                    case "$TASK_STATUS" in
                        completed) TASK_ICON="✅" ;;
                        in_progress) TASK_ICON="🔄" ;;
                        blocked) TASK_ICON="❌" ;;
                        failed) TASK_ICON="💥" ;;
                        *) TASK_ICON="⬜" ;;
                    esac

                    echo "- $TASK_ICON **$task_id:** $TASK_TITLE ($TASK_STATUS)"
                fi
            done
            echo ""
        fi
    done

    # Uncertainties
    echo "---"
    echo ""
    echo "## Uncertainties"
    echo ""

    UNCERTAINTIES=$(awk '/^uncertainties:/,/^[^ ]/' "$GOAL_FILE" | grep -A3 '^\s*- area:' || echo "")
    if [[ -n "$UNCERTAINTIES" ]]; then
        echo "| Area | Description | Impact | Resolution |"
        echo "|------|-------------|--------|------------|"
        awk '/^uncertainties:/,/^[^ ]/' "$GOAL_FILE" | awk '
            /- area:/ { area = $NF; gsub(/"/, "", area) }
            /description:/ { desc = substr($0, index($0, ":")+2); gsub(/"/, "", desc) }
            /impact:/ { impact = $NF }
            /resolution:/ {
                res = substr($0, index($0, ":")+2);
                gsub(/"/, "", res);
                if (res == "null") res = "-";
                print "| " area " | " desc " | " impact " | " res " |"
            }
        ' 2>/dev/null || echo "None recorded."
    else
        echo "None recorded."
    fi
    echo ""

    # Footer
    echo "---"
    echo ""
    echo "*Exported from Threads on $(date -u +"%Y-%m-%d %H:%M UTC")*"
}

# Output
if [[ -n "$OUTPUT_FILE" ]]; then
    generate_markdown > "$OUTPUT_FILE"
    echo -e "${GREEN}✓ Exported to $OUTPUT_FILE${NC}"
else
    generate_markdown
fi
