# E15: the docs still work. Runs, in order, every code block marked
# "```bash e2e" in the README and in the website's pages, and fails if one fails
# or if the docs' own clean-up steps leave something behind.
#
# A block marked "```bash e2e=<group>" is one tab of a code group, such as
# kubectl or Helm in the quick start. A page with groups runs once per group:
# its unmarked-group blocks ("e2e") and that group's blocks, in page order.
#
# It swaps three things for the ones under test:
#   - the OCI chart becomes the local chart, with the image under test
#   - the release file URL becomes the chart rendered here, as the publish
#     workflow renders it
#   - the guide's example Gateway, my-gateway in gateway-system, becomes the
#     cluster's Gateway
# The guides' Ingress and Gateway examples use Traefik, so this runs on k3d.
CLUSTERS="k3d"

scenario() {
  local repo work file count=0 block first
  repo="$(cd "$CHART/../../.." && pwd)"
  work=$(mktemp -d)
  helm template demo "$CHART" |
    sed "s|image: \"paulbouwer/hello-kubernetes:[^\"]*\"|image: \"$IMAGE_REPOSITORY:$IMAGE_TAG\"|" >"$work/hello-kubernetes.yaml"
  local image_args="--set deployment.container.image.repository=$IMAGE_REPOSITORY"
  image_args+=" --set deployment.container.image.tag=$IMAGE_TAG --set deployment.container.image.pullPolicy=Never"

  local site=site/src/content/docs/docs pass doc groups group
  for file in README.md $site/start-here/quick-start.mdx $site/deploy/helm.mdx \
    $site/deploy/kubectl.mdx $site/deploy/ingress.mdx $site/deploy/gateway.mdx; do
    doc=$(basename "$(dirname "$file")")-$(basename "${file%.*}")
    groups=$(grep -oE '^```bash e2e=[a-z0-9-]+' "$repo/$file" | sed 's/.*=//' | awk '!seen[$0]++' || true)
    for group in ${groups:-all}; do
      pass="$doc-$group"
      # Write each block for this pass to its own file, numbered in order.
      awk -v dir="$work" -v pass="$pass" -v group="$group" '
        /^```bash e2e( |$)/ || $0 ~ "^```bash e2e=" group "( |$)" { n++; out = sprintf("%s/%s-%02d.sh", dir, pass, n); inblock = 1; next }
        /^```/ { inblock = 0; next }
        inblock { print > out }
      ' "$repo/$file"
      for block in $(ls "$work/$pass"-*.sh 2>/dev/null | sort); do
        sed -i \
          -e "s|helm show values oci://ghcr.io/paulbouwer/charts/hello-kubernetes|helm show values $CHART|" \
          -e "s|oci://ghcr.io/paulbouwer/charts/hello-kubernetes|$CHART $image_args|" \
          -e "s|https://github.com/paulbouwer/hello-kubernetes/releases/[^ ]*/hello-kubernetes.yaml|$work/hello-kubernetes.yaml|" \
          -e "s|my-gateway|$GATEWAY_NAME|; s|gateway-system|$GATEWAY_NAMESPACE|" \
          "$block"
        first=$(head -n1 "$block")
        if ! (cd "$work" && bash -euo pipefail "$block") >"$block.log" 2>&1; then
          sed 's/^/      /' "$block.log" | tail -n 20
          die "$file ($group): the block starting '$first' failed"
        fi
        info "$file ($group): ran '${first:0:60}'"
        count=$((count + 1))
      done
    done
  done
  ((count >= 22)) || die "ran only $count blocks; are the e2e markers still in the docs?"

  # The docs' own clean-up steps must leave nothing behind.
  local left
  left=$(kubectl get deployments --all-namespaces -l app.kubernetes.io/name=hello-kubernetes -o name)
  [[ -z "$left" ]] || die "the docs' clean-up steps left $left"
  info "ran $count blocks, and the docs' clean-up steps removed everything"
  rm -rf "$work"
}
