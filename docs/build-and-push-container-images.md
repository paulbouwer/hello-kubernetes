# Build and push container images

The `hello-kubernetes` container image can be built and pushed to your own registry.

The official images, `paulbouwer/hello-kubernetes` on Docker Hub and `ghcr.io/paulbouwer/hello-kubernetes`, are published only by CI, when a release is tagged. They are built for `linux/amd64` and `linux/arm64`, with an SBOM and signed provenance. `make push-image` refuses to push to `docker.io/paulbouwer`.

## Prerequisites

- [make](https://www.gnu.org/software/make/)
- [Docker cli](https://www.docker.com/)
- Container registry

If you are using the [VS Code Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) based development environment, all of the prerequisites will be available in the terminal.

## Makefile configuration

The `Makefile` in the root folder of the repo provides the functionality to allow you to build and push your own `hello-kubernetes` container image.

### Environment variables

| Name | Default | Description | 
| ---- | ------- | ----------- |
| REGISTRY | docker.io | The container registry to push the images to. |
| REPOSITORY | paulbouwer | The repository (or hierarchy) within the container registry where the image will be located. |
| IMAGE_VERSION | the version in src/app/package.json | The image version (label) to use for the built and pushed container images. |

### Targets

| Name | Description |
| ---- | ----------- |
| build-image-linux | Build the `hello-kubernetes` container image for the architecture of your machine (`linux/amd64` or `linux/arm64`). |
| push-image | Push the `hello-kubernetes` container image to your own registry, set with `REGISTRY` and `REPOSITORY`. |

## Building a container image

You can build the `hello-kubernete` container image as follows:

```bash
# Build the paulbouwer/hello-kubernetes:$version image
make build-image-linux

# Build the paulbouwer.azurecr.io/paulbouwer/hello-kubernetes:$version image
export REGISTRY=paulbouwer.azurecr.io
make build-image-linux
```

## Pushing a container image

You can push your built `hello-kubernetes` container image to your own registry as follows:

```bash
# REGISTRY=paulbouwer.azurecr.io
# Push paulbouwer.azurecr.io/paulbouwer/hello-kubernetes:$version to paulbouwer.azurecr.io.
# Will tag $majorversion and $majorversion.$minorversion.
#
# Example: The container image will be tagged as follows for $version=1.10.0
#   - paulbouwer.azurecr.io/paulbouwer/hello-kubernetes:1.10.0
#   - paulbouwer.azurecr.io/paulbouwer/hello-kubernetes:1.10
#   - paulbouwer.azurecr.io/paulbouwer/hello-kubernetes:1
export REGISTRY=paulbouwer.azurecr.io
make push-image
```

`make push-image` pushes the image for your machine's architecture only. To push one image for both architectures, use Buildx:

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  --tag myregistry.example.com/myrepo/hello-kubernetes:1.11.0 --push src/app
```

## Verifying a published image

Each official image has an SBOM and SLSA provenance for each platform, and its provenance is signed with GitHub artifact attestations. To check an image you pull:

```bash
make verify-published PUBLISHED=paulbouwer/hello-kubernetes:1.11.0
# or, with a vulnerability scan too:
SCAN=1 test/image/verify-published.sh ghcr.io/paulbouwer/hello-kubernetes:1
```

It checks that the image is one index for `linux/amd64` and `linux/arm64` (V1), that each platform has an SBOM (V2) and provenance from this repo's CI (V3), that the signed attestation verifies for this repo (V4), and that each platform runs as user `1000` with version and revision labels (V5). With `SCAN=1`, it also fails on fixable HIGH and CRITICAL vulnerabilities (V6).

It needs Docker with Buildx, `jq`, and the GitHub CLI signed in. Only published images have an SBOM, provenance and a signature: an image you build locally keeps none of them. For a local image, use `make test-image`.
