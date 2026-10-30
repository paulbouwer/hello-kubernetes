# E10: the release file, hello-kubernetes.yaml, works with kubectl alone (#29).
# It is rendered here the same way as in the publish workflow: the chart's
# defaults, with the release name demo. Only the image is changed, to the one
# under test.
scenario() {
  local file html
  file=$(mktemp)
  helm template demo "$CHART" |
    sed "s|image: \"paulbouwer/hello-kubernetes:[^\"]*\"|image: \"$IMAGE_REPOSITORY:$IMAGE_TAG\"|" >"$file"
  grep -q "image: \"$IMAGE_REPOSITORY:$IMAGE_TAG\"" "$file" || die "the image in the rendered file was not replaced"
  kubectl create namespace "$NAMESPACE" >/dev/null
  kubectl -n "$NAMESPACE" apply -f "$file" >/dev/null
  wait_ready demo "$NAMESPACE" 2
  html=$(page demo "$NAMESPACE")
  contains "$html" "Hello world!" "the default message"
  contains "$html" "hello-kubernetes-demo-" "a pod named hello-kubernetes-demo"
  kubectl -n "$NAMESPACE" delete -f "$file" --wait >/dev/null
  [[ -z "$(kubectl -n "$NAMESPACE" get all -l app.kubernetes.io/instance=demo -o name 2>/dev/null | grep -v '^pod/')" ]] ||
    die "kubectl delete -f left resources behind"
  info "kubectl delete -f removed the Service and the Deployment"
  rm -f "$file"
}
