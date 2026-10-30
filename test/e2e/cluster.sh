# Creates and sets up the kind and k3d clusters for the e2e tests: the cluster,
# its Ingress controller and Gateway, and the image under test. Sourced by
# run.sh. Set CLUSTER_TYPE (kind or k3d) and KUBECONFIG before sourcing.
#
# Each cluster type exposes the same things, as the variables below:
#   INGRESS_CLASS, INGRESS_URL          the Ingress class, and where it answers
#   GATEWAY_NAME, GATEWAY_NAMESPACE     the Gateway for HTTPRoutes
#   GATEWAY_URL                         where the Gateway answers
#
# kind: the F5 NGINX Ingress Controller and NGINX Gateway Fabric, each on a
# NodePort that kind maps to localhost, and cloud-provider-kind, which gives
# LoadBalancer Services an address. It runs on the host, while the cluster runs. k3d: k3s's built-in Traefik, for both
# the Ingress and the Gateway, on the port that k3d maps to its load balancer.
#
# Every version is pinned, and checked against its digest or SHA-256. To change
# one, choose a release at least 7 days old (AGENTS.md rule 8), and update the
# version and its digest together.

cluster_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cluster="hk-e2e-$CLUSTER_TYPE"

# Node images, pinned by digest. Both run Kubernetes 1.37, the newest version.
# E2E_KUBERNETES=oldest runs kind on 1.35, the oldest version the chart
# supports (E13). The node images are the ones kind 0.33.0 lists.
kind_node_image="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
if [[ "${E2E_KUBERNETES:-}" == oldest ]]; then
  kind_node_image="kindest/node:v1.35.8@sha256:07b2536e30b803ed61d1677a79df6115f798ce64c80f9e22f6ed45afd09323c0"
fi
k3s_image="rancher/k3s:v1.37.1-k3s1@sha256:ca7f37d993d82ef0dcdcfecb2e0e2618ea541dbaffc620c8cedebe01a82acd0d"

# Gateway API CRDs for kind, the version NGINX Gateway Fabric 2.8.0 is built
# against. k3s ships its own.
gateway_api_url="https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.2/standard-install.yaml"
gateway_api_sha256="faede450fa178126aba41337737b97d351ebe87d93c910237ce1e072d1ca40d9"

# The F5 NGINX Ingress Controller 5.7.0, and NGINX Gateway Fabric 2.8.0.
nic_chart="oci://ghcr.io/nginx/charts/nginx-ingress"
nic_chart_version="2.8.0"
nic_chart_digest="sha256:72707cbc1807d825a5523014f4dfca18005ddbaabd64f09135cf4347c1999da4"
nic_image_digest="sha256:cf6a49ddb69065d17aded929b04ac0fa98525950ccfb98ce4723517edf6d3050"
ngf_chart="oci://ghcr.io/nginx/charts/nginx-gateway-fabric"
ngf_chart_version="2.8.0"
ngf_chart_digest="sha256:44e3b2a475f65f02c2399b2e4c01c99c684b8b03c46a89e115f3d500ca499333"
ngf_image_tag="2.8.0@sha256:cd0a787ecdaaa140f66a64b071f9553c7d69606b22c7b786ca65ad414a25b0fe"
ngf_nginx_image_tag="2.8.0@sha256:ed85a822d773a1a780c8897054f27fc881e378f586e6f39582dc2e04a152128d"

case "$CLUSTER_TYPE" in
  kind)
    export INGRESS_CLASS=nginx INGRESS_URL=http://127.0.0.1:18080
    export GATEWAY_NAME=hk-gateway GATEWAY_NAMESPACE=hk-gateway GATEWAY_URL=http://127.0.0.1:18081
    ;;
  k3d)
    export INGRESS_CLASS=traefik INGRESS_URL=http://127.0.0.1:18082
    export GATEWAY_NAME=traefik-gateway GATEWAY_NAMESPACE=kube-system GATEWAY_URL=http://127.0.0.1:18082
    ;;
esac

cluster_exists() {
  case "$CLUSTER_TYPE" in
    kind) kind get clusters 2>/dev/null | grep -qx "$cluster" ;;
    k3d) k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "$cluster" ;;
  esac
}

create_cluster() {
  echo "Creating $CLUSTER_TYPE cluster $cluster"
  case "$CLUSTER_TYPE" in
    kind)
      kind create cluster --name "$cluster" --image "$kind_node_image" \
        --config "$cluster_dir/kind-config.yaml" --kubeconfig "$KUBECONFIG" --wait 120s
      ;;
    k3d)
      k3d cluster create "$cluster" --config "$cluster_dir/k3d-config.yaml" --image "$k3s_image" --wait --timeout 180s
      ;;
  esac
}

write_kubeconfig() {
  case "$CLUSTER_TYPE" in
    kind) kind get kubeconfig --name "$cluster" >"$KUBECONFIG" ;;
    k3d) k3d kubeconfig get "$cluster" >"$KUBECONFIG" ;;
  esac
}

# load_image IMAGE
load_image() {
  echo "Loading $1 into $cluster"
  case "$CLUSTER_TYPE" in
    kind) kind load docker-image "$1" --name "$cluster" >/dev/null ;;
    k3d) k3d image import "$1" --cluster "$cluster" >/dev/null ;;
  esac
}

