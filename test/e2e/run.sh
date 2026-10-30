#!/usr/bin/env bash
# End-to-end tests: install the chart on a local kind or k3d cluster, with the
# image built from the working tree, and check the result.
#
# Usage: test/e2e/run.sh <kind|k3d> [scenario...]
#   scenario: a file name prefix in test/e2e/scenarios, e.g. e01 or e07-restricted
#
# Environment:
#   IMAGE         the local image to test (default hello-kubernetes:e2e)
#   KEEP_CLUSTER  1 keeps the cluster, and a failed scenario's namespace, at the end
#
# The cluster is created if it doesn't exist, with its Ingress controller and
# Gateway (cluster.sh), and deleted at the end unless KEEP_CLUSTER=1 or it
# existed before the run. Its kubeconfig is kept apart from ~/.kube/config.
# Needs docker, kind or k3d, kubectl, helm and curl.
#
# A scenario that sets CLUSTERS, for example CLUSTERS="k3d", runs only on those
# cluster types, and is reported as SKIP on the others.
#
# A scenario that sets EXPECTED_FAILURE must also set EXPECTED_ERROR, an
# extended regular expression for the error it expects. It is reported as XFAIL
# only when it fails and its output matches EXPECTED_ERROR. Any other failure is
# a FAIL. If it passes, it is reported as XPASS and fails the run, so the marker
# gets removed.

set -euo pipefail

cluster_type="${1:-}"
shift || true
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

image="${IMAGE:-hello-kubernetes:e2e}"

case "$cluster_type" in
  kind | k3d) ;;
  *)
    echo "usage: $0 <kind|k3d> [scenario...]" >&2
    exit 2
    ;;
esac

docker image inspect "$image" >/dev/null 2>&1 || {
  echo "image $image not found. Build it first, for example with make e2e-$cluster_type." >&2
  exit 2
}

export KUBECONFIG="${TMPDIR:-/tmp}/hk-e2e-$cluster_type.kubeconfig"
export CLUSTER_TYPE="$cluster_type"
export CHART="$repo/deploy/helm/hello-kubernetes"
export IMAGE_REPOSITORY="${image%:*}"
export IMAGE_TAG="${image##*:}"
# shellcheck source=cluster.sh
source "$here/cluster.sh"

# Runs on exit. A failed deletion is reported and fails the run.
delete_cluster() {
  local status=$? output
  echo "Deleting $cluster_type cluster $cluster"
  if ! output=$(delete_cluster_now); then
    echo "$output" >&2
    echo "FAIL: could not delete $cluster_type cluster $cluster. Delete it with make e2e-clean." >&2
    exit 1
  fi
  rm -f "$KUBECONFIG"
  exit "$status"
}

created=false
if cluster_exists; then
  echo "Reusing $cluster_type cluster $cluster"
else
  created=true
  if [[ "${KEEP_CLUSTER:-0}" != 1 ]]; then
    trap delete_cluster EXIT
  fi
  create_cluster
fi
write_kubeconfig
kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null
load_image "$image"
setup_routing

# Select the scenarios.
scenarios=()
for file in "$here"/scenarios/e*.sh; do
  name=$(basename "$file" .sh)
  if (($# == 0)); then
    scenarios+=("$file")
  else
    for wanted in "$@"; do
      [[ "$name" == "$wanted"* ]] && scenarios+=("$file") && break
    done
  fi
done
((${#scenarios[@]} > 0)) || {
  echo "no scenarios match: $*" >&2
  exit 2
}

pass=0
xfail=0
skipped=0
problems=()
for file in "${scenarios[@]}"; do
  name=$(basename "$file" .sh)
  namespace="hk-${name%%-*}"
  clusters=$(sed -nE 's/^CLUSTERS="(.*)"$/\1/p' "$file")
  if [[ -n "$clusters" && " $clusters " != *" $cluster_type "* ]]; then
    echo "SKIP $name: runs only on $clusters"
    skipped=$((skipped + 1))
    continue
  fi
  echo "== $name ($cluster_type)"
  expected=$(sed -nE 's/^EXPECTED_FAILURE="(.*)"$/\1/p' "$file")
  expected_error=$(sed -nE "s/^EXPECTED_ERROR='(.*)'$/\\1/p" "$file")
  output=$(mktemp)
  set +e
  (
    set -euo pipefail
    NAMESPACE="$namespace"
    # shellcheck source=lib.sh
    source "$here/lib.sh"
    # shellcheck disable=SC1090
    source "$file"
    scenario
  ) 2>&1 | tee "$output"
  status=${PIPESTATUS[0]}
  set -e
  matched=false
  if [[ -n "$expected_error" ]] && grep -qE -- "$expected_error" "$output"; then
    matched=true
  fi
  rm -f "$output"
  if ((status == 0)) && [[ -z "$expected" ]]; then
    echo "PASS $name"
    pass=$((pass + 1))
  elif ((status != 0)) && [[ -n "$expected" && "$matched" == true ]]; then
    echo "XFAIL $name: expected to fail: $expected"
    xfail=$((xfail + 1))
  elif ((status != 0)) && [[ -n "$expected" ]]; then
    (source "$here/lib.sh" && dump_diagnostics "$namespace")
    echo "FAIL $name: failed, but not with the expected error /${expected_error:-EXPECTED_ERROR is not set}/"
    problems+=("$name")
  elif ((status == 0)); then
    echo "XPASS $name: passed, but is marked as expected to fail ($expected). Remove EXPECTED_FAILURE."
    problems+=("$name (XPASS)")
  else
    (source "$here/lib.sh" && dump_diagnostics "$namespace")
    echo "FAIL $name"
    problems+=("$name")
  fi
  if [[ "${KEEP_CLUSTER:-0}" == 1 && $status -ne 0 ]]; then
    echo "Kept namespace $namespace for debugging"
  else
    kubectl delete namespace "$namespace" --ignore-not-found --wait=false >/dev/null
  fi
done

echo
echo "$cluster_type: $pass passed, $xfail expected failures, $skipped skipped, ${#problems[@]} problems"
if ((${#problems[@]} > 0)); then
  echo "Problems: ${problems[*]}"
  exit 1
fi
if [[ "$created" == true && "${KEEP_CLUSTER:-0}" == 1 ]]; then
  echo "Kept cluster $cluster. KUBECONFIG=$KUBECONFIG. Delete it with make e2e-clean."
fi
