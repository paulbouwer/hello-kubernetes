FROM node:8.1.0-alpine

ARG BUILD_DATE
ARG IMAGE_VERSION
ARG VCS_REF

# Metadata as defined at http://label-schema.org
LABEL maintainer="Paul Bouwer" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.vendor="Paul Bouwer" \
      org.label-schema.name="Hello Kubernetes!" \
      org.label-schema.version=$IMAGE_VERSION \
      org.label-schema.license="MIT" \
      org.label-schema.description="Provides a test image to deploy to a Kubernetes cluster. It displays the name of the pod and details of the node it's deployed to." \
      org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/paulbouwer/hello-kubernetes.git" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.usage="https://github.com/paulbouwer/hello-kubernetes/README.md"

# Create app directory
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

# Install app dependencies
COPY package.json /usr/src/app/
RUN npm install

# Bundle app source
COPY . /usr/src/app

EXPOSE 8080
CMD [ "npm", "start" ]