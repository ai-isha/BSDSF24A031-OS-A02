#!/bin/bash
# Simple commit + push helper for the current branch
# Usage: ./push.sh "your commit message"

MSG="$1"
if [ -z "$MSG" ]; then
    MSG="chore: update $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo ">> Staging all changes..."
git add -A

echo ">> Committing: $MSG"
git commit -m "$MSG" || echo "(nothing to commit — pushing anyway)"

echo ">> Pushing current branch to origin..."
git push origin HEAD

echo ">> Done."
