# E5: two releases, each behind the chart's Ingress under its own prefix, with
# rewritePath=true. The controller strips the prefix: the NGINX Ingress
# Controller with its nginx.org/rewrites annotation on kind, and Traefik with
# a stripPrefix Middleware on k3d (#31). Each release has its own host,
# because the NGINX Ingress Controller allows one Ingress per host.
scenario() {
  rewrite_args hello-world "$NAMESPACE" /app/hello-world
  install hello-world "$NAMESPACE" --set ingress.enabled=true --set ingress.className="$INGRESS_CLASS" \
    --set ingress.host=hello-world.e2e.test --set pathPrefix=/app/hello-world "${REWRITE_ARGS[@]}"
  rewrite_args custom-message "$NAMESPACE" /app/custom
  install custom-message "$NAMESPACE" --set ingress.enabled=true --set ingress.className="$INGRESS_CLASS" \
    --set ingress.host=custom.e2e.test --set pathPrefix=/app/custom --set-string message="A custom message" \
    "${REWRITE_ARGS[@]}"
  wait_ready hello-world "$NAMESPACE" 2
  wait_ready custom-message "$NAMESPACE" 2
  check_routed hello-world "$INGRESS_URL" hello-world.e2e.test /app/hello-world "Hello world!"
  check_routed custom-message "$INGRESS_URL" custom.e2e.test /app/custom "A custom message"
}
