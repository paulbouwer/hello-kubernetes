#!/usr/bin/env bash
# Installs the tools that CI uses, at pinned versions, after checking each
# download against a SHA-256 kept here. This table is the only place where the
# CI tool versions are set: the test and scan workflows both use this script.
#
# Usage: test/ci/install-tools.sh [tool...]
#   tool: trivy, kind, k3d, helm or kubectl. With no tool, installs all of them.
#
# Environment:
#   INSTALL_DIR  where to install (default /usr/local/bin, with sudo if needed)
#
# To change a version: choose a release published at least 7 days ago
# (AGENTS.md rule 8), take the SHA-256 for linux/amd64 and linux/arm64 from
# the project's published checksums, check it against the downloaded file, and
# update both values here.

set -euo pipefail

TRIVY_VERSION=0.76.1
TRIVY_SHA256_AMD64=c7cbe3137fb8a48a17574bede3dd6beb16742d1e9772929940fc90082c39d9c0
TRIVY_SHA256_ARM64=e174dff2a6dba5e3ae41f8d0537a6324405bd08132497340304c6b20e0f16a1f

KIND_VERSION=0.33.0
KIND_SHA256_AMD64=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d
KIND_SHA256_ARM64=20022bee6cfcd5086cb7234d218e3454e6090022f2a8f55d1fa7fcf42c3867a2

K3D_VERSION=5.9.0
K3D_SHA256_AMD64=06d8f25bc3a971c4eb29e0ff08429b180402db0f4dec838c9eac427e296800a0
K3D_SHA256_ARM64=03cde5cf23e6e8e67de5a039ecf26e5b85aca82fba3e5d13dadf904cd218a250

HELM_VERSION=4.3.1
HELM_SHA256_AMD64=0403a88ae20913d11b10a2467b50087721fea7581736da6b9d3992f5357fe54b
HELM_SHA256_ARM64=8cf8f66ecbc252ac8f7f06cca68aba88508ddfde3a6a34feb1678ad1694b4f88

KUBECTL_VERSION=1.37.1
KUBECTL_SHA256_AMD64=65691ff77eb6fa44c908b77a1082c9f092c3b9733b5cefabec0d1104890e21a8
KUBECTL_SHA256_ARM64=ff749f4b78d9c4f1ec87307df9b50119ed819e2094aa9810cb9acffc3286c8c7

case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
  *)
    echo "unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac
ARCH_UPPER=$(tr '[:lower:]' '[:upper:]' <<<"$arch")
install_dir="${INSTALL_DIR:-/usr/local/bin}"
workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

# Downloads URL to FILE in the work directory and checks its SHA-256.
fetch() {
  local url="$1" file="$2" sha="$3"
  curl -fsSL -o "$workdir/$file" "$url"
  echo "$sha  $workdir/$file" | sha256sum -c --quiet - ||
    { echo "SHA-256 mismatch for $url" >&2; exit 1; }
}

# Installs a binary from the work directory into the install directory.
place() {
  local source="$1" name="$2"
  if [[ -w "$install_dir" ]]; then
    install -m 0755 "$source" "$install_dir/$name"
  else
    sudo install -m 0755 "$source" "$install_dir/$name"
  fi
  echo "installed $name to $install_dir"
}

sha_for() {
  local var="${1}_SHA256_${ARCH_UPPER}"
  echo "${!var}"
}

install_trivy() {
  local file
  file="trivy_${TRIVY_VERSION}_Linux-$([[ $arch == amd64 ]] && echo 64bit || echo ARM64).tar.gz"
  fetch "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/$file" "$file" "$(sha_for TRIVY)"
  tar -xzf "$workdir/$file" -C "$workdir" trivy
  place "$workdir/trivy" trivy
}

install_kind() {
  fetch "https://github.com/kubernetes-sigs/kind/releases/download/v${KIND_VERSION}/kind-linux-$arch" kind "$(sha_for KIND)"
  place "$workdir/kind" kind
}

install_k3d() {
  fetch "https://github.com/k3d-io/k3d/releases/download/v${K3D_VERSION}/k3d-linux-$arch" k3d "$(sha_for K3D)"
  place "$workdir/k3d" k3d
}

install_helm() {
  local file="helm-v${HELM_VERSION}-linux-$arch.tar.gz"
  fetch "https://get.helm.sh/$file" "$file" "$(sha_for HELM)"
  tar -xzf "$workdir/$file" -C "$workdir" "linux-$arch/helm"
  place "$workdir/linux-$arch/helm" helm
}

install_kubectl() {
  fetch "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/$arch/kubectl" kubectl "$(sha_for KUBECTL)"
  place "$workdir/kubectl" kubectl
}

tools=("$@")
((${#tools[@]} > 0)) || tools=(trivy kind k3d helm kubectl)
for tool in "${tools[@]}"; do
  case "$tool" in
    trivy | kind | k3d | helm | kubectl) "install_$tool" ;;
    *)
      echo "unknown tool: $tool (trivy, kind, k3d, helm or kubectl)" >&2
      exit 2
      ;;
  esac
done
