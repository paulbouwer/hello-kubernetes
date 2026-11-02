# E18: the old ingress.configured, ingress.pathPrefix and ingress.rewritePath
# values still work, with a hand-written Ingress, as before 1.11. The chart
# creates no Ingress of its own.
scenario() {
  install old "$NAMESPACE" --set ingress.configured=true --set ingress.pathPrefix=app/old \
    --set ingress.rewritePath=false
  wait_ready old "$NAMESPACE" 2
  [[ -z "$(kubectl -n "$NAMESPACE" get ingress -o name)" ]] || die "the chart created an Ingress"
  info "the chart created no Ingress"
  kubectl apply -f - >/dev/null <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hand-written
  namespace: $NAMESPACE
spec:
  ingressClassName: $INGRESS_CLASS
  rules:
    - host: old.e2e.test
      http:
        paths:
          - path: /app/old
            pathType: Prefix
            backend:
              service:
                name: hello-kubernetes-old
                port:
                  number: 80
YAML
  check_routed old "$INGRESS_URL" old.e2e.test /app/old "Hello world!"
  no_probe_failures "$NAMESPACE"
}
