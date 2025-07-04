#!/bin/bash

# Check if comment is provided
if [ "$1" = "-comment" ] && [ -n "$2" ]; then
    COMMIT_MESSAGE="$2"
else
    COMMIT_MESSAGE="Update configuration files"
fi

# Add all changes
git add .

# Commit with the provided message
git commit -m "$COMMIT_MESSAGE"

# Show status
git status
