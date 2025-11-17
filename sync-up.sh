#!/bin/bash

# sync-up.sh: Force push local to remote
BRANCH="main"

echo "🔧 Staging changes..."
git add -A

echo "📝 Committing..."
git commit -m "sync-up: auto commit latest local changes" || echo "No changes to commit."

echo "🚀 Force pushing local → origin/$BRANCH ..."
git push origin $BRANCH --force

echo "✅ Done. Remote now matches your local copy."

