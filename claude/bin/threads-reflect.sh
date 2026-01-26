#!/bin/bash
# threads-reflect.sh - Self-critique and review current work
# Usage: threads reflect [--focus <area>] [--output <file>]
#
# This implements the Reflection Pattern from agentic workflows:
# The AI critiques its own work, identifies weaknesses, and suggests improvements.

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
FOCUS=""
OUTPUT_FILE=""
SHOW_PROMPT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --focus|-f)
            FOCUS="$2"
            shift 2
            ;;
        --output|-o)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --prompt|-p)
            SHOW_PROMPT=true
            shift
            ;;
        --help|-h)
            echo "Usage: threads reflect [OPTIONS]"
            echo ""
            echo "Generate a self-critique of current work using the Reflection Pattern."
            echo "This helps catch errors, improve quality, and update confidence scores."
            echo ""
            echo "Focus Areas:"
            echo "  --focus accuracy     Check facts, correctness, edge cases"
            echo "  --focus clarity      Check explanation quality, readability"
            echo "  --focus completeness Check if all requirements are addressed"
            echo "  --focus security     Check for vulnerabilities, risks"
            echo "  --focus performance  Check efficiency, optimization opportunities"
            echo "  --focus criteria     Check against task acceptance criteria"
            echo ""
            echo "Options:"
            echo "  -f, --focus <area>   Focus reflection on specific area"
            echo "  -o, --output <file>  Write reflection to file"
            echo "  -p, --prompt         Show the reflection prompt (for manual use)"
            echo "  -h, --help           Show this help"
            echo ""
            echo "Examples:"
            echo "  threads reflect                    # General reflection"
            echo "  threads reflect --focus accuracy   # Focus on correctness"
            echo "  threads reflect --focus criteria   # Check acceptance criteria"
            echo "  threads reflect -o review.md       # Save to file"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
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

yaml_get_list() {
    local file="$1"
    local key="$2"
    awk "/^${key}:/{found=1; next} found && /^[^ ]/{exit} found && /^  -/{gsub(/^  - /,\"\"); gsub(/\"/,\"\"); print}" "$file" 2>/dev/null
}

# Read current state
CURRENT_FILE="$THREADS_DIR/current.yaml"
if [[ ! -f "$CURRENT_FILE" ]]; then
    echo -e "${RED}Error: No current.yaml found${NC}"
    exit 1
fi

GOAL_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "goal_id")
PLAN_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "plan_id")
TASK_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "task_id")

# Determine what to reflect on
REFLECT_LEVEL="project"
REFLECT_FILE=""
REFLECT_TITLE=""
ACCEPTANCE_CRITERIA=""

if [[ -n "$TASK_ID" ]] && [[ "$TASK_ID" != "null" ]]; then
    REFLECT_LEVEL="task"
    TASK_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"
    if [[ -f "$TASK_FILE" ]]; then
        REFLECT_FILE="$TASK_FILE"
        REFLECT_TITLE=$(yaml_get "$TASK_FILE" "title")
        ACCEPTANCE_CRITERIA=$(yaml_get_list "$TASK_FILE" "acceptance_criteria")
    fi
elif [[ -n "$PLAN_ID" ]] && [[ "$PLAN_ID" != "null" ]]; then
    REFLECT_LEVEL="plan"
    PLAN_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/plan.yaml"
    if [[ -f "$PLAN_FILE" ]]; then
        REFLECT_FILE="$PLAN_FILE"
        REFLECT_TITLE=$(yaml_get "$PLAN_FILE" "title")
    fi
elif [[ -n "$GOAL_ID" ]] && [[ "$GOAL_ID" != "null" ]]; then
    REFLECT_LEVEL="goal"
    GOAL_FILE="$THREADS_DIR/goals/$GOAL_ID/goal.yaml"
    if [[ -f "$GOAL_FILE" ]]; then
        REFLECT_FILE="$GOAL_FILE"
        REFLECT_TITLE=$(yaml_get "$GOAL_FILE" "title")
        ACCEPTANCE_CRITERIA=$(yaml_get_list "$GOAL_FILE" "success_criteria")
    fi
else
    echo -e "${YELLOW}No active goal, plan, or task to reflect on.${NC}"
    echo "Create a goal first: threads goal new \"title\""
    exit 1
fi

# Build focus-specific prompts
build_focus_prompt() {
    local focus="$1"
    case "$focus" in
        accuracy)
            cat << 'EOF'
Focus your critique on ACCURACY:
- Are all facts and claims correct?
- Are there any logical errors or inconsistencies?
- Have edge cases been considered?
- Are assumptions stated and valid?
- Could any part be misinterpreted?
EOF
            ;;
        clarity)
            cat << 'EOF'
Focus your critique on CLARITY:
- Would someone unfamiliar with this understand it?
- Is the explanation well-structured?
- Is there unnecessary jargon or complexity?
- Are the key points easy to identify?
- Is the code/documentation readable?
EOF
            ;;
        completeness)
            cat << 'EOF'
