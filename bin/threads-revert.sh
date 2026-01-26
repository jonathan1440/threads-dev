#!/bin/bash
# threads-revert.sh - Restore files from a checkpoint
# Usage: threads-revert.sh <checkpoint-id> [--dry-run] [--force]

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
CHECKPOINT_ID=""
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --force|-f)
            FORCE=true
            shift
            ;;
        --list|-l)
            echo -e "${BOLD}Available checkpoints:${NC}"
            echo ""
            for cp_dir in "$THREADS_DIR/checkpoints"/*/; do
                if [[ -d "$cp_dir" ]]; then
                    cp_id=$(basename "$cp_dir")
                    cp_file="$cp_dir/checkpoint.yaml"
                    if [[ -f "$cp_file" ]]; then
                        created=$(grep "^created:" "$cp_file" | sed 's/created:[[:space:]]*//' | sed 's/"//g')
                        desc=$(grep "^description:" "$cp_file" | sed 's/description:[[:space:]]*//' | sed 's/"//g')
                        file_count=$(grep -c "^    - path:" "$cp_file" 2>/dev/null || echo "0")
                        echo -e "  ${CYAN}$cp_id${NC}"
                        echo -e "    ${GRAY}Created:${NC} $created"
                        echo -e "    ${GRAY}Description:${NC} $desc"
                        echo -e "    ${GRAY}Files:${NC} $file_count"
                        echo ""
                    fi
                fi
            done
            exit 0
            ;;
        --help|-h)
            echo "Usage: threads-revert.sh <checkpoint-id> [OPTIONS]"
            echo ""
            echo "Restore files from a checkpoint."
            echo ""
            echo "Options:"
            echo "  -l, --list      List available checkpoints"
            echo "  -n, --dry-run   Show what would be restored without doing it"
            echo "  -f, --force     Skip confirmation prompt"
            echo "  -h, --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  threads-revert.sh --list"
            echo "  threads-revert.sh cp-001"
            echo "  threads-revert.sh cp-001 --dry-run"
            exit 0
            ;;
        *)
            CHECKPOINT_ID="$1"
            shift
            ;;
    esac
done

if [[ -z "$CHECKPOINT_ID" ]]; then
    echo -e "${RED}Error: Checkpoint ID required${NC}"
    echo "Usage: threads-revert.sh <checkpoint-id>"
    echo "Use --list to see available checkpoints"
    exit 1
fi

# Find checkpoint
CHECKPOINT_DIR="$THREADS_DIR/checkpoints/$CHECKPOINT_ID"
CHECKPOINT_FILE="$CHECKPOINT_DIR/checkpoint.yaml"
SNAPSHOT_DIR="$CHECKPOINT_DIR/snapshot"

if [[ ! -d "$CHECKPOINT_DIR" ]]; then
    echo -e "${RED}Error: Checkpoint '$CHECKPOINT_ID' not found${NC}"
    echo "Use --list to see available checkpoints"
    exit 1
fi

if [[ ! -f "$CHECKPOINT_FILE" ]]; then
    echo -e "${RED}Error: Checkpoint file missing${NC}"
    exit 1
fi

# Extract checkpoint info
yaml_get() {
    local file="$1"
    local key="$2"
    grep "^${key}:" "$file" 2>/dev/null | sed "s/^${key}:[[:space:]]*//" | sed 's/^"//' | sed 's/"$//'
}

DESCRIPTION=$(yaml_get "$CHECKPOINT_FILE" "description")
CREATED=$(yaml_get "$CHECKPOINT_FILE" "created")

echo ""
echo -e "${BOLD}Checkpoint: ${CHECKPOINT_ID}${NC}"
echo -e "${GRAY}Created:${NC} $CREATED"
echo -e "${GRAY}Description:${NC} $DESCRIPTION"
echo ""

