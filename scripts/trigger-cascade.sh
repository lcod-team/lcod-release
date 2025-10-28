#!/usr/bin/env bash
set -euo pipefail

# Trigger kernel CI pipelines after shared spec/resolver updates.
# Requires the GitHub CLI (`gh`) authenticated with repo scope.

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required. Install from https://cli.github.com/." >&2
  exit 1
fi

REPO_LIST="${REPO_LIST:-}"
if [[ -n "${REPO_LIST}" ]]; then
  IFS=',' read -r -a REPOS <<< "${REPO_LIST}"
else
  REPOS=(
    "lcod-team/lcod-kernel-js"
    "lcod-team/lcod-kernel-rs"
    "lcod-team/lcod-kernel-java"
  )
fi

WORKFLOW="${WORKFLOW:-ci.yml}"
REF="${REF:-main}"

for repo in "${REPOS[@]}"; do
  echo "Triggering ${WORKFLOW} on ${repo}@${REF}"
  gh workflow run "${WORKFLOW}" --repo "${repo}" --ref "${REF}" || {
    echo "Failed to trigger ${repo}. Check authentication and workflow name." >&2
  }
done