Focus your critique on COMPLETENESS:
- Are all requirements addressed?
- Is anything missing that should be included?
- Are there gaps in the implementation?
- Have all specified deliverables been produced?
- Are there unhandled scenarios?
EOF
            ;;
        security)
            cat << 'EOF'
Focus your critique on SECURITY:
- Are there any obvious vulnerabilities?
- Is input validation sufficient?
- Are secrets/credentials properly handled?
- Are there injection risks?
- Is error handling secure (no info leakage)?
EOF
            ;;
        performance)
            cat << 'EOF'
Focus your critique on PERFORMANCE:
- Are there obvious inefficiencies?
- Could any operations be optimized?
- Are there unnecessary computations or API calls?
- Is resource usage reasonable?
- Are there potential bottlenecks?
EOF
            ;;
        criteria)
            cat << 'EOF'
Focus your critique on ACCEPTANCE CRITERIA:
- Go through each criterion one by one
- Mark each as: ✓ Met, ⚠ Partially met, ✗ Not met
- Explain why for any that aren't fully met
- Identify what would be needed to satisfy unmet criteria
EOF
            ;;
        *)
            cat << 'EOF'
Provide a general critique covering:
- Overall quality and correctness
- Any obvious issues or concerns
- What's working well
- What could be improved
- Confidence level (0.0-1.0) with justification
EOF
            ;;
    esac
}

# Display to terminal
echo ""
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}  REFLECTION: ${REFLECT_TITLE:-Current Work}${NC}"
echo -e "${BOLD}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GRAY}Level:${NC} $REFLECT_LEVEL"
echo -e "${GRAY}Focus:${NC} ${FOCUS:-general}"
echo ""

if [[ -n "$ACCEPTANCE_CRITERIA" ]]; then
    echo -e "${BOLD}Acceptance Criteria to Check:${NC}"
    echo "$ACCEPTANCE_CRITERIA" | while read -r criterion; do
        if [[ -n "$criterion" ]]; then
            echo -e "  ${GRAY}○${NC} $criterion"
        fi
    done
    echo ""
fi

echo -e "${BOLD}Reflection Focus:${NC}"
echo ""
build_focus_prompt "$FOCUS" | sed 's/^/  /'
echo ""
echo -e "${GRAY}───────────────────────────────────────────────────────────${NC}"
echo ""
echo -e "${CYAN}AI: Please perform this reflection now.${NC}"
echo ""
echo "Examine the current work and provide:"
echo ""
echo "  ${BOLD}1. Summary${NC}"
echo "     One paragraph overall assessment."
echo ""
echo "  ${BOLD}2. Strengths${NC}"
echo "     - What's working well (bullet points)"
echo ""
echo "  ${BOLD}3. Issues Found${NC}"
echo "     - Problem: [description] - Severity: [high/medium/low]"
echo "     (If none: \"No significant issues found.\")"
echo ""
echo "  ${BOLD}4. Suggested Improvements${NC}"
echo "     1. [Specific actionable improvement]"
echo "     (If none: \"No improvements suggested.\")"
echo ""
if [[ -n "$ACCEPTANCE_CRITERIA" ]]; then
    echo "  ${BOLD}5. Criteria Assessment${NC}"
    echo "     - ✓ Criterion: Met because..."
    echo "     - ⚠ Criterion: Partially met because..."
    echo "     - ✗ Criterion: Not met because..."
    echo ""
fi
echo "  ${BOLD}6. Updated Confidence Score${NC}"
echo "     Score: [0.0-1.0]"
echo "     Justification: [Why this score]"
echo ""
echo "  ${BOLD}7. Recommendation${NC}"
echo "     [proceed / revise / block]"
echo "     - proceed: Work meets standards, continue"
echo "     - revise: Minor issues to fix first"
echo "     - block: Significant issues, need human input"
echo ""

# Record that a reflection was requested
REFLECTION_LOG="$THREADS_DIR/reflections.log"
echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") | $REFLECT_LEVEL | ${REFLECT_TITLE:-unknown} | focus=${FOCUS:-general}" >> "$REFLECTION_LOG"

# If output file requested, write a template
if [[ -n "$OUTPUT_FILE" ]]; then
    cat > "$OUTPUT_FILE" << EOF
# Reflection: ${REFLECT_TITLE:-Current Work}

**Generated:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Level:** $REFLECT_LEVEL
**Focus:** ${FOCUS:-general}

---

## Acceptance Criteria
$(echo "$ACCEPTANCE_CRITERIA" | while read -r c; do [[ -n "$c" ]] && echo "- [ ] $c"; done)

## Reflection

### 1. Summary


### 2. Strengths
-

### 3. Issues Found
-

### 4. Suggested Improvements
1.

### 5. Criteria Assessment
-

### 6. Confidence Score
**Score:**
**Justification:**

### 7. Recommendation
**[proceed / revise / block]**

---
EOF
    echo -e "${GREEN}✓${NC} Reflection template written to: $OUTPUT_FILE"
fi
