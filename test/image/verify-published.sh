#!/usr/bin/env bash
# Verifies a published hello-kubernetes image in a registry: its platforms, its
# SBOM and provenance, the signed provenance attestation, and its config.
#
# Usage: test/image/verify-published.sh IMAGE
#   IMAGE: a published image, for example paulbouwer/hello-kubernetes:1.11.0,
#          ghcr.io/paulbouwer/hello-kubernetes:1, or ...@sha256:<digest>
#
# Environment:
#   REPO   the GitHub repo that must have built and signed it
#          (default paulbouwer/hello-kubernetes)
#   SCAN   1 also scans the image with Trivy, and fails on HIGH and CRITICAL
#          findings that have a fix
#
# Only published images have an SBOM, provenance and a signature: a local build
# keeps none of them. For a local image, use make test-image.
#
# Needs docker with buildx, jq, and gh (signed in, for the attestation check).
# Each check prints PASS or FAIL. The script exits 1 if any check fails.

set -euo pipefail

image="${1:?usage: $0 IMAGE}"
repo="${REPO:-paulbouwer/hello-kubernetes}"
failures=0

pass() { echo "PASS $1: $2"; }
fail() { echo "FAIL $1: $2"; failures=$((failures + 1)); }

for tool in docker jq gh; do
  command -v "$tool" >/dev/null || { echo "$tool is not installed" >&2; exit 2; }
done

inspect() {
  docker buildx imagetools inspect "$image" --format "{{json .$1}}"
}

if ! manifest=$(inspect Manifest 2>/dev/null); then
  echo "Can't find $image in a registry." >&2
  echo "Only published images have an SBOM, provenance and a signature. For a local image, use make test-image." >&2
  exit 2
fi
digest=$(jq -r .digest <<<"$manifest")
echo "Image: $image"
echo "Digest: $digest"

# The name without a tag or digest, with docker.io added when there's no
# registry, for gh attestation verify.
name="${image%@*}"
last="${name##*/}"
[[ "$last" == *:* ]] && name="${name%:*}"
first="${name%%/*}"
if [[ "$name" != */* || ( "$first" != *.* && "$first" != *:* && "$first" != localhost ) ]]; then
  name="docker.io/$name"
fi

# V1: the image is one index for linux/amd64 and linux/arm64.
platforms=$(jq -r '[.manifests[]?.platform | select(.os != "unknown") | "\(.os)/\(.architecture)"] | sort | join(",")' <<<"$manifest")
if [[ "$(jq -r .mediaType <<<"$manifest")" != *index* && "$(jq -r .mediaType <<<"$manifest")" != *manifest.list* ]]; then
  fail V1 "a single-platform image, not one index for linux/amd64 and linux/arm64"
elif [[ "$platforms" == "linux/amd64,linux/arm64" ]]; then
  pass V1 "platforms: $platforms"
else
  fail V1 "platforms are '${platforms:-none}', want linux/amd64,linux/arm64"
fi

# V2: each platform has an SBOM.
sbom=$(inspect SBOM 2>/dev/null || echo '{}')
for platform in linux/amd64 linux/arm64; do
  count=$(jq -r --arg p "$platform" '.[$p].SPDX.packages // [] | length' <<<"$sbom" 2>/dev/null || echo 0)
  version=$(jq -r --arg p "$platform" '.[$p].SPDX.spdxVersion // ""' <<<"$sbom" 2>/dev/null || true)
  if ((count > 0)); then
    pass V2 "$platform SBOM: $version, $count packages"
  else
    fail V2 "$platform has no SBOM"
  fi
done

# V3: each platform has SLSA provenance from a GitHub Actions run in REPO.
provenance=$(inspect Provenance 2>/dev/null || echo '{}')
for platform in linux/amd64 linux/arm64; do
  builder=$(jq -r --arg p "$platform" '.[$p].SLSA | (.runDetails.builder.id // .builder.id // "")' <<<"$provenance" 2>/dev/null || true)
  revision=$(jq -r --arg p "$platform" '.[$p].SLSA.buildDefinition.externalParameters.request.args["label:org.opencontainers.image.revision"] // ""' <<<"$provenance" 2>/dev/null || true)
  if [[ "$builder" == "https://github.com/$repo/actions/runs/"* ]]; then
    pass V3 "$platform provenance: built by $builder, revision ${revision:0:7}"
  else
    fail V3 "$platform has no provenance from $repo (builder '${builder:-none}')"
  fi
done

# V4: the signed provenance attestation verifies for REPO.
if result=$(gh attestation verify "oci://$name@$digest" --repo "$repo" --format json 2>&1); then
  pass V4 "$(jq -r '.[0].verificationResult | "signed attestation: \(.statement.predicateType), workflow \(.signature.certificate.buildSignerURI | split("@")[0] | split("/") | last), \(.signature.certificate.sourceRepositoryRef), commit \(.signature.certificate.sourceRepositoryDigest[0:7])"' <<<"$result")"
else
  fail V4 "no attestation signed by $repo verifies for $name@$digest: $(tail -n 1 <<<"$result")"
fi

# V5: each platform runs as the numeric user 1000, with version and revision labels.
config=$(inspect Image 2>/dev/null || echo '{}')
for platform in linux/amd64 linux/arm64; do
  read -r user version revision < <(jq -r --arg p "$platform" '.[$p].config | "\(.User // "-") \(.Labels["org.opencontainers.image.version"] // "-") \(.Labels["org.opencontainers.image.revision"] // "-")"' <<<"$config" 2>/dev/null || echo "- - -")
  if [[ "$user" =~ ^1000(:1000)?$ && "$version" != - && "$revision" != - ]]; then
    pass V5 "$platform: user $user, version $version, revision ${revision:0:7}"
  else
    fail V5 "$platform: user '$user', version '$version', revision '$revision'"
  fi
done

# V6 (SCAN=1): no fixable HIGH or CRITICAL vulnerabilities in the published image.
if [[ "${SCAN:-0}" == 1 ]]; then
  if ! command -v trivy >/dev/null; then
    fail V6 "trivy is not installed, so the image can't be scanned"
  elif trivy image --quiet --image-src remote --scanners vuln --severity HIGH,CRITICAL \
    --ignore-unfixed --exit-code 1 --format table "$image" >/dev/null 2>&1; then
    pass V6 "no fixable HIGH or CRITICAL vulnerabilities"
  else
    fail V6 "fixable HIGH or CRITICAL vulnerabilities found. Run: trivy image --image-src remote $image"
  fi
fi

if ((failures > 0)); then
  echo "$failures check(s) failed"
  exit 1
fi
echo "All checks passed"
