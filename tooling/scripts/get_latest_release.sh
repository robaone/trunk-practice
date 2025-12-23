#!/bin/bash

# Retrieves the latest release tag from GitHub.
# If no release exists, falls back to the initial commit hash.
# Returns: refs/tags/<tag> or the initial commit hash
# Exits with status 1 if no release or commit can be found

function get_latest_release() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: GitHub CLI (gh) is not installed" >&2
    exit 1
  fi

  latest_release=$(gh release list --limit 1 --json tagName --jq '.[0].tagName')
  if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch releases from GitHub" >&2
    exit 1
  fi

  if [ "$latest_release" == "null" ] || [ "$latest_release" == "" ]; then
    # get the initial commit hash
    latest_release=$(git rev-list --max-parents=0 HEAD)
    if [ $? -ne 0 ]; then
      echo "Error: Failed to get initial commit hash" >&2
      exit 1
    fi
  else
    latest_release=refs/tags/$latest_release
  fi
  if [ "$latest_release" == "" ]; then
    echo "No release found" >&2
    exit 1
  fi
  echo "$latest_release"
}

function main() {
  local result
  result=$(get_latest_release) || exit $?
  echo "$result"
}

main || exit $?

