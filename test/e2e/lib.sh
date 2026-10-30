# Helpers for the e2e scenarios. Sourced by run.sh, which sets KUBECONFIG,
# CLUSTER_TYPE, CHART, IMAGE_REPOSITORY and IMAGE_TAG, and, from cluster.sh,
# INGRESS_CLASS, INGRESS_URL, GATEWAY_NAME, GATEWAY_NAMESPACE and GATEWAY_URL.

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

# Prints a page through an Ingress or a Gateway, with a Host header. Retries
# for up to 60 seconds while the route reaches the proxy.
# routed BASE_URL HOST PATH
routed() {
  local body
  for _ in $(seq 1 30); do
    if body=$(curl -fsS -H "Host: $2" "$1$3" 2>/dev/null); then
      printf '%s\n' "$body"
      return 0
    fi
    sleep 2
  done
  curl -sS -o /dev/null -w "    last response: %{http_code}\n" -H "Host: $2" "$1$3" >&2 || true
  die "GET $3 with Host $2 through $1 failed"
}

# Fails unless the release serves its page under PREFIX through BASE_URL, with
# TEXT on it, and links its stylesheet and image under PREFIX, both loading.
# check_routed RELEASE BASE_URL HOST PREFIX TEXT
check_routed() {
  local release="$1" base="$2" host="$3" prefix="$4" text="$5" html asset code
  html=$(routed "$base" "$host" "$prefix/")
  contains "$html" "$text" "\"$text\" at $prefix/"
  contains "$html" "hello-kubernetes-$release-" "a pod of $release"
  for asset in css/main.css images/kubernetes.png; do
    contains "$html" "$prefix/$asset" "the link to $prefix/$asset"
    code=$(curl -sS -o /dev/null -w '%{http_code}' -H "Host: $host" "$base$prefix/$asset")
    [[ "$code" == 200 ]] || die "GET $prefix/$asset returned $code"
    info "$prefix/$asset: 200"
  done
}

# Fails if a probe got an HTTP error in the namespace, such as a 404 from a
# probe path outside the prefix. "connection refused" while the app starts is
# not an HTTP error, so it doesn't count.
# no_probe_failures NAMESPACE
no_probe_failures() {
  local failures
  failures=$(kubectl -n "$1" get events --field-selector reason=Unhealthy \
    -o jsonpath='{range .items[*]}{.message}{"\n"}{end}' 2>/dev/null | grep -F "statuscode" || true)
  [[ -z "$failures" ]] || die "probes failed in $1: $(head -n1 <<<"$failures")"
  info "no probe got an HTTP error"
}

# Prints the annotations of a resource, except the ones Helm adds.
# own_annotations NAMESPACE KIND NAME
own_annotations() {
  kubectl -n "$1" get "$2" "$3" -o json | jq -r '.metadata.annotations // {} | with_entries(select(.key | startswith("meta.helm.sh/") | not)) | select(length > 0) | tostring'
}

# Sets REWRITE_ARGS to the helm arguments that make the cluster's Ingress
# controller strip PREFIX: the NGINX Ingress Controller's nginx.org/rewrites
# annotation on kind, and a Traefik stripPrefix Middleware on k3d.
# rewrite_args RELEASE NAMESPACE PREFIX
rewrite_args() {
  local release="$1" namespace="$2" prefix="$3"
  case "$CLUSTER_TYPE" in
    kind)
      REWRITE_ARGS=(--set-string "ingress.annotations.nginx\\.org/rewrites=serviceName=hello-kubernetes-$release rewrite=/")
      ;;
    k3d)
      kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
      kubectl apply -f - >/dev/null <<EOF
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-$release
  namespace: $namespace
spec:
  stripPrefix:
    prefixes:
      - $prefix
EOF
      REWRITE_ARGS=(--set-string "ingress.annotations.traefik\\.ingress\\.kubernetes\\.io/router\\.middlewares=$namespace-strip-$release@kubernetescrd")
      ;;
  esac
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
