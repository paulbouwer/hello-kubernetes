# Development environment for hello-kubernetes.
#
# Tools track the latest release within a major version, so a rebuild picks up
# new minor and patch releases. Every download is checked against the checksum
# file published with that release. Release images are pinned separately.

FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Set by BuildKit to amd64 or arm64
ARG TARGETARCH

COPY github-latest-release.sh /usr/local/bin/github-latest-release

# Node.js
ARG NODE_MAJOR=24
RUN ARCH=$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64) \
    && VERSION=$(curl -fsSL https://nodejs.org/dist/index.json | jq -r --arg m "v${NODE_MAJOR}." '[.[] | select(.version | startswith($m))][0].version') \
    && FILE="node-${VERSION}-linux-${ARCH}.tar.xz" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "https://nodejs.org/dist/${VERSION}/${FILE}" \
    && curl -fsSL "https://nodejs.org/dist/${VERSION}/SHASUMS256.txt" | grep " ${FILE}\$" | sha256sum -c - \
    && tar -xJf "$FILE" -C /usr/local --strip-components=1 --no-same-owner \
    && rm -rf "$PWD"

# kubectl
RUN VERSION=$(curl -fsSL https://dl.k8s.io/release/stable.txt) \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "https://dl.k8s.io/release/${VERSION}/bin/linux/${TARGETARCH}/kubectl" \
    && echo "$(curl -fsSL "https://dl.k8s.io/release/${VERSION}/bin/linux/${TARGETARCH}/kubectl.sha256")  kubectl" | sha256sum -c - \
    && install -m 0755 kubectl /usr/local/bin/kubectl \
    && rm -rf "$PWD"

# Helm
ARG HELM_MAJOR=4
RUN VERSION=$(github-latest-release helm/helm "$HELM_MAJOR") \
    && FILE="helm-${VERSION}-linux-${TARGETARCH}.tar.gz" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "https://get.helm.sh/${FILE}" \
    && curl -fsSL "https://get.helm.sh/${FILE}.sha256sum" | sha256sum -c - \
    && tar -xzf "$FILE" --strip-components=1 "linux-${TARGETARCH}/helm" \
    && install -m 0755 helm /usr/local/bin/helm \
    && rm -rf "$PWD"

# Trivy
ARG TRIVY_MAJOR=0
RUN ARCH=$([ "$TARGETARCH" = arm64 ] && echo ARM64 || echo 64bit) \
    && VERSION=$(github-latest-release aquasecurity/trivy "$TRIVY_MAJOR") \
    && FILE="trivy_${VERSION#v}_Linux-${ARCH}.tar.gz" \
    && URL="https://github.com/aquasecurity/trivy/releases/download/${VERSION}" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "${URL}/${FILE}" \
    && curl -fsSL "${URL}/trivy_${VERSION#v}_checksums.txt" | grep " ${FILE}\$" | sha256sum -c - \
    && tar -xzf "$FILE" trivy \
    && install -m 0755 trivy /usr/local/bin/trivy \
    && rm -rf "$PWD"

# kind
ARG KIND_MAJOR=0
RUN VERSION=$(github-latest-release kubernetes-sigs/kind "$KIND_MAJOR") \
    && FILE="kind-linux-${TARGETARCH}" \
    && URL="https://github.com/kubernetes-sigs/kind/releases/download/${VERSION}" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "${URL}/${FILE}" \
    && curl -fsSL "${URL}/${FILE}.sha256sum" | sha256sum -c - \
    && install -m 0755 "$FILE" /usr/local/bin/kind \
    && rm -rf "$PWD"

# k3d
ARG K3D_MAJOR=5
RUN VERSION=$(github-latest-release k3d-io/k3d "$K3D_MAJOR") \
    && FILE="k3d-linux-${TARGETARCH}" \
    && URL="https://github.com/k3d-io/k3d/releases/download/${VERSION}" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "${URL}/${FILE}" \
    && curl -fsSL "${URL}/checksums.txt" | grep " _dist/${FILE}\$" | sed 's| _dist/| |' | sha256sum -c - \
    && install -m 0755 "$FILE" /usr/local/bin/k3d \
    && rm -rf "$PWD"

# GitHub CLI
ARG GH_MAJOR=2
RUN VERSION=$(github-latest-release cli/cli "$GH_MAJOR") \
    && FILE="gh_${VERSION#v}_linux_${TARGETARCH}.tar.gz" \
    && URL="https://github.com/cli/cli/releases/download/${VERSION}" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "${URL}/${FILE}" \
    && curl -fsSL "${URL}/gh_${VERSION#v}_checksums.txt" | grep " ${FILE}\$" | sha256sum -c - \
    && tar -xzf "$FILE" --strip-components=2 "gh_${VERSION#v}_linux_${TARGETARCH}/bin/gh" \
    && install -m 0755 gh /usr/local/bin/gh \
    && rm -rf "$PWD"

# GitHub Copilot CLI (updates itself)
RUN ARCH=$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64) \
    && FILE="copilot-linux-${ARCH}.tar.gz" \
    && URL="https://github.com/github/copilot-cli/releases/latest/download" \
    && cd "$(mktemp -d)" \
    && curl -fsSLO "${URL}/${FILE}" \
    && curl -fsSL "${URL}/SHA256SUMS.txt" | grep " ${FILE}\$" | sha256sum -c - \
    && tar -xzf "$FILE" copilot \
    && install -m 0755 copilot /usr/local/bin/copilot \
    && rm -rf "$PWD"

# Claude Code, stable channel (updates itself)
USER vscode
RUN ARCH=$([ "$TARGETARCH" = arm64 ] && echo arm64 || echo x64) \
    && URL="https://downloads.claude.ai/claude-code-releases" \
    && VERSION=$(curl -fsSL "${URL}/stable") \
    && cd "$(mktemp -d)" \
    && curl -fsSL -o claude "${URL}/${VERSION}/linux-${ARCH}/claude" \
    && echo "$(curl -fsSL "${URL}/${VERSION}/manifest.json" | jq -r --arg p "linux-${ARCH}" '.platforms[$p].checksum')  claude" | sha256sum -c - \
    && chmod +x claude \
    && ./claude install stable \
    && rm -rf "$PWD"
USER root

ENV PATH="/home/vscode/.local/bin:${PATH}"
