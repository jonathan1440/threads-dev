#!/bin/bash
# threads-test.sh - Run validation checks for current task
# Usage: threads-test.sh [--all] [--task task-id]

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

# Parse arguments
RUN_ALL=false
TASK_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all|-a)
            RUN_ALL=true
            shift
            ;;
        --task|-t)
            TASK_ID="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: threads-test.sh [OPTIONS]"
            echo ""
            echo "Run validation checks defined in the current (or specified) task."
            echo ""
            echo "Options:"
            echo "  -a, --all         Run all validation checks from goal"
            echo "  -t, --task ID     Run checks for specific task"
            echo "  -h, --help        Show this help"
            echo ""
            echo "This command reads the validation.automated.checks from task.yaml"
            echo "and executes each check, reporting pass/fail status."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Helper to read YAML
yaml_get_nested() {
    local file="$1"
    local key="$2"
    local subkey="$3"
    awk "/^${key}:/{found=1; next} found && /^  ${subkey}:/{print; exit} found && /^[^ ]/{exit}" "$file" 2>/dev/null | sed "s/^  ${subkey}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

# Read current state
CURRENT_FILE="$THREADS_DIR/current.yaml"

if [[ -z "$TASK_ID" ]]; then
    # Get current task from current.yaml
    TASK_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "task_id")
fi

GOAL_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "goal_id")
PLAN_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "plan_id")

if [[ -z "$TASK_ID" ]] || [[ "$TASK_ID" == "null" ]]; then
    if [[ "$RUN_ALL" != true ]]; then
        echo -e "${YELLOW}No active task. Use --all to run goal-level checks.${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  THREADS TEST RUNNER${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

TOTAL_CHECKS=0
PASSED=0
FAILED=0

run_check() {
    local check_type="$1"
    local command="$2"
    local source="$3"

    ((TOTAL_CHECKS++))

    echo -e "  ${CYAN}Running:${NC} $check_type"
    echo -e "  ${GRAY}Command:${NC} $command"
    echo -e "  ${GRAY}Source:${NC} $source"

    # Run the command
    cd "$PROJECT_DIR"

    set +e
    output=$(eval "$command" 2>&1)
    exit_code=$?
    set -e

    if [[ $exit_code -eq 0 ]]; then
        echo -e "  ${GREEN}✓ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "  ${RED}✗ FAILED${NC} (exit code: $exit_code)"
        if [[ -n "$output" ]]; then
            echo -e "  ${GRAY}Output:${NC}"
            echo "$output" | head -20 | sed 's/^/    /'
            if [[ $(echo "$output" | wc -l) -gt 20 ]]; then
                echo "    ... (truncated)"
            fi
        fi
        ((FAILED++))
    fi
    echo ""
}

