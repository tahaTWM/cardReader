#!/bin/bash

# Initialize a new git repository
git init
git add -A

# Prompt user to enter repository name, though it's not used in the script below as the URL is hard-coded
read -p "Enter Repo Name: " repo

# Set up remote repository URL
git remote add origin https://github.com/tahaTWM/cardReader.git

# Prompt user to enter commit message, use date-time as commit message here
read -p "Enter Commit Message: " msg
TM=$(date +"%Y-%m-%d, %T")

git commit -m "${msg}-${TM}"

# Prompt for branch to push to, default to master if not specified
read -p "main or uat? " branch
if [ "$branch" == "main" ]; then
    git branch -M main
    git push -u origin main --force
else
    git branch -M uat
    git push -u origin uat --force
fi

# Wait for the user to press any key to close
read -p "It is done. Press any key to close..."