delete_cluster_now() {
  case "$CLUSTER_TYPE" in
    kind) stop_cloud_provider_kind && kind delete cluster --name "$cluster" 2>&1 ;;
    k3d) k3d cluster delete "$cluster" 2>&1 ;;
  esac
}

cloud_provider_kind_pid="${TMPDIR:-/tmp}/$cluster-cloud-provider-kind.pid"

# Starts cloud-provider-kind, unless one is running already.
start_cloud_provider_kind() {
  # pgrep -x only matches names of up to 15 characters, so match the command.
  pgrep -f '(^|/)cloud-provider-kind( |$)' >/dev/null && return 0
  command -v cloud-provider-kind >/dev/null || {
    echo "cloud-provider-kind is not installed. Install it with test/ci/install-tools.sh cloud-provider-kind." >&2
    return 1
  }
  echo "Starting cloud-provider-kind"
  nohup cloud-provider-kind >"${TMPDIR:-/tmp}/$cluster-cloud-provider-kind.log" 2>&1 &
  echo $! >"$cloud_provider_kind_pid"
}

# Stops the cloud-provider-kind that start_cloud_provider_kind started.
stop_cloud_provider_kind() {
  if [[ -f "$cloud_provider_kind_pid" ]]; then
    kill "$(cat "$cloud_provider_kind_pid")" 2>/dev/null || true
    rm -f "$cloud_provider_kind_pid"
  fi
}

# Pulls a chart and checks its digest, then prints the path of the chart file.
# pull_chart REF VERSION DIGEST DIR
pull_chart() {
  local output digest
  output=$(helm pull "$1" --version "$2" --destination "$4" 2>&1) || {
    echo "$output" >&2
    return 1
  }
  digest=$(sed -n 's/^Digest: *//p' <<<"$output")
  if [[ "$digest" != "$3" ]]; then
    echo "$1 $2 has digest '$digest', not $3" >&2
    return 1
  fi
  echo "$4/${1##*/}-$2.tgz"
}

# Installs the Ingress controller and the Gateway, once. Skips what is there.
setup_routing() {
  case "$CLUSTER_TYPE" in
    kind) setup_routing_kind ;;
    k3d) setup_routing_k3d ;;
  esac
}

setup_routing_kind() {
  local work chart
  work=$(mktemp -d)
  if ! kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1; then
    echo "Installing the Gateway API CRDs"
    curl -fsSL "$gateway_api_url" -o "$work/gateway-api.yaml"
    echo "$gateway_api_sha256  $work/gateway-api.yaml" | sha256sum -c --quiet -
    kubectl apply --server-side -f "$work/gateway-api.yaml" >/dev/null
  fi
  if ! helm status nginx-ingress -n nginx-ingress >/dev/null 2>&1; then
    echo "Installing the NGINX Ingress Controller"
    chart=$(pull_chart "$nic_chart" "$nic_chart_version" "$nic_chart_digest" "$work")
    helm install nginx-ingress "$chart" -n nginx-ingress --create-namespace \
      --set controller.image.digest="$nic_image_digest" \
      --set controller.service.type=NodePort \
      --set controller.service.externalTrafficPolicy=Cluster \
      --set controller.service.httpPort.nodePort=30080 \
      --set controller.service.httpsPort.enable=false \
      --wait --timeout 300s >/dev/null
  fi
  if ! helm status ngf -n nginx-gateway >/dev/null 2>&1; then
    echo "Installing NGINX Gateway Fabric"
    chart=$(pull_chart "$ngf_chart" "$ngf_chart_version" "$ngf_chart_digest" "$work")
    helm install ngf "$chart" -n nginx-gateway --create-namespace \
      --set nginxGateway.image.tag="$ngf_image_tag" \
      --set nginx.image.tag="$ngf_nginx_image_tag" \
      --set nginx.service.type=NodePort \
      --set nginx.service.externalTrafficPolicy=Cluster \
      --set 'nginx.service.nodePorts[0].port=30081' \
      --set 'nginx.service.nodePorts[0].listenerPort=80' \
      --wait --timeout 300s >/dev/null
  fi
  rm -rf "$work"
  start_cloud_provider_kind
  kubectl apply -f "$cluster_dir/extras/gateway-kind.yaml" >/dev/null
  kubectl wait "gateway/$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" --for=condition=Programmed --timeout=180s >/dev/null
}

setup_routing_k3d() {
  # Traefik ships with only its Ingress provider on. This turns on its Gateway
  # API provider, and lets its Gateway take routes from every namespace.
  if ! kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" >/dev/null 2>&1; then
    echo "Turning on Traefik's Gateway API provider"
    kubectl apply -f "$cluster_dir/extras/traefik-gateway-provider.yaml" >/dev/null
    for _ in $(seq 1 60); do
      kubectl get gateway "$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" >/dev/null 2>&1 && break
      sleep 3
    done
  fi
  kubectl wait "gateway/$GATEWAY_NAME" -n "$GATEWAY_NAMESPACE" --for=condition=Programmed --timeout=180s >/dev/null
  kubectl -n kube-system rollout status deployment/traefik --timeout=180s >/dev/null
}
