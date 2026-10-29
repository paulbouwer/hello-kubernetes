# E1: default install. Two ready replicas, and a page with the default message,
# the namespace, a real pod and node, and the image under test.
scenario() {
  install hello-world "$NAMESPACE"
  wait_ready hello-world "$NAMESPACE" 2
  local html pod node
  html=$(page hello-world "$NAMESPACE")
  contains "$html" "Hello world!" "the default message"
  contains "$html" "$NAMESPACE" "the namespace"
  pod=$(page_field "$html" pod)
  kubectl -n "$NAMESPACE" get pod "$pod" >/dev/null 2>&1 || die "pod '$pod' on the page is not a pod in $NAMESPACE"
  info "pod $pod exists"
  node=$(kubectl -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.spec.nodeName}')
  contains "$html" "$node (" "the pod's node, $node"
  contains "$html" "$IMAGE_REPOSITORY:$IMAGE_TAG" "the image under test"
}
