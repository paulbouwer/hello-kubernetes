# E16: two releases, each behind the chart's HTTPRoute under its own prefix,
# with rewritePath=true. The route strips the prefix with the standard
# URLRewrite filter, with no settings for the Gateway implementation: NGINX
# Gateway Fabric on kind, and Traefik on k3d.
scenario() {
  local gateway=(--set httpRoute.enabled=true --set "httpRoute.parentRefs[0].name=$GATEWAY_NAME"
    --set "httpRoute.parentRefs[0].namespace=$GATEWAY_NAMESPACE")
  install hello-world "$NAMESPACE" "${gateway[@]}" --set pathPrefix=/app/hello-world
  install custom-message "$NAMESPACE" "${gateway[@]}" --set pathPrefix=/app/custom \
    --set-string message="A custom message"
  wait_ready hello-world "$NAMESPACE" 2
  wait_ready custom-message "$NAMESPACE" 2
  local filter annotations
  filter=$(kubectl -n "$NAMESPACE" get httproute hello-kubernetes-hello-world \
    -o jsonpath='{.spec.rules[0].filters[0].type} {.spec.rules[0].filters[0].urlRewrite.path.type}')
  [[ "$filter" == "URLRewrite ReplacePrefixMatch" ]] || die "the HTTPRoute's filter is '$filter'"
  info "the HTTPRoute has a URLRewrite filter with ReplacePrefixMatch"
  annotations=$(own_annotations "$NAMESPACE" httproute hello-kubernetes-hello-world)
  [[ -z "$annotations" ]] || die "the HTTPRoute has annotations: $annotations"
  info "the HTTPRoute has no annotations"
  check_routed hello-world "$GATEWAY_URL" e2e.test /app/hello-world "Hello world!"
  check_routed custom-message "$GATEWAY_URL" e2e.test /app/custom "A custom message"
}
