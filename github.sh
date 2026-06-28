#!/bin/bash
 
# Initialize git only if this isn't already a repo (safe to re-run)
if [ ! -d .git ]; then
  git init
fi
 
git add -A
 
# Set up the remote — works whether it's the first run or a later one
REPO_URL="https://github.com/tahaTWM/cardReader.git"
if git remote get-url origin > /dev/null 2>&1; then
  git remote set-url origin "$REPO_URL"
else
  git remote add origin "$REPO_URL"
fi
 
# Commit message
read -p "Enter Commit Message: " msg
TM=$(date +"%Y-%m-%d, %T")
git commit -m "${TM} ${msg} "
 
# Branch selection, with a clear default and basic validation
read -p "Push to main or uat? [main/uat]: " branch
branch=${branch:-uat}  # defaults to uat if left blank
 
if [ "$branch" != "main" ] && [ "$branch" != "uat" ]; then
  echo "Unrecognized branch '$branch' — defaulting to uat."
  branch="uat"
fi
 
git branch -M "$branch"
 
# Force-push only with explicit confirmation, not silently every time
read -p "Force-push (overwrites remote history)? [y/N]: " force_confirm
if [[ "$force_confirm" =~ ^[Yy]$ ]]; then
  git push -u origin "$branch" --force
else
  git push -u origin "$branch"
fi
 
read -p "It is done. Press Enter to close..."