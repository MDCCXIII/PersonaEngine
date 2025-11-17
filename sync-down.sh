#!/bin/bash

# sync-down.sh: Reset local to match remote
BRANCH="main"

echo "🌐 Fetching latest from remote..."
git fetch --all

echo "💣 Resetting local copy to origin/$BRANCH ..."
git reset --hard origin/$BRANCH

echo "📁 Cleaning untracked files..."
git clean -fd

echo "✅ Local copy reset to match remote exactly."

