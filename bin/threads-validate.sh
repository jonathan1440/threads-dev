#!/bin/bash
# threads-validate.sh - Validate YAML schema compliance and integrity
# Usage: threads-validate.sh [--fix] [--strict]

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

# Parse arguments
FIX_MODE=false
STRICT_MODE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --fix|-f)
            FIX_MODE=true
            shift
            ;;
        --strict|-s)
            STRICT_MODE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: threads-validate.sh [OPTIONS]"
            echo ""
            echo "Validate Threads YAML files for schema compliance and integrity."
            echo ""
            echo "Options:"
            echo "  -f, --fix      Attempt to fix minor issues"
            echo "  -s, --strict   Fail on warnings (not just errors)"
            echo "  -v, --verbose  Show all checks, not just failures"
            echo "  -h, --help     Show this help"
            echo ""
            echo "Checks performed:"
            echo "  - YAML syntax validity"
            echo "  - Required fields present"
            echo "  - ID format compliance"
            echo "  - Reference integrity (goals→plans→tasks→actions)"
            echo "  - Status field validity"
            echo "  - Confidence values in range [0,1]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Counters
ERRORS=0
WARNINGS=0
FIXED=0

# Log functions
log_error() {
    echo -e "  ${RED}ERROR${NC} $1"
    ((ERRORS++))
}

log_warning() {
    echo -e "  ${YELLOW}WARN${NC}  $1"
    ((WARNINGS++))
}

log_ok() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "  ${GREEN}OK${NC}    $1"
    fi
}

log_fixed() {
    echo -e "  ${CYAN}FIXED${NC} $1"
    ((FIXED++))
}

# Check YAML syntax
check_yaml_syntax() {
    local file="$1"
    local rel_path="${file#$THREADS_DIR/}"

    # Basic YAML syntax check using grep for common issues
    # (A full check would require a YAML parser like yq or python)

    # Check for tabs (YAML doesn't allow tabs for indentation)
    if grep -q $'\t' "$file" 2>/dev/null; then
        if [[ "$FIX_MODE" == true ]]; then
            sed -i.bak 's/\t/  /g' "$file" && rm -f "$file.bak"
            log_fixed "$rel_path: Converted tabs to spaces"
        else
            log_error "$rel_path: Contains tabs (YAML requires spaces)"
        fi
    fi

    # Check for trailing whitespace
    if grep -q '[[:space:]]$' "$file" 2>/dev/null; then
        if [[ "$FIX_MODE" == true ]]; then
            sed -i.bak 's/[[:space:]]*$//' "$file" && rm -f "$file.bak"
            log_fixed "$rel_path: Removed trailing whitespace"
        else
            log_warning "$rel_path: Has trailing whitespace"
        fi
    fi

    # Check for Windows line endings
    if grep -q $'\r' "$file" 2>/dev/null; then
        if [[ "$FIX_MODE" == true ]]; then
            sed -i.bak 's/\r$//' "$file" && rm -f "$file.bak"
            log_fixed "$rel_path: Converted CRLF to LF"
        else
            log_warning "$rel_path: Has Windows line endings (CRLF)"
        fi
    fi

    log_ok "$rel_path: YAML syntax"
}

# Check required fields
check_required_fields() {
    local file="$1"
    local type="$2"
    local rel_path="${file#$THREADS_DIR/}"

    case "$type" in
        goal)
            REQUIRED_FIELDS="id title status"
            ;;
        plan)
            REQUIRED_FIELDS="id title goal_id status"
            ;;
        task)
            REQUIRED_FIELDS="id title plan_id status"
            ;;
        action)
            REQUIRED_FIELDS="id task_id status"
            ;;
        checkpoint)
            REQUIRED_FIELDS="id created"
            ;;
        *)
            return
            ;;
    esac

    for field in $REQUIRED_FIELDS; do
        if ! grep -q "^${field}:" "$file" 2>/dev/null; then
            log_error "$rel_path: Missing required field '$field'"
        else
            log_ok "$rel_path: Has '$field'"
        fi
    done
}

