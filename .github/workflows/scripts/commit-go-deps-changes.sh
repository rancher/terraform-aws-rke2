#!/usr/bin/env bash
set -euo pipefail

git config --global user.name "github-actions[bot]"
git config --global user.email "github-actions[bot]@users.noreply.github.com"

if [[ -z "$(git status --porcelain)" ]]; then
  echo "No changes detected."
  echo "has_changes=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Changes detected, committing and pushing..."
BRANCH_NAME="automation/update-go-deps-$(date +%Y%m%d)"
git checkout -b "$BRANCH_NAME"
git add .
git commit -m "chore(deps): update go dependencies"
git push origin "$BRANCH_NAME" --force

echo "has_changes=true" >> "$GITHUB_OUTPUT"
echo "branch_name=$BRANCH_NAME" >> "$GITHUB_OUTPUT"
