# Development environment for hello-kubernetes.
#
# The tools that build, test and scan what is deployed (Node.js, kubectl, Helm,
# Trivy, kind, k3d) are pinned in test/ci/install-tools.sh, the same table CI
# uses. The developer tools that are never deployed (gh, Copilot CLI, Claude
# Code) track their latest release. Every download is checked against a
# checksum. The build context is the repo root, limited by /.dockerignore.

FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Set by BuildKit to amd64 or arm64
ARG TARGETARCH

COPY .devcontainer/github-latest-release.sh /usr/local/bin/github-latest-release

# Node.js, kubectl, Helm, Trivy, kind and k3d, at the versions pinned in
# test/ci/install-tools.sh: the same versions as CI, each checked against a
# SHA-256 kept in that table.
COPY test/ci/install-tools.sh /tmp/install-tools.sh
RUN /tmp/install-tools.sh node kubectl helm trivy kind k3d \
    && rm /tmp/install-tools.sh

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
