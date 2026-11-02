# E6: the chart's Ingress with rewritePath=false, the recommended setup. The
# controller passes the prefix on with no annotations, and the app and its
# probes serve under it (#30, #38, #44).
scenario() {
  install hello "$NAMESPACE" --set ingress.enabled=true --set ingress.className="$INGRESS_CLASS" \
    --set ingress.host=hello.e2e.test --set pathPrefix=/app/hello --set rewritePath=false
  wait_ready hello "$NAMESPACE" 2
  local annotations
  annotations=$(own_annotations "$NAMESPACE" ingress hello-kubernetes-hello)
  [[ -z "$annotations" ]] || die "the Ingress has annotations: $annotations"
  info "the Ingress has no annotations"
  check_routed hello "$INGRESS_URL" hello.e2e.test /app/hello "Hello world!"
  no_probe_failures "$NAMESPACE"
}
