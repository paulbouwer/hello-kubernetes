# E9: four pods spread across the cluster's nodes, and requests through the
# Ingress reach more than one of them, which is the demo's main point.
scenario() {
  install spread "$NAMESPACE" --set deployment.replicaCount=4 --set ingress.enabled=true \
    --set ingress.className="$INGRESS_CLASS" --set ingress.host=spread.e2e.test \
    --set pathPrefix=/app/spread --set rewritePath=false
  wait_ready spread "$NAMESPACE" 4
  local nodes html seen count=1 deadline
  nodes=$(kubectl -n "$NAMESPACE" get pods -l app.kubernetes.io/instance=spread \
    -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort -u | wc -l)
  ((nodes >= 2)) || die "the 4 pods are on $nodes node"
  info "the 4 pods are on $nodes nodes"
  # The Ingress controller picks up new endpoints a few seconds after the pods
  # are ready, so send requests, for up to 60 seconds, until more than one pod
  # answers. A failed request still fails at once (workstream 5 review).
  html=$(routed "$INGRESS_URL" spread.e2e.test /app/spread/)
  seen=$(page_field "$html" pod)
  deadline=$((SECONDS + 60))
  while (($(sort -u <<<"$seen" | wc -l) < 2)); do
    ((SECONDS < deadline)) || die "$count requests over 60 seconds reached only one pod"
    html=$(curl -fsS -H "Host: spread.e2e.test" "$INGRESS_URL/app/spread/") || die "request $((count + 1)) through the Ingress failed"
    seen+=$'\n'$(page_field "$html" pod)
    count=$((count + 1))
    sleep 0.25
  done
  info "$count requests reached $(sort -u <<<"$seen" | wc -l) pods"
}
