#!/bin/bash
# threads-checkpoint.sh - Create a checkpoint for current state
# Usage: threads-checkpoint.sh [description] [--files file1 file2 ...]

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
DESCRIPTION=""
FILES=()
PARSE_FILES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --files|-f)
            PARSE_FILES=true
            shift
            ;;
        --help|-h)
            echo "Usage: threads-checkpoint.sh [description] [--files file1 file2 ...]"
            echo ""
            echo "Creates a checkpoint of specified files (or all tracked files)."
            echo ""
            echo "Options:"
            echo "  -f, --files    List of files to checkpoint"
            echo "  -h, --help     Show this help"
            echo ""
            echo "Examples:"
            echo "  threads-checkpoint.sh 'Before refactoring auth'"
            echo "  threads-checkpoint.sh 'Save user model' --files src/models/User.ts"
            exit 0
            ;;
        *)
            if [[ "$PARSE_FILES" == true ]]; then
                FILES+=("$1")
            else
                DESCRIPTION="$1"
            fi
            shift
            ;;
    esac
done

# Read current state
CURRENT_FILE="$THREADS_DIR/current.yaml"

yaml_get_nested() {
    local file="$1"
    local key="$2"
    local subkey="$3"
    awk "/^${key}:/{found=1; next} found && /^  ${subkey}:/{print; exit} found && /^[^ ]/{exit}" "$file" 2>/dev/null | sed "s/^  ${subkey}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

GOAL_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "goal_id")
PLAN_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "plan_id")
TASK_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "task_id")
ACTION_ID=$(yaml_get_nested "$CURRENT_FILE" "active" "action_id")

# Generate checkpoint ID
TIMESTAMP=$(date +%Y%m%d%H%M%S)
CP_COUNT=$(ls -1 "$THREADS_DIR/checkpoints" 2>/dev/null | wc -l | tr -d ' ')
CP_NUM=$(printf "%03d" $((CP_COUNT + 1)))
CHECKPOINT_ID="cp-${CP_NUM}"

# Create checkpoint directory
CHECKPOINT_DIR="$THREADS_DIR/checkpoints/$CHECKPOINT_ID"
SNAPSHOT_DIR="$CHECKPOINT_DIR/snapshot"
mkdir -p "$SNAPSHOT_DIR"

echo -e "${CYAN}Creating checkpoint ${CHECKPOINT_ID}...${NC}"

