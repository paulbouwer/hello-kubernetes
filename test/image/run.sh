#!/usr/bin/env bash
# Image tests from .project/roadmap/1.x/testing.md: I1 to I7, and I5a.
#
# Usage: test/image/run.sh IMAGE
#
# Environment:
#   PLATFORMS  platforms for I5, comma-separated, e.g. linux/amd64,linux/arm64.
#              Defaults to the image's own platform. Others need emulation.
#
# Each test prints PASS or FAIL. The script exits 1 if any test fails.
# Every container runs with --pull never: a test must never fetch an image, which
# would replace the local tag with a registry image and test the wrong one.
# Needs docker, curl, jq and trivy (for I4).

set -euo pipefail

image="${1:?usage: $0 IMAGE}"
failures=0

pass() { echo "PASS $1: $2"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

# Runs a command in the image, with the entrypoint replaced.
in_image() {
  local entrypoint="$1"
  shift
  docker run --rm --pull never --entrypoint "$entrypoint" "$image" "$@"
}

# version_ge A B: true if version A >= version B (dotted numbers).
version_ge() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# Starts the image with extra docker run args, fetches the page from
# CONTAINER_PORT, and stops the container. Prints the stylesheet's HTTP status
# on the first line, then the page. The page is empty if it didn't load.
# serve_page CONTAINER_PORT [docker run args...]
serve_page() {
  local container_port="$1" cid port html="" css=000 error
  shift
  # Docker's errors and the container's logs go to stderr, so that they show
  # in the test output without changing what this function prints.
  if cid=$(docker run -d --pull never -p "127.0.0.1::$container_port" "$@" "$image" 2>"${TMPDIR:-/tmp}/serve-page.err"); then
    port=$(docker port "$cid" "$container_port/tcp" | head -n1 | sed 's/.*://')
    for _ in $(seq 1 40); do
      html=$(curl -fs "http://127.0.0.1:$port/" 2>/dev/null) && break
      sleep 0.25
    done
    css=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/css/main.css")
    if [[ -z "$html" ]]; then
      echo "    the page didn't load (docker run $*). Container logs:" >&2
      docker logs "$cid" 2>&1 | tail -n 20 | sed 's/^/      /' >&2
    fi
    docker rm -f "$cid" >/dev/null
  else
    error=$(cat "${TMPDIR:-/tmp}/serve-page.err")
    echo "    docker run $* failed: $error" >&2
  fi
  rm -f "${TMPDIR:-/tmp}/serve-page.err"
  printf '%s\n%s\n' "$css" "$html"
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

# I4: no HIGH or CRITICAL vulnerabilities that have a fix. Fails, not skips,
# when trivy is missing, so the test can't pass by not running.
if ! command -v trivy >/dev/null; then
  fail I4 "trivy is not installed, so the image can't be scanned"
else
  scan=$(mktemp)
  if trivy image --quiet --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed \
    --exit-code 1 --format json --output "$scan" "$image" 2>"$scan.err"; then
    pass I4 "no fixable HIGH or CRITICAL vulnerabilities ($(trivy --version | head -n1))"
  else
    found=$(jq -r '[.Results[]?.Vulnerabilities[]? | "\(.PkgName) \(.InstalledVersion) \(.VulnerabilityID) \(.Severity)"] | unique | join("; ")' "$scan" 2>/dev/null || true)
    fail I4 "${found:-trivy failed: $(tail -n 3 "$scan.err")}"
  fi
  rm -f "$scan" "$scan.err"
fi

# I5a: the page shows the architecture of the running image, in OCI form.
# The real architecture must match the image config. Simulated values, set
# with test/image/fake-arch.js, check the mapping from Node's names.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
page_arch() {
  local fake="$1" cid port html
  cid=$(docker run -d --pull never -p 127.0.0.1::8080 -e FAKE_ARCH="$fake" \
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

# I5: starts and serves on each platform, and the page shows that platform.
platforms="${PLATFORMS:-$expected_real}"
i5_problems=()
for platform in ${platforms//,/ }; do
  page=$(serve_page 8080 --platform "$platform" | tail -n +2)
  if [[ -z "$page" ]]; then
    i5_problems+=("$platform: the page didn't load")
  elif ! grep -qF "($platform)" <<<"$page"; then
    i5_problems+=("$platform: the page doesn't show ($platform)")
  fi
done
if ((${#i5_problems[@]} == 0)); then
  pass I5 "serves on ${platforms//,/, } and shows the platform"
else
  fail I5 "${i5_problems[*]}"
fi

# I6: respects PORT.
page=$(serve_page 9090 -e PORT=9090 | tail -n +2)
if [[ -n "$page" ]]; then
  pass I6 "serves on port 9090 with PORT=9090"
else
  fail I6 "nothing served on port 9090 with PORT=9090"
fi

# I7: works with a read-only root filesystem, as the chart's
# readOnlyRootFilesystem sets.
result=$(serve_page 8080 --read-only --tmpfs /tmp)
if [[ -n "$(tail -n +2 <<<"$result")" && "$(head -n1 <<<"$result")" == 200 ]]; then
  pass I7 "serves the page and the stylesheet with a read-only root filesystem"
else
  fail I7 "with a read-only root filesystem, the page didn't load or the stylesheet returned $(head -n1 <<<"$result")"
fi

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All image tests passed"
