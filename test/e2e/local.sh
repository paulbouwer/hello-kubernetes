#!/usr/bin/env bash
# Starts a local kind or k3d cluster to try the deployment docs on, set up as
# the e2e tests set it up (cluster.sh): an Ingress controller, a Gateway, and
# the image loaded. The cluster is kept until you delete it.
#
# Usage: test/e2e/local.sh <kind|k3d>      start the cluster, or reuse it
#        test/e2e/local.sh clean           delete both clusters
#
# Environment:
#   IMAGE  the local image to load (default hello-kubernetes:e2e)
#
# The image is also loaded as the chart's default image,
# paulbouwer/hello-kubernetes:<appVersion>, so the docs' commands work before
# that version is published. In this cluster, that tag is your local build.
#
# The e2e tests use the same cluster names and ports, so make e2e-kind and
# make e2e-k3d reuse a running local cluster, and leave it running.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
image="${IMAGE:-hello-kubernetes:e2e}"

if [[ "${1:-}" == clean ]]; then
  for CLUSTER_TYPE in kind k3d; do
    (
      export CLUSTER_TYPE KUBECONFIG="${TMPDIR:-/tmp}/hk-e2e-$CLUSTER_TYPE.kubeconfig"
      # shellcheck source=cluster.sh
      source "$here/cluster.sh"
      if cluster_exists; then
        echo "Deleting $CLUSTER_TYPE cluster $cluster"
        delete_cluster_now >/dev/null
      fi
      stop_cloud_provider_kind
      rm -f "$KUBECONFIG" "${TMPDIR:-/tmp}/$cluster-cloud-provider-kind.log"
    )
  done
  exit 0
fi

export CLUSTER_TYPE="${1:-}"
case "$CLUSTER_TYPE" in
  kind | k3d) ;;
  *)
    echo "usage: $0 <kind|k3d|clean>" >&2
    exit 2
    ;;
esac

docker image inspect "$image" >/dev/null 2>&1 || {
  echo "image $image not found. Build it first, for example with make cluster-$CLUSTER_TYPE." >&2
  exit 2
}

export KUBECONFIG="${TMPDIR:-/tmp}/hk-e2e-$CLUSTER_TYPE.kubeconfig"
# shellcheck source=cluster.sh
source "$here/cluster.sh"

if cluster_exists; then
  echo "Reusing $CLUSTER_TYPE cluster $cluster"
else
  create_cluster
fi
write_kubeconfig
kubectl wait --for=condition=Ready nodes --all --timeout=120s >/dev/null

# The chart's default image, so that the docs' commands use the local build.
app_version=$(sed -nE 's/^appVersion: *"?([^"]*)"?$/\1/p' "$repo/deploy/helm/hello-kubernetes/Chart.yaml")
default_image="paulbouwer/hello-kubernetes:$app_version"
docker tag "$image" "$default_image"
load_image "$image"
load_image "$default_image"
setup_routing

case "$CLUSTER_TYPE" in
  kind) lb="cloud-provider-kind gives each LoadBalancer Service an address on the Docker network." ;;
  k3d) lb="Traefik holds port 80, so give a LoadBalancer Service another port: --set service.port=8080." ;;
esac

cat <<EOF

The $CLUSTER_TYPE cluster $cluster is ready. Use it with:

  export KUBECONFIG=$KUBECONFIG

Ingress:  class $INGRESS_CLASS, at $INGRESS_URL
Gateway:  $GATEWAY_NAME in the $GATEWAY_NAMESPACE namespace, at $GATEWAY_URL
EOF
[[ "$INGRESS_URL" == "$GATEWAY_URL" ]] && echo "          (Traefik serves the Ingress and the Gateway on the same port.)"
cat <<EOF
LoadBalancer: $lb

The image $default_image in this cluster is your local build of
$image, not the published image, so the docs' commands use it.

To try the docs, install from the local chart, deploy/helm/hello-kubernetes,
until $app_version is published:
EOF
case "$CLUSTER_TYPE" in
  kind)
    cat <<EOF
  helm install hello deploy/helm/hello-kubernetes --set service.type=ClusterIP \\
    --set ingress.enabled=true --set ingress.className=nginx --set ingress.host=hello.local \\
    --set pathPrefix=/app/hello --set rewritePath=false --wait
  curl -H "Host: hello.local" $INGRESS_URL/app/hello/

The NGINX Ingress Controller needs a host on each Ingress, so send it in the
Host header, or add hello.local to your hosts file.
EOF
    ;;
  k3d)
    cat <<EOF
  helm install hello deploy/helm/hello-kubernetes --set service.type=ClusterIP \\
    --set ingress.enabled=true --set ingress.className=traefik \\
    --set pathPrefix=/app/hello --set rewritePath=false --wait
  curl $INGRESS_URL/app/hello/
EOF
    ;;
esac
cat <<EOF

In the devcontainer, the ports are on localhost there. VS Code forwards them
to your machine: see its Ports view. Delete the cluster with make cluster-clean.
EOF
