---
title: Goal
description: What hello-kubernetes is for, and what is in and out of scope for the app, architectures, deployment, docs and the website.
type: goal
status: active
areas: [app, image, deploy, ci, site]
created: 2026-10-23
updated: 2026-10-23
---

# Goal

hello-kubernetes is a simple app for checking that a Kubernetes cluster works. Deploy it, open the page, and it shows basic information about where it's running.

It stays simple. The app only ever displays metadata, and the effort goes into making it easy to deploy on as many kinds of cluster as possible.

## In scope

### The app

A single page showing:

- a message (default "Hello world!")
- the namespace
- the pod name
- the node name, with the node's OS and kernel version
- the container image, with its architecture.

Settings, all through environment variables:

- the message (`MESSAGE`)
- the port (`PORT`)
- the path prefixes for running behind an ingress or gateway (`HANDLER_PATH_PREFIX`, `RENDER_PATH_PREFIX`)
- the log level (`LOG_LEVEL`).

That's the complete feature set. Other metadata or settings can be proposed in an issue, and are judged against the goal of keeping the app simple.

### Supported architectures

- `linux/amd64`
- `linux/arm64`

The architecture shown in the app must be the image's real platform. 

### Deployment

- **A Helm chart**, the single source of truth for the Kubernetes manifests.
- **Plain YAML published with each release**, rendered from the chart, for `kubectl apply` and as a base for Kustomize.
- **Documented Kustomize customisation** of the release YAML, with a reference of what each chart value changes.
- **Ways to expose the app:**
  - a Service of type ClusterIP, NodePort or LoadBalancer
  - an Ingress, created by the chart, with path prefix and rewrite options
  - a Gateway API HTTPRoute, created by the chart.
- **Enough configuration for a wide variety of clusters:**
  - replicas and resources
  - scheduling (`nodeSelector`, tolerations, affinity)
  - an image override
  - a security context that passes restricted Pod Security.

### Documentation, website and agent experience

- **Documentation** for every deployment option, in the README and `docs/`.
- **A website** on GitHub Pages, built from the same docs, with a config builder and a preview of the app's page.
- **Agent experience (AX):**
  - `llms.txt` and `llms-full.txt` on the website
  - `AGENTS.md` in the repo
  - a `values.schema.json` for the chart
  - docs commands that need no prompts and show the expected result.

## Out of scope

- **Windows**, on any architecture.
- **Other Linux architectures**, including `linux/arm/v7`, `linux/riscv64`, `linux/ppc64le` and `linux/s390x`.
- **Features beyond displaying metadata**, such as metrics, authentication, TLS in the app, databases or echoing requests.
- **A separately maintained Kustomize version** of the manifests. Kustomize users start from the release YAML.
- **Installing ingress controllers or Gateway API implementations.** Users bring their own.

## Possible 2.0 goal

Rewriting the app in Go or Rust would remove the dependency on Node's platform support and could bring back architectures such as `linux/arm/v7` and `linux/riscv64`. The app's behaviour and scope would stay the same. This is explored in [rewrite.md](roadmap/2.x/rewrite.md).
