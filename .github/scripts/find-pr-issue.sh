#!/usr/bin/env bash
# Finds the one issue that a PR belongs to. Used by pr-issue-check.yaml and
# pr-labels.yaml, so that both always pick the same issue.
#
# Usage: .github/scripts/find-pr-issue.sh PR HEAD_REF
#
# Environment: GH_REPO (owner/name), and GH_TOKEN for gh.
#
# The candidates are the issue number in the branch name ({type}/{issue}-...),
# and the issues linked to the PR in its Development section. Only open issues
# in GH_REPO count: a closed issue, a PR, or an issue in another repo doesn't.
#
# Output and exit status:
#   0  exactly one issue: prints its number
#   1  no issue
#   3  more than one different issue. A PR belongs to exactly one issue.
# Explanations go to stderr.
#
# pr-labels.yaml runs this with write access, from the base branch's copy of
# the repo, never from the PR's code.

set -euo pipefail

pr="${1:?usage: $0 PR HEAD_REF}"
head_ref="${2:?usage: $0 PR HEAD_REF}"
repo="${GH_REPO:?GH_REPO must be set (owner/name)}"

candidates=()
if [[ "$head_ref" =~ ^[a-z]+/([0-9]+)- ]]; then
  candidates+=("${BASH_REMATCH[1]}")
fi

linked=$(gh api graphql \
  -f query='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){closingIssuesReferences(first:20){nodes{number repository{nameWithOwner}}}}}}' \
  -f o="${repo%/*}" -f r="${repo#*/}" -F n="$pr")
while read -r n; do
  [[ -n "$n" ]] && candidates+=("$n")
done < <(jq -r --arg repo "$repo" \
  '.data.repository.pullRequest.closingIssuesReferences.nodes[] | select(.repository.nameWithOwner == $repo) | .number' <<<"$linked" | sort -n)

valid=()
for n in $(printf '%s\n' "${candidates[@]}" | awk 'NF && !seen[$0]++'); do
  state=$(gh api "repos/$repo/issues/$n" 2>/dev/null | jq -r 'if .pull_request then "a PR" else .state end' || echo "not found")
  if [[ "$state" == open ]]; then
    valid+=("$n")
  else
    echo "#$n isn't an open issue in $repo ($state)." >&2
  fi
done

case "${#valid[@]}" in
  1)
    echo "${valid[0]}"
    ;;
  0)
    exit 1
    ;;
  *)
    echo "This PR points at more than one open issue: $(printf '#%s ' "${valid[@]}")" >&2
    exit 3
    ;;
esac
