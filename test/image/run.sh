#!/usr/bin/env bash
# Image tests from .project/roadmap/1.x/testing.md (I1 to I3 and I5a so far).
#
# Usage: test/image/run.sh IMAGE
#
# Each test prints PASS or FAIL. The script exits 1 if any test fails.

set -euo pipefail

image="${1:?usage: $0 IMAGE}"
failures=0

pass() { echo "PASS $1: $2"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

# Runs a command in the image, with the entrypoint replaced.
in_image() {
  local entrypoint="$1"
  shift
  docker run --rm --entrypoint "$entrypoint" "$image" "$@"
}

# version_ge A B: true if version A >= version B (dotted numbers).
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# I1: Node is a supported line, at or above the release with the eMudhra fix.
node_version=$(in_image node -p process.versions.node)
case "${node_version%%.*}" in
  22) minimum=22.23.4 ;;
  24) minimum=24.22.1 ;;
  26) minimum=26.12.1 ;;
  *) minimum="" ;;
esac
if [[ -z "$minimum" ]]; then
  fail I1 "Node $node_version is not a supported line (22, 24 or 26)"
elif version_ge "$node_version" "$minimum"; then
  pass I1 "Node $node_version >= $minimum"
else
  fail I1 "Node $node_version < $minimum"
fi

# I2: the OS CA bundle has the eMudhra fix. Alpine's node images install
# ca-certificates-bundle, not ca-certificates.
ca_minimum=20261020-r0
ca_version=$(in_image apk list --installed ca-certificates-bundle | awk '{print $1}' | sed 's/^ca-certificates-bundle-//')
if [[ -z "$ca_version" ]]; then
  fail I2 "ca-certificates-bundle is not installed"
elif [[ "$(in_image apk version -t "$ca_version" "$ca_minimum")" != "<" ]]; then
  pass I2 "ca-certificates-bundle $ca_version >= $ca_minimum"
else
  fail I2 "ca-certificates-bundle $ca_version < $ca_minimum"
fi

# I3: runs as the numeric non-root user 1000.
config_user=$(docker inspect -f '{{.Config.User}}' "$image")
uid=$(in_image id -u)
if [[ "$config_user" =~ ^1000(:1000)?$ && "$uid" == "1000" ]]; then
  pass I3 "user is $config_user, id -u is $uid"
else
  fail I3 "user is '$config_user', id -u is '$uid' (want 1000)"
fi

# I5a: the page shows the architecture of the running image, in OCI form.
# The real architecture must match the image config. Simulated values, set
# with test/image/fake-arch.js, check the mapping from Node's names.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
page_arch() {
  local fake="$1" cid port html
  cid=$(docker run -d -p 127.0.0.1::8080 -e FAKE_ARCH="$fake" \
    -v "$here/fake-arch.js:/tmp/fake-arch.js:ro" -e NODE_OPTIONS=--require=/tmp/fake-arch.js "$image")
  port=$(docker port "$cid" 8080/tcp | head -n1 | sed 's/.*://')
  for _ in $(seq 1 40); do
    html=$(curl -fs "http://127.0.0.1:$port/" 2>/dev/null) && break
    sleep 0.25
  done
  docker rm -f "$cid" >/dev/null
  # The footer ends with "(<os>/<arch>)".
  sed -nE 's/.*\(([a-z0-9]+\/[a-z0-9]+)\).*/\1/p' <<<"$html" | tail -n1
}
expected_real=$(docker inspect -f '{{.Os}}/{{.Architecture}}' "$image")
i5a_problems=()
shown=$(page_arch "")
[[ "$shown" == "$expected_real" ]] || i5a_problems+=("real: shows '$shown', image is $expected_real")
for pair in x64=amd64 arm64=arm64 ia32=386 ppc64=ppc64le s390x=s390x riscv64=riscv64; do
  shown=$(page_arch "${pair%%=*}")
  [[ "$shown" == "linux/${pair#*=}" ]] || i5a_problems+=("${pair%%=*}: shows '$shown', want linux/${pair#*=}")
done
if ((${#i5a_problems[@]} == 0)); then
  pass I5a "page shows $expected_real, and x64, arm64, ia32, ppc64, s390x, riscv64 map correctly"
else
  fail I5a "${i5a_problems[*]}"
fi

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All image tests passed"
