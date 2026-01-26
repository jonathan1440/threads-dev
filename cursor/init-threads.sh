#!/bin/bash
# Initialize Threads workflow system in a project directory
# Usage: ./init-threads.sh [project-directory] [project-name]

set -e

# Get the directory where this script lives
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target directory (default: current directory)
TARGET_DIR="${1:-.}"
PROJECT_NAME="${2:-$(basename "$(cd "$TARGET_DIR" && pwd)")}"

# Resolve to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

echo "Initializing Threads in: $TARGET_DIR"
echo "Project name: $PROJECT_NAME"

# Check if already initialized
if [ -d "$TARGET_DIR/.threads" ]; then
    echo "Warning: .threads directory already exists"
    read -p "Reinitialize? This will NOT delete existing goals. (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

# Create directory structure
echo "Creating directory structure..."
mkdir -p "$TARGET_DIR/.threads"/{goals,checkpoints,context,schemas}

# Copy schemas
echo "Copying schemas..."
cp "$SCRIPT_DIR/.threads/schemas/"*.yaml "$TARGET_DIR/.threads/schemas/" 2>/dev/null || true

# Create config.yaml
echo "Creating config.yaml..."
cat > "$TARGET_DIR/.threads/config.yaml" << EOF
# Threads Configuration
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

version: "1.0"

project:
  name: "$PROJECT_NAME"
  root: "."

confidence:
  proceed: 0.8
  warn: 0.5
  block: 0.3

right_sizing:
  trivial:
    max_files: 1
    max_lines: 20
    max_minutes: 5
  small:
    max_files: 3
    max_lines: 100
    max_minutes: 30
  medium:
    max_files: 10
    max_lines: 500
    max_minutes: 180

checkpoints:
  auto_create: true
  triggers:
    - before_file_delete
    - before_file_overwrite
    - on_task_complete
    - on_plan_complete
  max_checkpoints: 50

validation:
  require_human_approval:
    - goal_creation
    - goal_completion
    - destructive_file_operations
  automated_checks:
    - syntax_validation
    - lint_check
    - type_check

session:
  auto_save_interval: 60
  context_load_depth: 3
EOF

# Create current.yaml
echo "Creating current.yaml..."
cat > "$TARGET_DIR/.threads/current.yaml" << EOF
# Current Active Context
# Updated automatically as work progresses

active:
  goal_id: null
  plan_id: null
  task_id: null
  action_id: null

session:
  id: null
  started: null
  last_activity: null

status:
  summary: "No active work"
  phase: "idle"
  blocker: null

resume_context: |
  Threads initialized for project "$PROJECT_NAME".
  No active work. Ready to start a new goal.
EOF

# Create project context
echo "Creating project context..."
cat > "$TARGET_DIR/.threads/context/project.yaml" << EOF
# Project Context
# Accumulated knowledge about this project

discovered:
  stack: []
  patterns: []
  constraints: []

key_files:
  entry_points: []
  config_files: []
  frequently_modified: []

decisions: []

learnings: []
EOF

# Copy SKILL.md to project
echo "Copying SKILL.md..."
cp "$SCRIPT_DIR/SKILL.md" "$TARGET_DIR/.threads/SKILL.md"

# Add to .gitignore if git repo
if [ -d "$TARGET_DIR/.git" ]; then
    echo "Updating .gitignore..."
    if ! grep -q "\.threads/checkpoints/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$TARGET_DIR/.gitignore"
        echo "# Threads - checkpoint snapshots (can be large)" >> "$TARGET_DIR/.gitignore"
        echo ".threads/checkpoints/*/snapshot/" >> "$TARGET_DIR/.gitignore"
    fi
fi

echo ""
echo "✓ Threads initialized successfully!"
echo ""
echo "Directory structure created:"
echo "  $TARGET_DIR/.threads/"
echo "  ├── config.yaml        # System configuration"
echo "  ├── current.yaml       # Active context pointer"
echo "  ├── SKILL.md           # AI instructions"
echo "  ├── context/"
echo "  │   └── project.yaml   # Project knowledge"
echo "  ├── goals/             # Your goals will live here"
echo "  ├── checkpoints/       # Reversibility snapshots"
echo "  └── schemas/           # YAML templates"
echo ""
echo "Next steps:"
echo "  1. Start working with Cursor AI"
echo "  2. The AI will read .threads/SKILL.md to understand the workflow"
echo "  3. Describe what you want to accomplish"
echo "  4. The AI will create goals, plans, and tasks as needed"
echo ""
