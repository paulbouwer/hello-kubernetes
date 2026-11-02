# E8: a LoadBalancer Service gets an address, and serves the page through it
# (#1, #14). On kind, cloud-provider-kind gives the address. On k3d, k3s's
# ServiceLB does, on port 8080, because its built-in Traefik holds port 80.
scenario() {
  local port=80 address="" html
  [[ "$CLUSTER_TYPE" == k3d ]] && port=8080
  install lb "$NAMESPACE" --set service.type=LoadBalancer --set service.port="$port"
  wait_ready lb "$NAMESPACE" 2
  for _ in $(seq 1 45); do
    address=$(kubectl -n "$NAMESPACE" get service hello-kubernetes-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    [[ -n "$address" ]] && break
    sleep 2
  done
  [[ -n "$address" ]] || die "the Service got no EXTERNAL-IP within 90 seconds"
  info "EXTERNAL-IP: $address"
  html=$(routed "http://$address:$port" lb.e2e.test /)
  contains "$html" "Hello world!" "the page, through the load balancer on port $port"
}
