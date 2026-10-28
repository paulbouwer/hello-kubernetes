#!/usr/bin/env bash
# Image tests from .project/roadmap/1.x/testing.md (I1 to I3 so far).
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

if ((failures > 0)); then
  echo "$failures test(s) failed"
  exit 1
fi
echo "All image tests passed"