# Check ID format
check_id_format() {
    local file="$1"
    local type="$2"
    local rel_path="${file#$THREADS_DIR/}"

    local id=$(grep "^id:" "$file" 2>/dev/null | sed 's/id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')

    if [[ -z "$id" ]] || [[ "$id" == "null" ]]; then
        log_error "$rel_path: ID is empty or null"
        return
    fi

    case "$type" in
        goal)
            if [[ ! "$id" =~ ^g-[0-9]{8}-.+ ]]; then
                log_warning "$rel_path: Goal ID '$id' doesn't match format g-YYYYMMDD-slug"
            else
                log_ok "$rel_path: Goal ID format"
            fi
            ;;
        plan)
            if [[ ! "$id" =~ ^p-[0-9]{3}-.+ ]]; then
                log_warning "$rel_path: Plan ID '$id' doesn't match format p-NNN-slug"
            else
                log_ok "$rel_path: Plan ID format"
            fi
            ;;
        task)
            if [[ ! "$id" =~ ^t-[0-9]{3}-.+ ]]; then
                log_warning "$rel_path: Task ID '$id' doesn't match format t-NNN-slug"
            else
                log_ok "$rel_path: Task ID format"
            fi
            ;;
        action)
            if [[ ! "$id" =~ ^a-[0-9]{3} ]]; then
                log_warning "$rel_path: Action ID '$id' doesn't match format a-NNN"
            else
                log_ok "$rel_path: Action ID format"
            fi
            ;;
        checkpoint)
            if [[ ! "$id" =~ ^cp-[0-9]{3} ]]; then
                log_warning "$rel_path: Checkpoint ID '$id' doesn't match format cp-NNN"
            else
                log_ok "$rel_path: Checkpoint ID format"
            fi
            ;;
    esac
}

# Check status field validity
check_status_field() {
    local file="$1"
    local type="$2"
    local rel_path="${file#$THREADS_DIR/}"

    local status=$(grep "^status:" "$file" 2>/dev/null | sed 's/status:[[:space:]]*//' | head -1)

    case "$type" in
        goal)
            VALID_STATUSES="not_started planning in_progress blocked validating completed abandoned"
            ;;
        plan)
            VALID_STATUSES="proposed approved in_progress blocked completed abandoned"
            ;;
        task)
            VALID_STATUSES="pending in_progress blocked validating completed failed skipped"
            ;;
        action)
            VALID_STATUSES="pending in_progress completed failed rolled_back"
            ;;
        checkpoint)
            VALID_STATUSES="active restored superseded pruned"
            ;;
        *)
            return
            ;;
    esac

    local status_valid=false
    for valid in $VALID_STATUSES; do
        if [[ "$status" == "$valid" ]]; then
            status_valid=true
            break
        fi
    done

    if [[ "$status_valid" != true ]]; then
        log_error "$rel_path: Invalid status '$status' (valid: $VALID_STATUSES)"
    else
        log_ok "$rel_path: Status '$status' is valid"
    fi
}

# Check confidence values
check_confidence_values() {
    local file="$1"
    local rel_path="${file#$THREADS_DIR/}"

    # Extract confidence values
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]+(understanding|approach|feasibility|overall|pre_start|current|pre_action|post_action):[[:space:]]*([0-9.]+) ]]; then
            local field="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Check if value is between 0 and 1
            if (( $(echo "$value < 0 || $value > 1" | bc -l 2>/dev/null || echo 1) )); then
                log_error "$rel_path: Confidence '$field' value '$value' not in range [0,1]"
            else
                log_ok "$rel_path: Confidence '$field' = $value"
            fi
        fi
    done < <(awk '/^confidence:/,/^[^ ]/' "$file" 2>/dev/null)
}

