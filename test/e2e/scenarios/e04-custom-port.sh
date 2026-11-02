# E4: a custom container port. The probes follow it, and the service serves
# the page through it (#34).
scenario() {
  install custom-port "$NAMESPACE" --set deployment.container.port=9090
  wait_ready custom-port "$NAMESPACE" 2
  local html
  html=$(page custom-port "$NAMESPACE")
  contains "$html" "Hello world!" "the default message, served on port 9090"
}
