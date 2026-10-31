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
push-image: ## push to your own registry. Official images are published only by CI.
	@if [ "$(REGISTRY)/$(REPOSITORY)" = "docker.io/paulbouwer" ]; then \
		echo "Official images are published only by CI (.github/workflows/build-and-publish-container-image.yaml)."; \
		echo "Set REGISTRY and REPOSITORY to your own registry to push there."; \
		exit 1; \
	fi
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

.PHONY: test-chart
test-chart: ## chart tests (test/chart/run.sh): render the chart and check it
	test/chart/run.sh

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

.PHONY: e2e-kind-oldest
e2e-kind-oldest: e2e-image ## e2e E1, E6 and E7 on kind with the oldest supported Kubernetes (E13)
	E2E_KUBERNETES=oldest IMAGE=$(E2E_IMAGE) test/e2e/run.sh kind e01 e06 e07

.PHONY: e2e
e2e: e2e-kind e2e-k3d ## e2e tests on kind, then k3d

.PHONY: cluster-kind
cluster-kind: e2e-image ## start a local kind cluster to try the docs on (kept until make cluster-clean)
	IMAGE=$(E2E_IMAGE) test/e2e/local.sh kind

.PHONY: cluster-k3d
cluster-k3d: e2e-image ## start a local k3d cluster to try the docs on (kept until make cluster-clean)
	IMAGE=$(E2E_IMAGE) test/e2e/local.sh k3d

.PHONY: cluster-clean
cluster-clean: ## delete the local and e2e clusters
	test/e2e/local.sh clean

.PHONY: e2e-clean
e2e-clean: ## delete the e2e clusters, and stop cloud-provider-kind
	test/e2e/local.sh clean

.PHONY: verify-published
verify-published: ## verify a published image: make verify-published PUBLISHED=ghcr.io/paulbouwer/hello-kubernetes:1.11.0 [SCAN=1]
	@test -n "$(PUBLISHED)" || { echo "Set PUBLISHED, for example PUBLISHED=paulbouwer/hello-kubernetes:1.11.0"; exit 2; }
	test/image/verify-published.sh "$(PUBLISHED)"

# The website (site/). Playwright runs from its official image, pinned by
# digest, so its browsers match @playwright/test in site/package.json.
PLAYWRIGHT_IMAGE ?= mcr.microsoft.com/playwright:v1.64.1-noble@sha256:47b510dd9230bf0b9bfc9b20102241e577ea7a99334ab4c3ca19f19770e9b8ea

.PHONY: site
site: ## build the website into site/dist, after its type checks
	cd site && npm ci --no-audit --no-fund && npm run check && npm run build

.PHONY: site-dev
site-dev: ## serve the website at http://localhost:4321/hello-kubernetes/, reloading on changes
	cd site && npm ci --no-audit --no-fund && npm run dev -- --port 4321

.PHONY: site-test
site-test: site ## browser checks of the built site; screenshots go to site/test-results/screenshots
	docker run --rm --ipc=host --network host -u "$$(id -u):$$(id -g)" -e HOME=/tmp \
		-v "$(CURDIR)/site:/site" -w /site $(PLAYWRIGHT_IMAGE) npx playwright test

.PHONY: screenshot
screenshot: cluster-k3d ## screenshot the app on a k3d cluster into hello-kubernetes.png, for the README
	PLAYWRIGHT_IMAGE=$(PLAYWRIGHT_IMAGE) test/screenshot.sh
