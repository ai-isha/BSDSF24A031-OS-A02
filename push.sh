#!/bin/bash
# Auto pull + commit + push helper
# Usage: ./push.sh "your commit message"

MSG="$1"
if [ -z "$MSG" ]; then
    MSG="chore: update $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo ">> Pulling latest from origin/main..."
git pull origin main --no-rebase --allow-unrelated-histories --no-edit || {
    echo "!! Pull failed — you probably have a merge conflict."
    echo "!! Fix the conflict, run 'git add <file>' then './push.sh \"msg\"' again."
    exit 1
}

echo ">> Staging all changes..."
git add -A

echo ">> Committing: $MSG"
git commit -m "$MSG" || echo "(nothing to commit — pushing anyway)"

echo ">> Pushing to origin/main..."
git push origin main

echo ">> Done."
