# Helpers for the e2e scenarios. Sourced by run.sh, which sets KUBECONFIG,
# CLUSTER_TYPE, CHART, IMAGE_REPOSITORY and IMAGE_TAG.

# Stops the scenario with a failure message.
die() {
  echo "    FAIL: $*" >&2
  exit 1
}

info() {
  echo "    $*"
}

# Installs the chart with the image under test.
# install RELEASE NAMESPACE [helm args...]
install() {
  local release="$1" namespace="$2"
  shift 2
  helm upgrade --install "$release" "$CHART" -n "$namespace" --create-namespace \
    --set deployment.container.image.repository="$IMAGE_REPOSITORY" \
    --set deployment.container.image.tag="$IMAGE_TAG" \
    --set deployment.container.image.pullPolicy=Never \
    --set service.type=ClusterIP \
    --wait --timeout "${INSTALL_TIMEOUT:-120s}" "$@" >/dev/null
}

# Prints the deployment name for a release.
deployment_name() {
  echo "hello-kubernetes-$1"
}

# Fails unless the deployment has all its replicas ready.
# wait_ready RELEASE NAMESPACE REPLICAS
wait_ready() {
  local deployment
  deployment=$(deployment_name "$1")
  kubectl -n "$2" rollout status "deployment/$deployment" --timeout=120s >/dev/null ||
    die "deployment/$deployment did not become ready"
  local ready
  ready=$(kubectl -n "$2" get "deployment/$deployment" -o jsonpath='{.status.readyReplicas}')
  [[ "$ready" == "$3" ]] || die "deployment/$deployment has $ready of $3 replicas ready"
  info "deployment/$deployment: $ready/$3 ready"
}

# Prints the page from the release's service, through a port-forward.
# page RELEASE NAMESPACE [PATH]
page() {
  local service log pid port body
  service=$(deployment_name "$1")
  log=$(mktemp)
  kubectl -n "$2" port-forward "svc/$service" 0:80 >"$log" 2>&1 &
  pid=$!
  for _ in $(seq 1 40); do
    port=$(sed -nE 's/^Forwarding from 127\.0\.0\.1:([0-9]+) .*/\1/p' "$log" | head -n1)
    [[ -n "$port" ]] && break
    sleep 0.25
  done
  if [[ -z "$port" ]]; then
    kill "$pid" 2>/dev/null
    cat "$log" >&2
    rm -f "$log"
    die "port-forward to svc/$service did not start"
  fi
  body=$(curl -fsS "http://127.0.0.1:$port${3:-/}") || {
    kill "$pid" 2>/dev/null
    rm -f "$log"
    die "GET ${3:-/} through svc/$service failed"
  }
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  rm -f "$log"
  printf '%s\n' "$body"
}

# Fails unless TEXT contains NEEDLE (a fixed string).
# contains TEXT NEEDLE DESCRIPTION
contains() {
  grep -qF -- "$2" <<<"$1" || die "$3: page does not contain '$2'"
  info "page contains $3"
}

# Fails if TEXT contains NEEDLE (a fixed string).
# not_contains TEXT NEEDLE DESCRIPTION
not_contains() {
  if grep -qF -- "$2" <<<"$1"; then
    die "$3: page contains '$2'"
  fi
  info "page does not contain $3"
}

# Prints a value from the page's info table, for example "pod" or "node".
# page_field TEXT FIELD
page_field() {
  tr -d '\r' <<<"$1" | grep -A1 -E "<th>$2:</th>" | sed -nE 's/.*<td>(.*)<\/td>.*/\1/p' | head -n1
}

# Prints the state of a namespace, for a failed scenario.
dump_diagnostics() {
  local namespace="$1"
  echo "    ---- diagnostics for namespace $namespace ----"
  kubectl -n "$namespace" get all,events -o wide 2>&1 | sed 's/^/    /'
  kubectl -n "$namespace" describe deployments,replicasets,pods 2>&1 | sed 's/^/    /' | tail -n 80
  for pod in $(kubectl -n "$namespace" get pods -o name 2>/dev/null); do
    echo "    ---- logs for $pod ----"
    kubectl -n "$namespace" logs "$pod" --tail=20 2>&1 | sed 's/^/    /'
  done
  echo "    ---- end of diagnostics ----"
}