# Check reference integrity
check_references() {
    local file="$1"
    local type="$2"
    local rel_path="${file#$THREADS_DIR/}"

    case "$type" in
        plan)
            # Check goal_id reference
            local goal_id=$(grep "^goal_id:" "$file" 2>/dev/null | sed 's/goal_id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
            if [[ -n "$goal_id" ]] && [[ "$goal_id" != "null" ]]; then
                if [[ ! -d "$THREADS_DIR/goals/$goal_id" ]]; then
                    log_error "$rel_path: References non-existent goal '$goal_id'"
                else
                    log_ok "$rel_path: Goal reference valid"
                fi
            fi
            ;;
        task)
            # Check plan_id reference
            local plan_id=$(grep "^plan_id:" "$file" 2>/dev/null | sed 's/plan_id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
            local goal_id=$(grep "^goal_id:" "$file" 2>/dev/null | sed 's/goal_id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
            if [[ -n "$plan_id" ]] && [[ "$plan_id" != "null" ]] && [[ -n "$goal_id" ]] && [[ "$goal_id" != "null" ]]; then
                if [[ ! -d "$THREADS_DIR/goals/$goal_id/plans/$plan_id" ]]; then
                    log_error "$rel_path: References non-existent plan '$plan_id'"
                else
                    log_ok "$rel_path: Plan reference valid"
                fi
            fi
            ;;
        action)
            # Check task_id reference
            local task_id=$(grep "^task_id:" "$file" 2>/dev/null | sed 's/task_id:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
            if [[ -n "$task_id" ]] && [[ "$task_id" != "null" ]]; then
                # Actions are nested, so we just check the file exists in the right place
                log_ok "$rel_path: Task reference present"
            fi
            ;;
    esac
}

# Main validation
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  THREADS VALIDATION${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Validate config.yaml
echo -e "${BOLD}Config:${NC}"
CONFIG_FILE="$THREADS_DIR/config.yaml"
if [[ -f "$CONFIG_FILE" ]]; then
    check_yaml_syntax "$CONFIG_FILE"
    log_ok "config.yaml exists"
else
    log_error "config.yaml missing"
fi
echo ""

# Validate current.yaml
echo -e "${BOLD}Current State:${NC}"
CURRENT_FILE="$THREADS_DIR/current.yaml"
if [[ -f "$CURRENT_FILE" ]]; then
    check_yaml_syntax "$CURRENT_FILE"
    log_ok "current.yaml exists"
else
    log_error "current.yaml missing"
fi
echo ""

# Validate goals
echo -e "${BOLD}Goals:${NC}"
for goal_dir in "$THREADS_DIR/goals"/*/; do
    if [[ -d "$goal_dir" ]]; then
        goal_id=$(basename "$goal_dir")
        goal_file="$goal_dir/goal.yaml"

        if [[ -f "$goal_file" ]]; then
            echo -e "  ${CYAN}$goal_id${NC}"
            check_yaml_syntax "$goal_file"
            check_required_fields "$goal_file" "goal"
            check_id_format "$goal_file" "goal"
            check_status_field "$goal_file" "goal"
            check_confidence_values "$goal_file"

            # Validate plans
            for plan_dir in "$goal_dir/plans"/*/; do
                if [[ -d "$plan_dir" ]]; then
                    plan_id=$(basename "$plan_dir")
                    plan_file="$plan_dir/plan.yaml"

                    if [[ -f "$plan_file" ]]; then
                        echo -e "    ${GRAY}└─${NC} $plan_id"
                        check_yaml_syntax "$plan_file"
                        check_required_fields "$plan_file" "plan"
                        check_id_format "$plan_file" "plan"
                        check_status_field "$plan_file" "plan"
                        check_references "$plan_file" "plan"

                        # Validate tasks
                        for task_dir in "$plan_dir/tasks"/*/; do
                            if [[ -d "$task_dir" ]]; then
                                task_id=$(basename "$task_dir")
                                task_file="$task_dir/task.yaml"

                                if [[ -f "$task_file" ]]; then
                                    echo -e "      ${GRAY}└─${NC} $task_id"
                                    check_yaml_syntax "$task_file"
                                    check_required_fields "$task_file" "task"
                                    check_id_format "$task_file" "task"
                                    check_status_field "$task_file" "task"
                                    check_references "$task_file" "task"
                                    check_confidence_values "$task_file"

                                    # Validate actions
                                    for action_file in "$task_dir/actions"/*.yaml; do
                                        if [[ -f "$action_file" ]]; then
                                            check_yaml_syntax "$action_file"
                                            check_required_fields "$action_file" "action"
                                            check_id_format "$action_file" "action"
                                            check_status_field "$action_file" "action"
                                            check_confidence_values "$action_file"
                                        fi
                                    done
                                fi
                            fi
                        done
                    fi
                fi
            done
        else
            log_error "$goal_id: Missing goal.yaml"
        fi
    fi
done
echo ""

# Validate checkpoints
echo -e "${BOLD}Checkpoints:${NC}"
CP_COUNT=0
for cp_dir in "$THREADS_DIR/checkpoints"/*/; do
    if [[ -d "$cp_dir" ]]; then
        cp_id=$(basename "$cp_dir")
        cp_file="$cp_dir/checkpoint.yaml"

        if [[ -f "$cp_file" ]]; then
            ((CP_COUNT++))
            check_yaml_syntax "$cp_file"
            check_required_fields "$cp_file" "checkpoint"
            check_id_format "$cp_file" "checkpoint"
            check_status_field "$cp_file" "checkpoint"

            # Check snapshot directory exists
            if [[ ! -d "$cp_dir/snapshot" ]]; then
                log_warning "$cp_id: Missing snapshot directory"
            fi
        else
            log_error "$cp_id: Missing checkpoint.yaml"
        fi
    fi
done
if [[ $CP_COUNT -eq 0 ]]; then
    log_ok "No checkpoints to validate"
else
    log_ok "$CP_COUNT checkpoint(s) checked"
fi
echo ""

# Summary
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✓ All validations passed${NC}"
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠ Passed with $WARNINGS warning(s)${NC}"
else
    echo -e "${RED}✗ Failed with $ERRORS error(s), $WARNINGS warning(s)${NC}"
fi

if [[ $FIXED -gt 0 ]]; then
    echo -e "${CYAN}  Fixed $FIXED issue(s)${NC}"
fi

echo ""

# Exit code
if [[ $ERRORS -gt 0 ]]; then
    exit 1
elif [[ "$STRICT_MODE" == true ]] && [[ $WARNINGS -gt 0 ]]; then
    exit 1
else
    exit 0
fi
