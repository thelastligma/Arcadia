#!/usr/bin/env bash
set -euo pipefail

# push_to_github.sh
# Helper to push this project to GitHub under the account/repo provided.
# By default it targets: https://github.com/thelastligma/Arcadia.git
# It will:
#  - initialize a git repo if needed
#  - create an initial commit (author set to thelastligma)
#  - try to create the remote repo with `gh` if available & authenticated
#  - otherwise push via HTTPS using GITHUB_TOKEN (if provided)

DEFAULT_USER="thelastligma"
DEFAULT_REPO="Arcadia"

GITHUB_USER="${GITHUB_USER:-$DEFAULT_USER}"
GITHUB_REPO="${GITHUB_REPO:-$DEFAULT_REPO}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}" # optional

# CLI args
FORK_MODE=0
if [ "${1:-}" = "--fork" ] || [ "${1:-}" = "-f" ]; then
  FORK_MODE=1
fi

echo "Push helper: target -> ${GITHUB_USER}/${GITHUB_REPO}"

command -v git >/dev/null 2>&1 || { echo "git is required. Install git and try again."; exit 1; }

cwd=$(pwd)

# Ensure we're in a working tree
if [ ! -d .git ]; then
  echo "No git repository found. Initializing..."
  git init
fi

# Add all files and commit if there are changes
git add --all
if git diff --cached --quiet; then
  echo "No changes to commit. Skipping commit step."
else
  echo "Committing files with author set to ${GITHUB_USER} <${GITHUB_USER}@users.noreply.github.com>"
  git -c user.name="${GITHUB_USER}" -c user.email="${GITHUB_USER}@users.noreply.github.com" commit -m "Initial commit"
fi

create_fork_and_set_remote() {
  ORIGINAL_OWNER="$DEFAULT_USER"
  ORIGINAL_REPO="$DEFAULT_REPO"

  # If gh is available, use it to fork
  if command -v gh >/dev/null 2>&1; then
    echo "Attempting to create a fork of ${ORIGINAL_OWNER}/${ORIGINAL_REPO} using gh..."
    set +e
    gh repo fork "${ORIGINAL_OWNER}/${ORIGINAL_REPO}" --remote=true --clone=false 2>/dev/null
    rc=$?
    set -e
    if [ $rc -eq 0 ]; then
      # determine authenticated user
      AUTH_USER=$(gh api user --jq .login 2>/dev/null || true)
      if [ -n "$AUTH_USER" ]; then
        echo "Fork created under ${AUTH_USER}. Setting remote to your fork."
        git remote set-url origin "https://github.com/${AUTH_USER}/${ORIGINAL_REPO}.git"
        return 0
      fi
    else
      echo "gh fork failed or not authorized. Will try API-based fork if token is available."
    fi
  fi

  # If no gh or it failed, try GitHub API using GITHUB_TOKEN
  if [ -n "${GITHUB_TOKEN}" ]; then
    echo "Creating fork using GitHub API (token owner)."
    # Determine token owner
    TOKEN_USER=$(curl -s -H "Authorization: token ${GITHUB_TOKEN}" https://api.github.com/user | grep '"login"' | head -n1 | sed -E 's/\s*"login":\s*"([^"]+)".*/\1/')
    if [ -z "$TOKEN_USER" ]; then
      echo "Could not determine token owner. Aborting fork step.";
      return 1
    fi
    echo "Token owner: $TOKEN_USER"
    # Create fork
    curl -s -X POST -H "Authorization: token ${GITHUB_TOKEN}" "https://api.github.com/repos/${ORIGINAL_OWNER}/${ORIGINAL_REPO}/forks" >/dev/null
    # Wait briefly for GitHub to create the fork
    echo "Waiting for fork to appear..."
    sleep 2
    git remote set-url origin "https://github.com/${TOKEN_USER}/${ORIGINAL_REPO}.git"
    return 0
  fi

  echo "Cannot create fork: neither 'gh' available/authorized nor GITHUB_TOKEN provided."
  return 1
}

if [ $FORK_MODE -eq 1 ]; then
  echo "Fork mode: will attempt to fork ${DEFAULT_USER}/${DEFAULT_REPO} into your account and push there."
  if ! create_fork_and_set_remote; then
    echo "Fork creation failed. Exiting."; exit 1
  fi
fi

# Set remote URL to target repository (HTTPS). If GITHUB_TOKEN provided, use embedded credentials for one-off push.
REMOTE_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
if git remote get-url origin >/dev/null 2>&1; then
  echo "Remote 'origin' already exists. Updating to ${REMOTE_URL}"
  git remote set-url origin "${REMOTE_URL}"
else
  git remote add origin "${REMOTE_URL}"
fi

if [ -n "${GITHUB_TOKEN}" ]; then
  echo "Attempting push with provided GITHUB_TOKEN (temporary remote URL)."
  AUTH_REMOTE="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"
  git remote set-url origin "$AUTH_REMOTE"
  # Ensure a main branch name
  if git show-ref --verify --quiet refs/heads/main; then
    BRANCH=main
  else
    BRANCH=$(git rev-parse --abbrev-ref HEAD || echo main)
  fi
  git push -u origin "$BRANCH"
  # Restore remote without token
  git remote set-url origin "$REMOTE_URL"
  echo "Push complete (token-based)."
  exit 0
fi

echo "No GITHUB_TOKEN provided. Attempting unauthenticated push to ${REMOTE_URL} (this will fail unless you have write access)."
echo "If push fails, provide a token via the GITHUB_TOKEN env var or install/authorize the GitHub CLI 'gh' and re-run."

# Ensure a main branch name
if git show-ref --verify --quiet refs/heads/main; then
  BRANCH=main
else
  BRANCH=$(git rev-parse --abbrev-ref HEAD || echo main)
fi

git push -u origin "$BRANCH" || {
  echo "Push failed. Common fixes:"
  echo " - Provide a token: export GITHUB_TOKEN=ghp_xxx; ./push_to_github.sh"
  echo " - Use gh: gh auth login; gh repo create ${GITHUB_USER}/${GITHUB_REPO} --public --source=. --remote=origin --push"
  echo " - Or manually create the repo on GitHub and then: git remote set-url origin https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git; git push -u origin ${BRANCH}"
  exit 1
}

echo "Push succeeded. Repository: https://github.com/${GITHUB_USER}/${GITHUB_REPO}"