# Get list of files to restore
FILES_TO_RESTORE=()
while IFS= read -r line; do
    if [[ "$line" =~ ^[[:space:]]*-\ path: ]]; then
        file_path=$(echo "$line" | sed 's/.*path:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
        FILES_TO_RESTORE+=("$file_path")
    fi
done < "$CHECKPOINT_FILE"

if [[ ${#FILES_TO_RESTORE[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No files to restore in this checkpoint${NC}"
    exit 0
fi

# Show what will be restored
echo -e "${BOLD}Files to restore:${NC}"
for file in "${FILES_TO_RESTORE[@]}"; do
    src="$SNAPSHOT_DIR/$file"
    dest="$PROJECT_DIR/$file"

    if [[ ! -f "$src" ]]; then
        echo -e "  ${RED}✗${NC} $file ${GRAY}(snapshot missing)${NC}"
        continue
    fi

    if [[ -f "$dest" ]]; then
        # Compare hashes
        if command -v sha256sum &> /dev/null; then
            src_hash=$(sha256sum "$src" | cut -d' ' -f1)
            dest_hash=$(sha256sum "$dest" | cut -d' ' -f1)
        elif command -v shasum &> /dev/null; then
            src_hash=$(shasum -a 256 "$src" | cut -d' ' -f1)
            dest_hash=$(shasum -a 256 "$dest" | cut -d' ' -f1)
        else
            src_hash="unknown"
            dest_hash="unknown2"
        fi

        if [[ "$src_hash" == "$dest_hash" ]]; then
            echo -e "  ${GRAY}=${NC} $file ${GRAY}(unchanged)${NC}"
        else
            echo -e "  ${YELLOW}~${NC} $file ${GRAY}(will overwrite)${NC}"
        fi
    else
        echo -e "  ${GREEN}+${NC} $file ${GRAY}(will create)${NC}"
    fi
done
echo ""

# Dry run stops here
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${CYAN}Dry run - no changes made${NC}"
    exit 0
fi

# Confirm unless forced
if [[ "$FORCE" != true ]]; then
    echo -e "${YELLOW}This will overwrite existing files.${NC}"
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create a checkpoint before reverting
echo -e "${CYAN}Creating safety checkpoint before revert...${NC}"
SAFETY_CP=$("$THREADS_DIR/../bin/threads-checkpoint.sh" "Before revert to $CHECKPOINT_ID" --files "${FILES_TO_RESTORE[@]}" 2>/dev/null | grep "Checkpoint cp-" | sed 's/.*\(cp-[0-9]*\).*/\1/' || echo "")

if [[ -n "$SAFETY_CP" ]]; then
    echo -e "  ${GREEN}✓${NC} Safety checkpoint: $SAFETY_CP"
fi
echo ""

# Restore files
echo -e "${BOLD}Restoring files:${NC}"
RESTORED=0
FAILED=0

for file in "${FILES_TO_RESTORE[@]}"; do
    src="$SNAPSHOT_DIR/$file"
    dest="$PROJECT_DIR/$file"

    if [[ ! -f "$src" ]]; then
        echo -e "  ${RED}✗${NC} $file (snapshot missing)"
        ((FAILED++))
        continue
    fi

    # Create directory if needed
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"

    # Copy file
    if cp "$src" "$dest" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $file"
        ((RESTORED++))
    else
        echo -e "  ${RED}✗${NC} $file (copy failed)"
        ((FAILED++))
    fi
done

echo ""

# Update checkpoint status
sed -i.bak "s/^status: active/status: restored/" "$CHECKPOINT_FILE" 2>/dev/null || true
sed -i.bak "s/^restored_at: null/restored_at: \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"/" "$CHECKPOINT_FILE" 2>/dev/null || true
sed -i.bak "s/^restored_by: null/restored_by: \"human\"/" "$CHECKPOINT_FILE" 2>/dev/null || true
rm -f "$CHECKPOINT_FILE.bak"

# Summary
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ Restored $RESTORED files from $CHECKPOINT_ID${NC}"
else
    echo -e "${YELLOW}Restored $RESTORED files, $FAILED failed${NC}"
fi

if [[ -n "$SAFETY_CP" ]]; then
    echo ""
    echo -e "${GRAY}To undo this revert:${NC} threads-revert.sh $SAFETY_CP"
fi