# If no files specified, find affected files from current task
if [[ ${#FILES[@]} -eq 0 ]]; then
    # Try to get files from current task
    if [[ -n "$TASK_ID" ]] && [[ "$TASK_ID" != "null" ]] && [[ -n "$GOAL_ID" ]] && [[ "$GOAL_ID" != "null" ]] && [[ -n "$PLAN_ID" ]] && [[ "$PLAN_ID" != "null" ]]; then
        TASK_FILE="$THREADS_DIR/goals/$GOAL_ID/plans/$PLAN_ID/tasks/$TASK_ID/task.yaml"
        if [[ -f "$TASK_FILE" ]]; then
            # Extract affected files (simple parsing)
            while IFS= read -r line; do
                # Clean up the line
                file=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | sed 's/^"//' | sed 's/"$//' | sed "s/^'//" | sed "s/'$//")
                if [[ -n "$file" ]] && [[ -f "$PROJECT_DIR/$file" ]]; then
                    FILES+=("$file")
                fi
            done < <(awk '/^affected_files:/,/^[^ ]/' "$TASK_FILE" | grep '^\s*-' || true)
        fi
    fi
fi

# If still no files, use git to find modified files
if [[ ${#FILES[@]} -eq 0 ]] && [[ -d "$PROJECT_DIR/.git" ]]; then
    while IFS= read -r file; do
        if [[ -n "$file" ]] && [[ -f "$PROJECT_DIR/$file" ]]; then
            FILES+=("$file")
        fi
    done < <(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null && git diff --cached --name-only 2>/dev/null | sort -u)
fi

# Snapshot files
SNAPSHOT_FILES=()
for file in "${FILES[@]}"; do
    src_path="$PROJECT_DIR/$file"
    if [[ -f "$src_path" ]]; then
        # Create directory structure in snapshot
        dest_dir="$SNAPSHOT_DIR/$(dirname "$file")"
        mkdir -p "$dest_dir"

        # Copy file
        cp "$src_path" "$SNAPSHOT_DIR/$file"

        # Calculate hash
        if command -v sha256sum &> /dev/null; then
            HASH=$(sha256sum "$src_path" | cut -d' ' -f1)
        elif command -v shasum &> /dev/null; then
            HASH=$(shasum -a 256 "$src_path" | cut -d' ' -f1)
        else
            HASH="unavailable"
        fi

        SIZE=$(wc -c < "$src_path" | tr -d ' ')

        SNAPSHOT_FILES+=("$file:$HASH:$SIZE")
        echo -e "  ${GREEN}✓${NC} $file"
    else
        echo -e "  ${YELLOW}⚠${NC} $file (not found, skipping)"
    fi
done

if [[ ${#SNAPSHOT_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}Warning: No files to checkpoint${NC}"
    rm -rf "$CHECKPOINT_DIR"
    exit 0
fi

# Get git info if available
GIT_BRANCH=""
GIT_COMMIT=""
GIT_DIRTY=""
if [[ -d "$PROJECT_DIR/.git" ]]; then
    GIT_BRANCH=$(cd "$PROJECT_DIR" && git branch --show-current 2>/dev/null || echo "")
    GIT_COMMIT=$(cd "$PROJECT_DIR" && git rev-parse HEAD 2>/dev/null || echo "")
    GIT_DIRTY=$(cd "$PROJECT_DIR" && git diff --name-only 2>/dev/null | head -5 | tr '\n' ',' | sed 's/,$//')
fi

# Generate checkpoint YAML
CHECKPOINT_FILE="$CHECKPOINT_DIR/checkpoint.yaml"

cat > "$CHECKPOINT_FILE" << EOF
# Checkpoint: $CHECKPOINT_ID
id: "$CHECKPOINT_ID"
type: checkpoint
created: "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

trigger:
  type: manual
  source_id: ${ACTION_ID:-null}
  source_type: ${ACTION_ID:+action}

description: "${DESCRIPTION:-Manual checkpoint}"

context:
  goal_id: ${GOAL_ID:-null}
  plan_id: ${PLAN_ID:-null}
  task_id: ${TASK_ID:-null}
  action_id: ${ACTION_ID:-null}

snapshot:
  files:
EOF

# Add file entries
for entry in "${SNAPSHOT_FILES[@]}"; do
    IFS=':' read -r file hash size <<< "$entry"
    # Escape the file path for YAML
    escaped_file=$(echo "$file" | sed 's/"/\\"/g')
    cat >> "$CHECKPOINT_FILE" << EOF
    - path: "$escaped_file"
      hash: "sha256:$hash"
      size: $size
      content_ref: "snapshot/$escaped_file"
EOF
done

# Add git info
cat >> "$CHECKPOINT_FILE" << EOF

  git:
    available: $([ -n "$GIT_BRANCH" ] && echo "true" || echo "false")
    branch: ${GIT_BRANCH:-null}
    commit_hash: ${GIT_COMMIT:-null}
    dirty_files: [${GIT_DIRTY}]
    stash_ref: null

restoration:
  can_restore: true
  method: file_copy
  would_affect:
EOF

for entry in "${SNAPSHOT_FILES[@]}"; do
    IFS=':' read -r file hash size <<< "$entry"
    escaped_file=$(echo "$file" | sed 's/"/\\"/g')
    cat >> "$CHECKPOINT_FILE" << EOF
    - path: "$escaped_file"
      checkpoint_hash: "sha256:$hash"
EOF
done

cat >> "$CHECKPOINT_FILE" << EOF

status: active
restored_at: null
restored_by: null
EOF

echo ""
echo -e "${GREEN}✓ Checkpoint ${CHECKPOINT_ID} created${NC}"
echo -e "  ${GRAY}Files:${NC} ${#SNAPSHOT_FILES[@]}"
echo -e "  ${GRAY}Location:${NC} $CHECKPOINT_DIR"
echo ""
echo -e "  ${GRAY}To restore:${NC} threads-revert.sh $CHECKPOINT_ID"
