#!/bin/bash

# Simple git commit script
# Usage: ./commit_after_changes.sh -comment "Your commit message"

if [ $# -lt 2 ] || [ "$1" != "-comment" ]; then
    echo "Error: Comment is mandatory!"
    echo "Usage: $0 -comment \"Your commit message\""
    exit 1
fi

# Get the commit message from parameters
COMMIT_MSG="$2"

# Add all changes and commit
git add -A
git commit -m "$COMMIT_MSG"

# Try to push changes (will fail silently if no remote or authentication issues)
echo "Attempting to push changes..."
git push 2>/dev/null || echo "Push failed - changes are committed locally only"

echo "Changes committed with message: $COMMIT_MSG"
