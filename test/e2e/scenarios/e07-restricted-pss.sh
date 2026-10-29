# E7: the chart installs in a namespace that enforces the restricted Pod
# Security Standard, with no warnings, and the app runs as user 1000 (#35).
EXPECTED_FAILURE="4.1: the chart has no securityContext, so restricted Pod Security rejects the pods"
scenario() {
  kubectl create namespace "$NAMESPACE" >/dev/null
  kubectl label namespace "$NAMESPACE" pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/warn=restricted >/dev/null
  local output pod uid
  output=$(INSTALL_TIMEOUT=60s install hello-world "$NAMESPACE" 2>&1) || {
    echo "$output" | sed 's/^/    /'
    die "install failed in a restricted namespace"
  }
  if grep -q "would violate PodSecurity" <<<"$output"; then
    echo "$output" | sed 's/^/    /'
    die "install printed Pod Security warnings"
  fi
  wait_ready hello-world "$NAMESPACE" 2
  pod=$(kubectl -n "$NAMESPACE" get pods -o jsonpath='{.items[0].metadata.name}')
  uid=$(kubectl -n "$NAMESPACE" exec "$pod" -- id -u)
  [[ "$uid" == 1000 ]] || die "the app runs as user $uid, not 1000"
  info "the app runs as user 1000"
}
