REGISTRY ?= docker.io
REPOSITORY ?= paulbouwer
IMAGE_VERSION ?= $(shell cat src/app/package.json | jq -r .version)
IMAGE_MAJOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f1 )
IMAGE_MINOR_VERSION = $(shell echo "$(IMAGE_VERSION)" | cut -d '.' -f2 )
IMAGE = $(REGISTRY)/$(REPOSITORY)/hello-kubernetes

.PHONY: scan-for-vulns
scan-for-vulns: ## scan $(IMAGE):$(IMAGE_VERSION) as CI does: fail on HIGH and CRITICAL findings that have a fix
	trivy image --image-src docker --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 $(IMAGE):$(IMAGE_VERSION)

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

.PHONY: test-image
test-image: ## image tests (test/image/run.sh) against $(IMAGE):$(IMAGE_VERSION)
	test/image/run.sh "$(IMAGE):$(IMAGE_VERSION)"

.PHONY: test-proxy
test-proxy: ## proxy tests (test/proxy/run.sh) against $(IMAGE):$(IMAGE_VERSION)
	test/proxy/run.sh "$(IMAGE):$(IMAGE_VERSION)"

# npm ci writes node_modules/.package-lock.json, so it is newer than the
# lockfile after an install, and older than it after the lockfile changes.
src/app/node_modules/.package-lock.json: src/app/package-lock.json
	cd src/app && npm ci --ignore-scripts --no-audit --no-fund

.PHONY: run
run: src/app/node_modules/.package-lock.json ## run the app locally on port 8080, installing dependencies first if they are out of date
	node src/app/server.js

# End-to-end tests on local clusters (test/e2e/run.sh). The image is built from
# the working tree and tagged hello-kubernetes:e2e, so that no registry image
# is ever used. KEEP_CLUSTER=1 keeps the cluster for debugging.
E2E_IMAGE ?= hello-kubernetes:e2e

.PHONY: e2e-image
e2e-image:
	docker build -q -t $(E2E_IMAGE) src/app >/dev/null

.PHONY: e2e-kind
e2e-kind: e2e-image ## e2e tests on a kind cluster
	IMAGE=$(E2E_IMAGE) test/e2e/run.sh kind

.PHONY: e2e-k3d
e2e-k3d: e2e-image ## e2e tests on a k3d cluster
	IMAGE=$(E2E_IMAGE) test/e2e/run.sh k3d

.PHONY: e2e
e2e: e2e-kind e2e-k3d ## e2e tests on kind, then k3d

.PHONY: e2e-clean
e2e-clean: ## delete the e2e clusters
	-kind delete cluster --name hk-e2e-kind
	-k3d cluster delete hk-e2e-k3d
	rm -f $${TMPDIR:-/tmp}/hk-e2e-kind.kubeconfig $${TMPDIR:-/tmp}/hk-e2e-k3d.kubeconfig
