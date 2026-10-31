#!/usr/bin/env bash
# Takes the screenshot of the app for the README and the website: the chart,
# installed as the release hello-world in the hello-kubernetes namespace, on
# the k3d cluster from make cluster-k3d, with a real namespace, pod and node.
#
# Usage: make screenshot   (starts the cluster, then runs this)
#
# Environment:
#   PLAYWRIGHT_IMAGE  the Playwright image, pinned in the Makefile
#   OUT               where to write the screenshot (default hello-kubernetes.png)

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
out="${OUT:-$repo/hello-kubernetes.png}"
export KUBECONFIG="${TMPDIR:-/tmp}/hk-e2e-k3d.kubeconfig"
namespace=hello-kubernetes
port=18099

helm upgrade --install hello-world "$repo/deploy/helm/hello-kubernetes" \
  --namespace "$namespace" --create-namespace --set service.type=ClusterIP --wait >/dev/null
kubectl port-forward -n "$namespace" service/hello-kubernetes-hello-world "$port:80" >/dev/null 2>&1 &
forward=$!
trap 'kill $forward 2>/dev/null || true' EXIT
for _ in $(seq 1 40); do
  curl -fs -o /dev/null "http://127.0.0.1:$port/" && break
  sleep 0.25
done

docker run --rm --ipc=host --network host -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -v "$(dirname "$out"):/out" "$PLAYWRIGHT_IMAGE" \
  npx -y playwright@1.64.1 screenshot --full-page --viewport-size=640,480 --wait-for-timeout=1000 \
  "http://127.0.0.1:$port/" "/out/$(basename "$out")" >/dev/null

helm uninstall hello-world --namespace "$namespace" >/dev/null
kubectl delete namespace "$namespace" --wait=false >/dev/null
echo "Wrote $out"
