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
# The cluster is created if it doesn't exist, and deleted at the end unless
# KEEP_CLUSTER=1 or it existed before the run. Its kubeconfig is kept apart from
# ~/.kube/config. Needs docker, kind or k3d, kubectl, helm and curl.
#
# A scenario that sets EXPECTED_FAILURE is reported as XFAIL when it fails. If it
# passes, it is reported as XPASS and fails the run, so the marker gets removed.

set -euo pipefail

cluster_type="${1:-}"
shift || true
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"

# Node images, pinned by digest. Both run Kubernetes 1.37.
kind_node_image="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
k3s_image="rancher/k3s:v1.37.1-k3s1@sha256:ca7f37d993d82ef0dcdcfecb2e0e2618ea541dbaffc620c8cedebe01a82acd0d"

image="${IMAGE:-hello-kubernetes:e2e}"
cluster="hk-e2e-$cluster_type"

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

export KUBECONFIG="${TMPDIR:-/tmp}/$cluster.kubeconfig"
export CLUSTER_TYPE="$cluster_type"
export CHART="$repo/deploy/helm/hello-kubernetes"
export IMAGE_REPOSITORY="${image%:*}"
export IMAGE_TAG="${image##*:}"

cluster_exists() {
  case "$cluster_type" in
    kind) kind get clusters 2>/dev/null | grep -qx "$cluster" ;;
    k3d) k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "$cluster" ;;
  esac
}

create_cluster() {
  echo "Creating $cluster_type cluster $cluster"
  case "$cluster_type" in
    kind)
      kind create cluster --name "$cluster" --image "$kind_node_image" \
        --config "$here/kind-config.yaml" --kubeconfig "$KUBECONFIG" --wait 120s
      ;;
    k3d)
      k3d cluster create "$cluster" --config "$here/k3d-config.yaml" --image "$k3s_image" --wait --timeout 180s
      ;;
  esac
}

write_kubeconfig() {
  case "$cluster_type" in
    kind) kind get kubeconfig --name "$cluster" >"$KUBECONFIG" ;;
    k3d) k3d kubeconfig get "$cluster" >"$KUBECONFIG" ;;
  esac
}

load_image() {
  echo "Loading $image into $cluster"
  case "$cluster_type" in
    kind) kind load docker-image "$image" --name "$cluster" >/dev/null ;;
    k3d) k3d image import "$image" --cluster "$cluster" >/dev/null ;;
  esac
}

delete_cluster() {
  echo "Deleting $cluster_type cluster $cluster"
  case "$cluster_type" in
    kind) kind delete cluster --name "$cluster" >/dev/null 2>&1 || true ;;
    k3d) k3d cluster delete "$cluster" >/dev/null 2>&1 || true ;;
  esac
  rm -f "$KUBECONFIG"
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
load_image

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
problems=()
for file in "${scenarios[@]}"; do
  name=$(basename "$file" .sh)
  namespace="hk-${name%%-*}"
  echo "== $name ($cluster_type)"
  expected=$(sed -nE 's/^EXPECTED_FAILURE="(.*)"$/\1/p' "$file")
  set +e
  (
    set -euo pipefail
    NAMESPACE="$namespace"
    # shellcheck source=lib.sh
    source "$here/lib.sh"
    # shellcheck disable=SC1090
    source "$file"
    scenario
  )
  status=$?
  set -e
  if ((status == 0)) && [[ -z "$expected" ]]; then
    echo "PASS $name"
    pass=$((pass + 1))
  elif ((status != 0)) && [[ -n "$expected" ]]; then
    echo "XFAIL $name: expected to fail: $expected"
    xfail=$((xfail + 1))
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
echo "$cluster_type: $pass passed, $xfail expected failures, ${#problems[@]} problems"
if ((${#problems[@]} > 0)); then
  echo "Problems: ${problems[*]}"
  exit 1
fi
if [[ "$created" == true && "${KEEP_CLUSTER:-0}" == 1 ]]; then
  echo "Kept cluster $cluster. KUBECONFIG=$KUBECONFIG. Delete it with make e2e-clean."
fi
