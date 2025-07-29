#!/bin/bash
# scripts/update-repos.sh - Update all service repositories

set -e

echo "🔄 Updating all service repositories..."

# Update main deployment repo
echo "📦 Updating deployment repo..."
git pull origin main

# Update submodules to latest commits on their main branches
echo "📦 Updating frontend..."
cd services/frontend
git checkout main
git pull origin main
cd ../..

echo "📦 Updating backend..."
cd services/backend
git checkout main  
git pull origin main
cd ../..

echo "📦 Updating inference server..."
cd services/inference-server
git checkout main
git pull origin main
cd ../..

# Update submodule references in main repo
git add services/
git commit -m "Update submodules to latest versions" || echo "No changes to commit"

echo "✅ All repositories updated successfully!"