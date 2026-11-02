# E17: the chart's HTTPRoute with rewritePath=false. The Gateway accepts it,
# passes the prefix on, and the app and its probes serve under it.
scenario() {
  install hello "$NAMESPACE" --set httpRoute.enabled=true --set "httpRoute.parentRefs[0].name=$GATEWAY_NAME" \
    --set "httpRoute.parentRefs[0].namespace=$GATEWAY_NAMESPACE" --set pathPrefix=/app/hello --set rewritePath=false
  wait_ready hello "$NAMESPACE" 2
  local accepted filters
  for _ in $(seq 1 30); do
    accepted=$(kubectl -n "$NAMESPACE" get httproute hello-kubernetes-hello \
      -o jsonpath='{.status.parents[0].conditions[?(@.type=="Accepted")].status}')
    [[ "$accepted" == True ]] && break
    sleep 2
  done
  [[ "$accepted" == True ]] || die "the HTTPRoute is not Accepted"
  info "the HTTPRoute is Accepted by $GATEWAY_NAME"
  filters=$(kubectl -n "$NAMESPACE" get httproute hello-kubernetes-hello -o jsonpath='{.spec.rules[0].filters}')
  [[ -z "$filters" ]] || die "the HTTPRoute has filters: $filters"
  check_routed hello "$GATEWAY_URL" e2e.test /app/hello "Hello world!"
  no_probe_failures "$NAMESPACE"
}
