# Build and push container images

The `hello-kubernetes` container image can be built and pushed to your own registry or or DockerHub repository. Currently only the `linux/amd64` architecture is supported.

## Prerequisites

- [make](https://www.gnu.org/software/make/)
- [Docker cli](https://www.docker.com/)
- Container registry

## Makefile configuration

The `Makefile` in the root folder of the repo provides the functionality to allow you to build and push your own `hello-kubernetes` container image.

### Environment variables

| Name | Default | Description | 
| ---- | ------- | ----------- |
| REGISTRY | docker.io | The container registry to push the images to. |
| REPOSITORY | eduardobaitello | The repository (or hierarchy) within the container registry where the image will be located. |
| IMAGE_VERSION | the version in src/app/package.json | The image version (label) to use for the built and pushed container images. |

### Targets

| Name | Description |
| ---- | ----------- |
| build-image-linux | Build the `hello-kubernetes` container image for the `linux/amd64` architecture. |
| push-image | Push the `hello-kubernetes` container image to the defined registry. |

## Building a container image

You can build the `hello-kubernete` container image as follows:

```bash
# Build the eduardobaitello/hello-kubernetes:$version image
make build-image-linux

# Build the eduardobaitello.azurecr.io/eduardobaitello/hello-kubernetes:$version image
export REGISTRY=eduardobaitello.azurecr.io
make build-image-linux
```

## Pushing a container image

You can push your built `hello-kubernetes` container image to the defined registry as follows:

```bash
# Push eduardobaitello/hello-kubernetes:$version to docker hub.
# Will tag $majorversion and $majorversion.$minorversion.
#
# Example: The container image will be tagged as follows for $version=1.10.0
#   - eduardobaitello/hello-kubernetes:1.10.0
#   - eduardobaitello/hello-kubernetes:1.10
#   - eduardobaitello/hello-kubernetes:1
make push-image

# REGISTRY=eduardobaitello.azurecr.io
# Push eduardobaitello.azurecr.io/eduardobaitello/hello-kubernetes:$version to eduardobaitello.azurecr.io.
# Will tag $majorversion and $majorversion.$minorversion.
#
# Example: The container image will be tagged as follows for $version=1.10.0
#   - eduardobaitello.azurecr.io/eduardobaitello/hello-kubernetes:1.10.0
#   - eduardobaitello.azurecr.io/eduardobaitello/hello-kubernetes:1.10
#   - eduardobaitello.azurecr.io/eduardobaitello/hello-kubernetes:1
export REGISTRY=eduardobaitello.azurecr.io
make push-image
```
