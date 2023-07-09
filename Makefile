REGISTRY ?= docker.io
REPOSITORY ?= paulbouwer
IMAGE_VERSION ?= $(shell cat src/app/package.json | jq -r .version)
IMAGE_MAJOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f1 )
IMAGE_MINOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f2 )
IMAGE = $(REGISTRY)/$(REPOSITORY)/hello-kubernetes
BUILD_ARCH ?= amd64 arm arm64 riscv64
BUILD_IMAGE_LIST:=$(shell echo $(BUILD_ARCH) | sed -e "s~[^ ]*~$(IMAGE):$(IMAGE_VERSION)\-&~g")

.PHONY: scan-for-vulns
scan-for-vulns:
	for arch in $(BUILD_ARCH); do \
		if [ "$${arch}" = $$(uname -m) ]; then \
			trivy image --format template --template "@/trivy/contrib/sarif.tpl" $(IMAGE):$(IMAGE_VERSION)-$${arch}; \
		fi; \
	done

.PHONY: build-images
build-images: build-image-linux

.PHONY: build-image-linux
build-image-linux:
	cp Dockerfile build/docker/$${arch} ; \
	DOCKER_ARGS=""; \
	for arch in $(BUILD_ARCH); do \
		if [ "$${arch}" = "riscv64" ]; then \
			DOCKER_ARGS="--build-arg=BASE=riscv64/alpine:edge"; \
		fi; \
		DOCKER_BUILDKIT=1 \
		docker build --no-cache \
		--platform $${arch} \
		--build-arg IMAGE_VERSION="$(IMAGE_VERSION)" \
		--build-arg IMAGE_CREATE_DATE="`date -u +"%Y-%m-%dT%H:%M:%SZ"`" \
		--build-arg IMAGE_SOURCE_REVISION="`git rev-parse HEAD`" \
		$${DOCKER_ARGS} \
		-f src/app/Dockerfile -t "$(IMAGE):$(IMAGE_VERSION)-$${arch}" src/app; \
	done

.PHONY: push-image
push-image:
	for arch in $(BUILD_ARCH); do \
		docker push $(IMAGE):$(IMAGE_VERSION)-$${arch}; \
	done; \
	docker manifest create --amend $(IMAGE):$(IMAGE_VERSION) $(BUILD_IMAGE_LIST); \
	docker manifest create --amend $(IMAGE):$(IMAGE_MAJOR_VERSION) $(BUILD_IMAGE_LIST); \
	docker manifest create --amend $(IMAGE):$(IMAGE_MAJOR_VERSION).$(IMAGE_MINOR_VERSION) $(BUILD_IMAGE_LIST); \
	docker manifest push --purge $(IMAGE):$(IMAGE_VERSION); \
	docker manifest push --purge $(IMAGE):$(IMAGE_MAJOR_VERSION); \
	docker manifest push --purge $(IMAGE):$(IMAGE_MAJOR_VERSION).$(IMAGE_MINOR_VERSION); \
