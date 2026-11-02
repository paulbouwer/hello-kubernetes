# E2: the architecture on the page matches the kubernetes.io/arch label of the
# node that runs the pod (#40).
scenario() {
  install hello-world "$NAMESPACE"
  wait_ready hello-world "$NAMESPACE" 2
  local html pod node arch
  html=$(page hello-world "$NAMESPACE")
  pod=$(page_field "$html" pod)
  node=$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.spec.nodeName}')
  arch=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.kubernetes\.io/arch}')
  contains "$html" "(linux/$arch)" "the architecture of node $node"
}
