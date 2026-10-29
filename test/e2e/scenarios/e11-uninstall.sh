# E11: uninstall and delete the namespace, and nothing with the chart's
# labels is left (#28).
scenario() {
  install uninstall-check "$NAMESPACE"
  wait_ready uninstall-check "$NAMESPACE" 2
  helm uninstall uninstall-check -n "$NAMESPACE" --wait >/dev/null || die "helm uninstall failed"
  kubectl delete namespace "$NAMESPACE" --wait --timeout=120s >/dev/null || die "the namespace was not deleted"
  local left
  left=$(kubectl get deployments,replicasets,pods,services,serviceaccounts -A \
    -l app.kubernetes.io/instance=uninstall-check -o name 2>/dev/null)
  [[ -z "$left" ]] || die "resources left after uninstall: $left"
  info "no Deployment, ReplicaSet, Pod, Service or ServiceAccount left"
}
