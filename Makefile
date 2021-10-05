REGISTRY ?= docker.io
REPOSITORY ?= paulbouwer
IMAGE_VERSION ?= $(shell cat src/app/package.json | jq -r .version)
IMAGE_MAJOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f1 )
IMAGE_MINOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f2 )
IMAGE = $(REGISTRY)/$(REPOSITORY)/hello-kubernetes

.PHONY: scan-for-vulns
scan-for-vulns:
	trivy image --format template --template "@/trivy/contrib/sarif.tpl" $(IMAGE):$(IMAGE_VERSION)

.PHONY: build-images
build-images: build-image-linux

.PHONY: build-image-linux
build-image-linux: 
	docker build --no-cache \
		--build-arg IMAGE_VERSION="$(IMAGE_VERSION)" \
		--build-arg IMAGE_CREATE_DATE="`date -u +"%Y-%m-%dT%H:%M:%SZ"`" \
		--build-arg IMAGE_SOURCE_REVISION="`git rev-parse HEAD`" \
		-f src/app/Dockerfile -t "$(IMAGE):$(IMAGE_VERSION)" src/app;

.PHONY: push-image
push-image:
	docker tag $(IMAGE):$(IMAGE_VERSION) $(IMAGE):$(IMAGE_MAJOR_VERSION); \
	docker tag $(IMAGE):$(IMAGE_VERSION) $(IMAGE):$(IMAGE_MAJOR_VERSION).$(IMAGE_MINOR_VERSION); \
	docker push $(IMAGE):$(IMAGE_VERSION); \
	docker push $(IMAGE):$(IMAGE_MAJOR_VERSION); \
	docker push $(IMAGE):$(IMAGE_MAJOR_VERSION).$(IMAGE_MINOR_VERSION)