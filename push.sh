#!/bin/bash
# Auto commit + push helper
# Usage: ./push.sh "your commit message"

MSG="$1"

if [ -z "$MSG" ]; then
    MSG="chore: update $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo ">> Adding all changes..."
git add -A

echo ">> Committing: $MSG"
git commit -m "$MSG"

echo ">> Pushing to origin main..."
git push origin main

echo ">> Done."
