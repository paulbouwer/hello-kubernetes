# E9: four pods spread across the cluster's nodes, and requests through the
# Ingress reach more than one of them, which is the demo's main point.
scenario() {
  install spread "$NAMESPACE" --set deployment.replicaCount=4 --set ingress.enabled=true \
    --set ingress.className="$INGRESS_CLASS" --set ingress.host=spread.e2e.test \
    --set pathPrefix=/app/spread --set rewritePath=false
  wait_ready spread "$NAMESPACE" 4
  local nodes pods html
  nodes=$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance=spread \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
  ((nodes >= 2)) || die "the 4 pods are on $nodes node"
  info "the 4 pods are on $nodes nodes"
  pods=$(for _ in $(seq 1 20); do
    html=$(routed "$INGRESS_URL" spread.e2e.test /app/spread/)
    page_field "$html" pod
  done | sort -u | wc -l)
  ((pods >= 2)) || die "20 requests reached $pods pod"
  info "20 requests reached $pods pods"
}
