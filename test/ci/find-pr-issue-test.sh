#!/usr/bin/env bash
# Tests .github/scripts/find-pr-issue.sh against a stand-in gh, which returns
# prepared answers. No network or GitHub access is needed.
#
# Usage: test/ci/find-pr-issue-test.sh
#
# Each case prints PASS or FAIL. The script exits 1 if any case fails.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolver="$here/../../.github/scripts/find-pr-issue.sh"
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
failures=0

# The stand-in gh. FAKE_LINKED lists the linked issues as repo#number, and
# FAKE_ISSUES gives each number's state in this repo: open, closed or pr.
cat >"$stub/gh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1 $2" == "api graphql" ]]; then
  nodes=$(for link in $FAKE_LINKED; do
    printf '{"number":%s,"repository":{"nameWithOwner":"%s"}}\n' "${link#*#}" "${link%#*}"
  done | jq -s -c .)
  echo "{\"data\":{\"repository\":{\"pullRequest\":{\"closingIssuesReferences\":{\"nodes\":${nodes:-[]}}}}}}"
  exit 0
fi
if [[ "$1" == api && "$2" == repos/*/issues/* ]]; then
  n="${2##*/}"
  for entry in $FAKE_ISSUES; do
    if [[ "${entry%%=*}" == "$n" ]]; then
      case "${entry#*=}" in
        open) echo '{"state":"open"}' ;;
        closed) echo '{"state":"closed"}' ;;
        pr) echo '{"state":"open","pull_request":{}}' ;;
      esac
      exit 0
    fi
  done
  echo '{"message":"Not Found"}' >&2
  exit 1
fi
echo "unexpected gh call: $*" >&2
exit 2
EOF
chmod +x "$stub/gh"

# check NAME HEAD_REF LINKED ISSUES WANT_STATUS WANT_OUTPUT
check() {
  local name="$1" head_ref="$2" linked="$3" issues="$4" want_status="$5" want_output="$6" output status
  set +e
  output=$(PATH="$stub:$PATH" GH_REPO=owner/repo FAKE_LINKED="$linked" FAKE_ISSUES="$issues" \
    "$resolver" 100 "$head_ref" 2>/dev/null)
  status=$?
  set -e
  if [[ "$status" == "$want_status" && "$output" == "$want_output" ]]; then
    echo "PASS $name"
  else
    echo "FAIL $name: got status $status, output '$output'; want $want_status, '$want_output'"
    failures=$((failures + 1))
  fi
}

check "branch issue is open" fix/59-thing "" "59=open" 0 59
check "branch issue, also linked" fix/59-thing "owner/repo#59" "59=open" 0 59
check "closed branch issue, open issue linked" fix/56-thing "owner/repo#80" "56=closed 80=open" 0 80
check "branch number is a PR, open issue linked" fix/58-thing "owner/repo#80" "58=pr 80=open" 0 80
check "no number in branch, open issue linked" patch-1 "owner/repo#80" "80=open" 0 80
check "linked issue in another repo is ignored" patch-1 "other/repo#80" "80=open" 1 ""
check "another repo's link doesn't shadow this repo's" fix/59-thing "other/repo#80" "59=open 80=open" 0 59
check "no issue at all" patch-1 "" "" 1 ""
check "only closed issues" fix/56-thing "owner/repo#57" "56=closed 57=closed" 1 ""
check "branch number not found" fix/999-thing "" "" 1 ""
check "two different open issues" fix/59-thing "owner/repo#80" "59=open 80=open" 3 ""
check "two different linked open issues" patch-1 "owner/repo#80 owner/repo#81" "80=open 81=open" 3 ""

# Both workflows use the shared resolver, and the labels workflow, which has
# write access in pull_request_target, never checks out the PR's head.
workflows="$here/../../.github/workflows"
if grep -q "find-pr-issue.sh" "$workflows/pr-issue-check.yaml" && grep -q "find-pr-issue.sh" "$workflows/pr-labels.yaml"; then
  echo "PASS both workflows use the shared resolver"
else
  echo "FAIL a PR workflow doesn't use .github/scripts/find-pr-issue.sh"
  failures=$((failures + 1))
fi
if grep -nE "pull_request\.head|head_ref|refs/pull|^ +ref:" "$workflows/pr-labels.yaml" | grep -v "HEAD_REF: \${{ github.event.pull_request.head.ref }}"; then
  echo "FAIL pr-labels.yaml may check out or run the PR's code (lines above)"
  failures=$((failures + 1))
else
  echo "PASS pr-labels.yaml checks out only the base branch"
fi

if ((failures > 0)); then
  echo "$failures case(s) failed"
  exit 1
fi
echo "All resolver cases passed"
