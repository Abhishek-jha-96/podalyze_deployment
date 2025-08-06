#!/bin/bash
# scripts/update-repos.sh - Update all service repositories

set -e

echo "🔄 Updating all service repositories..."

# Update main deployment repo
echo "📦 Updating deployment repo..."
git pull origin main

# Update submodules to latest commits on their main branches
echo "📦 Updating frontend..."
cd services/podalyze
git checkout main
git pull origin main
cd ../..

echo "📦 Updating backend..."
cd services/podalyze_backend
git checkout main  
git pull origin main
cd ../..

echo "📦 Updating inference server..."
cd services/podalyze_inference
git checkout main
git pull origin main
cd ../..

# Update submodule references in main repo
git add services/
git commit -m "Update submodules to latest versions" || echo "No changes to commit"

echo "✅ All repositories updated successfully!"