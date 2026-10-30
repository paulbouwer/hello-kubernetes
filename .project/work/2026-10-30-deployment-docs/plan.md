---
title: Deployment docs
description: Rewrite the deployment docs for kubectl, Helm and Kustomize, with no clone of the repo, clear prerequisites, and Ingress and Gateway API examples.
type: plan
status: done
areas: [deploy]
issues: [121]
created: 2026-10-30
updated: 2026-10-30
---

# Deployment docs

## Intent

The quick start needed a clone of the repo, used the old `ingress.configured` value, and had no clean-up step (#28). The Ingress guide installed the retired community Ingress-NGINX controller and used `networking.k8s.io/v1beta1`, which Kubernetes removed in 1.22 (#31). There was nothing for `kubectl` or Kustomize users. This work rewrites the docs for what 1.11 publishes: the release file, the OCI chart, and the chart's Ingress and HTTPRoute.

This is work item 4.5 in the [1.x work plan](../2026-10-26-roadmap-1x/plan.md#4-chart-and-deployment), from [deploy.md](../../roadmap/1.x/deploy.md).

## Decisions

Made on 2026-10-30 (maintainer).

| Decision | Result |
|---|---|
| File names | `deploy-using-helm.md` and `deploy-with-ingress.md` keep their names, because tutorials link to them. `deploy-using-kubectl-and-kustomize.md` is new. |
| Quick start | Three paths, each with what it needs, where it installs, what it gives, how to reach the app, and how to remove it: `kubectl apply` of the release file (current namespace, defaults), `helm install` from the OCI chart (current namespace, defaults), and a custom message in its own namespace. |
| Where the address works | A table, in the README and the kubectl page. Testing found that on k3s, k3d and Rancher Desktop the built-in Traefik already holds port 80, so a `LoadBalancer` on port 80 stays pending; the docs give `port-forward`, or port 8080. |
| Values reference | Kept in step with `values.schema.json` by chart test C17, not generated. |
| NGINX | The docs recommend `rewritePath=false`, which needs no annotation. The F5 `nginx.org/rewrites` example uses paths with a trailing slash, and the chart's has none, so an NGINX rewrite example waits for 4.6, where it can be tested. |
| Versions | The quick start installs the newest release. The Helm guide shows `--version`, and the Kustomize examples pin `v1.11.0`. |

## Tracking

- **Issue:** [#121](https://github.com/paulbouwer/hello-kubernetes/issues/121), a sub-issue of epic [#54](https://github.com/paulbouwer/hello-kubernetes/issues/54). Resolves #28 and #31.
- **Branch:** `docs/121-deployment-docs`, from `release-1.11`.
- **Labels, milestone, assignee:** `documentation`, `area:deploy`, `v1.11`, @paulbouwer.

## Validation

Every command in the docs was run on a k3d cluster with Traefik, with the local chart in place of the OCI chart and a local image in place of `1.11.0`, which are published in 6.2.

| Check | How |
|---|---|
| README | The release file with `kubectl apply`, `rollout status`, `port-forward` and `delete`. Helm with the defaults, and with a message in the `hello` namespace, then uninstall. |
| Helm guide | Install, a second release with `ClusterIP`, `upgrade --reuse-values`, `helm list`, uninstall. C17 checks the values table. |
| Ingress and Gateway guide | Two Ingress releases without rewriting, one with a Traefik `stripPrefix` middleware, Traefik's Gateway turned on with the guide's `HelmChartConfig`, an HTTPRoute with `URLRewrite`, and the clean-up. |
| Kustomize | The three examples, from the doc: a namespace, a message and 3 replicas; port 8080; an Ingress. |
