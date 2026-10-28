# Both stages use node:24-alpine, pinned by digest to a multi-arch index
# (amd64 and arm64). Dependabot updates both digests. New Node majors are
# planned work.

# Install the production dependencies from the lockfile.
FROM node:24-alpine@sha256:06d7adf3e0ef61a13f1d28682726366f97a15aa1888c934d3ecec86c33918b53 AS deps
WORKDIR /usr/src/app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --ignore-scripts --no-audit --no-fund

FROM node:24-alpine@sha256:06d7adf3e0ef61a13f1d28682726366f97a15aa1888c934d3ecec86c33918b53

ARG IMAGE_CREATE_DATE
ARG IMAGE_VERSION
ARG IMAGE_SOURCE_REVISION

# Metadata as defined in OCI image spec annotations - https://github.com/opencontainers/image-spec/blob/master/annotations.md
LABEL org.opencontainers.image.title="Hello Kubernetes!" \
      org.opencontainers.image.description="Provides a demo app to deploy to a Kubernetes cluster. It displays a message, the name of the pod and details of the node it is deployed to." \
      org.opencontainers.image.created=$IMAGE_CREATE_DATE \
      org.opencontainers.image.version=$IMAGE_VERSION \
      org.opencontainers.image.authors="Paul Bouwer" \
      org.opencontainers.image.url="https://hub.docker.com/r/paulbouwer/hello-kubernetes/" \
      org.opencontainers.image.documentation="https://github.com/paulbouwer/hello-kubernetes/README.md" \
      org.opencontainers.image.vendor="Paul Bouwer" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/paulbouwer/hello-kubernetes.git" \
      org.opencontainers.image.revision=$IMAGE_SOURCE_REVISION

# The app runs without a package manager, so remove npm, corepack and yarn.
# Their bundled dependencies otherwise show up in vulnerability scans.
RUN rm -rf /usr/local/lib/node_modules /opt/yarn-* \
      /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
      /usr/local/bin/yarn /usr/local/bin/yarnpkg

WORKDIR /usr/src/app

# The app files stay owned by root and read-only to the app user.
COPY --from=deps /usr/src/app/node_modules ./node_modules
COPY package.json server.js ./
COPY static ./static
COPY views ./views

# Numeric user, so that a cluster can verify runAsNonRoot. 1000 is the
# image's node user. Start node directly, without npm.
USER 1000:1000
EXPOSE 8080
CMD ["node", "server.js"]