# Run task-level checks
if [[ -n "$TASK_ID" ]] && [[ "$TASK_ID" != "null" ]] && [[ -n "$GOAL_ID" ]] && [[ "$GOAL_ID" != "null" ]] && [[ -n "$PLAN_ID" ]] && [[ "$PLAN_ID" != "null" ]]; then
    TASK_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"

    if [[ -f "$TASK_FILE" ]]; then
        TASK_TITLE=$(grep "^title:" "$TASK_FILE" | sed 's/title:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

        echo -e "${BOLD}Task: $TASK_TITLE${NC}"
        echo -e "${GRAY}ID: $TASK_ID${NC}"
        echo ""

        # Extract checks from validation.automated.checks
        in_checks=false
        check_type=""
        check_command=""

        while IFS= read -r line; do
            # Detect start of checks section
            if [[ "$line" =~ ^[[:space:]]*checks: ]]; then
                in_checks=true
                continue
            fi

            # Exit checks section when we hit non-indented line
            if [[ "$in_checks" == true ]] && [[ "$line" =~ ^[[:space:]]{0,3}[^[:space:]] ]] && [[ ! "$line" =~ ^[[:space:]]*- ]]; then
                in_checks=false
            fi

            if [[ "$in_checks" == true ]]; then
                # Parse check entry
                if [[ "$line" =~ ^[[:space:]]*-\ type:[[:space:]]*(.+) ]]; then
                    check_type="${BASH_REMATCH[1]}"
                    check_type=$(echo "$check_type" | sed 's/^"//' | sed 's/"$//')
                fi

                if [[ "$line" =~ ^[[:space:]]*command:[[:space:]]*(.+) ]]; then
                    check_command="${BASH_REMATCH[1]}"
                    check_command=$(echo "$check_command" | sed 's/^"//' | sed 's/"$//')

                    # Run the check
                    if [[ -n "$check_type" ]] && [[ -n "$check_command" ]]; then
                        run_check "$check_type" "$check_command" "$TASK_ID"
                        check_type=""
                        check_command=""
                    fi
                fi
            fi
        done < "$TASK_FILE"
    fi
fi

# Run goal-level checks if --all
if [[ "$RUN_ALL" == true ]] && [[ -n "$GOAL_ID" ]] && [[ "$GOAL_ID" != "null" ]]; then
    GOAL_FILE="$THREADS_DIR/goals/$GOAL_ID/goal.yaml"

    if [[ -f "$GOAL_FILE" ]]; then
        GOAL_TITLE=$(grep "^title:" "$GOAL_FILE" | sed 's/title:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

        echo -e "${BOLD}Goal-Level Checks: $GOAL_TITLE${NC}"
        echo ""

        # Extract goal-level validation commands
        while IFS= read -r line; do
            if [[ "$line" =~ ^[[:space:]]*-\ command:[[:space:]]*(.+) ]]; then
                command="${BASH_REMATCH[1]}"
                command=$(echo "$command" | sed 's/^"//' | sed 's/"$//')
                run_check "goal validation" "$command" "$GOAL_ID"
            fi
        done < <(awk '/^validation:/,/^[^ ]/' "$GOAL_FILE" | awk '/automated:/,/human/' | grep 'command:')
    fi
fi

# Also try common test commands if nothing specific found
if [[ $TOTAL_CHECKS -eq 0 ]]; then
    echo -e "${YELLOW}No validation checks defined in task.${NC}"
    echo ""
    echo -e "Attempting common test commands..."
    echo ""

    # Try npm test
    if [[ -f "$PROJECT_DIR/package.json" ]]; then
        if grep -q '"test"' "$PROJECT_DIR/package.json" 2>/dev/null; then
            run_check "npm test" "npm test" "auto-detected"
        fi
    fi

    # Try pytest
    if [[ -f "$PROJECT_DIR/pytest.ini" ]] || [[ -f "$PROJECT_DIR/setup.py" ]] || [[ -d "$PROJECT_DIR/tests" ]]; then
        if command -v pytest &> /dev/null; then
            run_check "pytest" "pytest" "auto-detected"
        fi
    fi

    # Try go test
    if [[ -f "$PROJECT_DIR/go.mod" ]]; then
        run_check "go test" "go test ./..." "auto-detected"
    fi

    # Try cargo test
    if [[ -f "$PROJECT_DIR/Cargo.toml" ]]; then
        run_check "cargo test" "cargo test" "auto-detected"
    fi
fi

# Summary
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ $TOTAL_CHECKS -eq 0 ]]; then
    echo -e "${YELLOW}No checks were run${NC}"
    echo ""
    echo "Add validation checks to your task.yaml:"
    echo ""
    echo "validation:"
    echo "  automated:"
    echo "    checks:"
    echo "      - type: \"test\""
    echo "        command: \"npm test\""
    echo "      - type: \"lint\""
    echo "        command: \"npm run lint\""
    exit 0
fi

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All checks passed ($PASSED/$TOTAL_CHECKS)${NC}"
    exit 0
else
    echo -e "${RED}✗ $FAILED of $TOTAL_CHECKS checks failed${NC}"
    exit 1
fi
