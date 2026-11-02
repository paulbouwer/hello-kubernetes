#!/usr/bin/env bash
# Print the newest non-prerelease tag of a GitHub repo within a major version.
# Usage: github-latest-release.sh <owner/repo> <major>    e.g. helm/helm 4 -> v4.3.1
set -euo pipefail

repo="$1"
major="$2"

curl -fsSL "https://api.github.com/repos/${repo}/releases?per_page=100" \
  | jq -r --arg prefix "v${major}." '
      [ .[]
        | select(.draft == false and .prerelease == false)
        | .tag_name
        | select(startswith($prefix))
        | select(test("^v[0-9]+\\.[0-9]+\\.[0-9]+$")) ]
      | sort_by(ltrimstr("v") | split(".") | map(tonumber))
      | last // error("no v\($prefix)x release found")'
