#!/usr/bin/env bash
# Keep the repo's labels in step with the list below.
#
# Usage:
#   .github/labels.sh           Create, update and remove labels until the repo matches the list.
#   .github/labels.sh --check   Change nothing. Print each difference, and exit 1 if there is one.
#
# Works on the repo that gh resolves from the current directory, or on GH_REPO.
# Needs gh (signed in, with write access to the repo) and jq.
#
# This list is the source of truth for label names, colours and descriptions.
# What each label is for is in .project/roadmap/1.x/operations.md.
# Only the repo owner adds or changes labels: change this list in a PR, then run the script.

set -euo pipefail

# name|colour|description
LABELS=(
  # Type
  "bug|d73a4a|Something isn't working"
  "enhancement|a2eeef|New feature or improvement"
  "documentation|0075ca|Documentation only"
  "security|b60205|Security fix or scanner finding; needs human review"
  "dependencies|0366d6|Dependency update"
  "breaking-change|e11d21|Needs a major version bump"
  # Area
  "area:app|c5def5|Node app (src/app)"
  "area:image|c5def5|Container image"
  "area:deploy|c5def5|Helm chart, release YAML, Kustomize"
  "area:ci|c5def5|Workflows, Makefile, tests"
  "area:site|c5def5|Website, llms.txt"
  "area:operations|c5def5|Repo maintenance and dev environment"
  # Waiting on the reporter
  "needs-info|fbca04|Waiting on the reporter"
  # Agent trigger and filter
  "agent|5319e7|Approved for an agent to implement"
  "not-aligned|e4e669|Not aligned with the project's goals (see GOAL.md)"
)

# Removed in favour of close reasons and Discussions, and invalid, renamed to
# not-aligned. Only these are ever deleted.
REMOVE=(
  "duplicate"
  "wontfix"
  "question"
  "good first issue"
  "help wanted"
  "invalid"
)

mode=apply
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

# Current labels as name<TAB>colour<TAB>description, one per line.
current=$(gh label list --limit 200 --json name,color,description \
  --jq '.[] | [.name, (.color | ascii_downcase), .description] | @tsv')

lookup() {
  awk -F'\t' -v n="$1" '$1 == n { print; found = 1 } END { exit !found }' <<<"$current"
}

diffs=0
changes=0
wanted=()

for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color description <<<"$entry"
  wanted+=("$name")
  if ! row=$(lookup "$name"); then
    status=missing
  else
    IFS=$'\t' read -r _ have_color have_description <<<"$row"
    if [[ "$have_color" == "${color,,}" && "$have_description" == "$description" ]]; then
      continue
    fi
    status=different
  fi
  if [[ $mode == check ]]; then
    echo "$status: $name"
    diffs=$((diffs + 1))
  else
    gh label create "$name" --color "$color" --description "$description" --force >/dev/null
    [[ $status == missing ]] && echo "created: $name" || echo "updated: $name"
    changes=$((changes + 1))
  fi
done

for name in "${REMOVE[@]}"; do
  lookup "$name" >/dev/null || continue
  if [[ $mode == check ]]; then
    echo "extra: $name"
    diffs=$((diffs + 1))
  else
    gh label delete "$name" --yes >/dev/null
    echo "deleted: $name"
    changes=$((changes + 1))
  fi
done

# Labels in neither list are reported, never deleted.
if [[ $mode == check ]]; then
  while IFS=$'\t' read -r name _; do
    [[ -z "$name" ]] && continue
    printf '%s\n' "${wanted[@]}" "${REMOVE[@]}" | grep -qxF -- "$name" && continue
    echo "extra: $name"
    diffs=$((diffs + 1))
  done <<<"$current"
  if ((diffs > 0)); then
    echo "$diffs difference(s)" >&2
    exit 1
  fi
  echo "Labels match."
elif ((changes == 0)); then
  echo "No changes."
fi
