#!/usr/bin/env bash
# Builds, tests and publishes the deprecation images for the old tags
# (.project/roadmap/1.x/deprecation.md). Each image is the original, pinned by
# digest in tags.txt, with one layer on top: a warning banner on the page and
# a notice on startup. Nothing else changes.
#
# Usage:
#   deprecation/deprecate.sh build   [tag...]   build the images locally
#   deprecation/deprecate.sh test    [tag...]   check them against the originals,
#                                               then run them on a kind cluster
#   deprecation/deprecate.sh publish --yes [tag...]
#                                               7.1 only: keep each original as
#                                               <tag>-original, then push the
#                                               new image to <tag>
# With no tags, every tag in tags.txt.
#
# publish refuses to run until paulbouwer/hello-kubernetes:1.11.0 exists, and
# refuses a tag whose original no longer has the digest in tags.txt.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_image=paulbouwer/hello-kubernetes
local_image=hello-kubernetes-deprecated

# tag digest user, from tags.txt, for the tags asked for.
entries() {
  local wanted=" $* "
  grep -v '^#' "$here/tags.txt" | awk 'NF == 3' | while read -r tag digest user; do
    if [[ $# -eq 0 || "$wanted" == *" $tag "* ]]; then echo "$tag $digest $user"; fi
  done
}

build() {
  local tag digest user context
  while read -r tag digest user; do
    context=$(mktemp -d)
    cp "$here/patch.js" "$here/banner.html" "$here/notice.js.in" "$context/"
    {
      echo "FROM $repo_image@$digest"
      [[ "$user" == root ]] || echo "USER root"
      echo "COPY patch.js banner.html notice.js.in /usr/src/app/.deprecation/"
      echo "RUN DEPRECATED_TAG=$tag node /usr/src/app/.deprecation/patch.js"
      [[ "$user" == root ]] || echo "USER $user"
      echo "LABEL org.opencontainers.image.description=\"DEPRECATED: hello-kubernetes $tag is unsupported and has known security vulnerabilities. Upgrade to ghcr.io/paulbouwer/hello-kubernetes:1.11.\" \\"
      echo "      io.github.paulbouwer.hello-kubernetes.deprecated=\"true\" \\"
      echo "      io.github.paulbouwer.hello-kubernetes.replacement=\"ghcr.io/paulbouwer/hello-kubernetes:1.11\" \\"
      echo "      io.github.paulbouwer.hello-kubernetes.original=\"$repo_image@$digest\""
    } >"$context/Dockerfile"
    echo "Building $local_image:$tag from $repo_image@$digest"
    docker build -q --platform linux/amd64 -t "$local_image:$tag" "$context" >/dev/null
    rm -rf "$context"
  done < <(entries "$@")
}

test_images() {
  node "$here/check.mjs" $(entries "$@" | awk '{print $1}')
}

publish() {
  [[ "${1:-}" == --yes ]] || { echo "publish changes public tags; run it as: publish --yes [tag...]" >&2; exit 2; }
  shift
  docker buildx imagetools inspect "$repo_image:1.11.0" >/dev/null 2>&1 ||
    { echo "$repo_image:1.11.0 isn't published yet; publish the warnings after 1.11.0 (7.1)" >&2; exit 1; }
  local tag digest user current pushed
  while read -r tag digest user; do
    current=$(docker buildx imagetools inspect "$repo_image:$tag" --format '{{json .Manifest}}' | jq -r .digest)
    if [[ "$current" != "$digest" ]]; then
      echo "$repo_image:$tag is $current, not the original $digest; skipping it" >&2
      continue
    fi
    docker image inspect "$local_image:$tag" >/dev/null 2>&1 || { echo "build and test $tag first" >&2; exit 1; }
    # Keep the original, by digest, before the tag moves.
    docker buildx imagetools create -t "$repo_image:$tag-original" "$repo_image@$digest"
    docker tag "$local_image:$tag" "$repo_image:$tag"
    docker push -q "$repo_image:$tag" >/dev/null
    pushed=$(docker buildx imagetools inspect "$repo_image:$tag" --format '{{json .Manifest}}' | jq -r .digest)
    echo "$repo_image:$tag is now $pushed; the original is $repo_image:$tag-original ($digest)"
  done < <(entries "$@")
}

command=${1:-}
shift || true
case "$command" in
  build) build "$@" ;;
  test) test_images "$@" ;;
  publish) publish "$@" ;;
  *) sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
