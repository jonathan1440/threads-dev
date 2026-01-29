#!/usr/bin/env bash
# Copy threads-system workflow files into an existing project.
# Usage: ./setup-threads.sh <destination-path>

set -e

THREADS_ROOT="$(cd "$(dirname "$0")" && pwd)"
DEST="${1:?Usage: $0 <destination-path>}"

if [[ ! -d "$DEST" ]]; then
  echo "Error: destination is not a directory: $DEST" >&2
  exit 1
fi

echo "Copying threads-system files into $DEST"
cp -r "$THREADS_ROOT/.cursor" "$DEST/"
cp -r "$THREADS_ROOT/docs" "$DEST/"
cp "$THREADS_ROOT/CLAUDE.md" "$DEST/"
cp "$THREADS_ROOT/README.md" "$DEST/THREADS-README.md"
echo "Done. Edit $DEST/CLAUDE.md for your project and adjust $DEST/.cursor/hooks.json if needed."
