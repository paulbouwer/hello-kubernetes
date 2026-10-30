---
title: Deployment
description: Helm as the single source, rendered release YAML, Kustomize patches, chart-created Ingress and HTTPRoute with NGINX and Traefik examples.
type: plan
status: active
areas: [deploy]
created: 2026-10-22
updated: 2026-10-26
---

# Deployment

How people should deploy hello-kubernetes: with Helm, with plain `kubectl apply`, or with Kustomize, and how to expose it through a Service, an Ingress or the Gateway API. This goes with item 6 (Helm) in [review.md](review.md), the `helm template` request in [community.md](community.md), and the deployment scope in [GOAL.md](../../GOAL.md).

## Summary

- **Keep Helm as the single source of truth.** Don't maintain a second, hand-written set of Kustomize manifests.
- **Publish rendered YAML from the chart** with every release, so `kubectl apply` and Kustomize users have a stable URL to start from.
- **Document how to customise that YAML with Kustomize patches**, including a table of what each chart value changes.
- **Have the chart create an Ingress or a Gateway API HTTPRoute**, not just set the app's path prefix. Document NGINX and Traefik as the two worked examples.
- **Recommend "no rewrite" for path prefixes**, so an Ingress works on any controller without annotations. In 1.x the default stays `rewritePath: true`, so the docs set `rewritePath=false` explicitly. The default changes in 2.0.
- **Support Helm 4.** The devcontainer and CI use Helm 4. Helm 3 is near the end of its security fixes, so the chart is not tested with it (decided 2026-10-30).

## Helm version

The devcontainer used to install whatever Helm release was newest at build time, so each rebuild could pull a different major version. Since #50 it installs the latest Helm 4.x release (`HELM_MAJOR=4` in `.devcontainer/Dockerfile`), checked against its published checksum. The development environment tracks the latest release in a major version on purpose; exact versions are pinned in CI and the release images, not in the devcontainer.

- Helm 4 came out in late 2025, and Helm 3 is close to the end of its security-fix window. Check the exact date on helm.sh before putting it in the docs.
- The chart is `apiVersion: v2`. `helm lint` and `helm template` run under Helm 4, and the e2e tests install it with Helm 4 (see [testing.md](testing.md)).
- The docs say Helm 4 (#113). On 2026-10-30 the maintainer decided not to test Helm 3: it is near the end of its security fixes, and the devcontainer and CI already use Helm 4.

The chart also needs the work in review item 6. 4.1 (#113) adds the `securityContext`, sets `appVersion` to `1.11.0` and fills `templates/NOTES.txt`. The probe fix (PR #30/#44) merged in 1.10. The ingress docs (#31) are in 4.5.

## Exposing the app

Today the chart never creates an Ingress or a route. `ingress.configured` only sets two environment variables on the Deployment, and users write their own Ingress. [GOAL.md](../../GOAL.md) puts chart-created Ingress and HTTPRoute resources in scope.

The Ingress API is frozen (stable, with no new features), not deprecated, so both are supported. The community Ingress-NGINX controller was retired in March 2026, which is why the Gateway API matters for new clusters. Installing controllers or Gateway API implementations stays out of scope; users bring their own.

### Path prefixes and rewriting

When the app is served under a prefix such as `/app/hello`, either the proxy strips the prefix before passing requests on, or the app serves under the prefix itself:

| `rewritePath` | Proxy | App | Works on |
|---|---|---|---|
| `false` (recommended; default from 2.0) | Passes `/app/hello/...` through unchanged | Serves under `/app/hello` (`HANDLER_PATH_PREFIX` and `RENDER_PATH_PREFIX` both set) | Every Ingress controller and Gateway, no annotations |
| `true` (default in 1.x) | Strips `/app/hello` | Serves at `/`, renders links with the prefix (`RENDER_PATH_PREFIX` only) | Ingress: needs controller-specific annotations. Gateway API: portable, using the standard `URLRewrite` filter |

Because the app can serve under a prefix itself, `rewritePath: false` is the simplest setting: the chart's Ingress works anywhere with no annotations. The probes must then use the prefix too, which is what PR #30 fixes.

Changing the default is a breaking change for anyone who relies on today's `true` default with their own rewriting Ingress. It waits for 2.0, so users migrate once (decided 2026-10-26, see the [1.x work plan](../../work/2026-10-26-roadmap-1x/plan.md#decisions)). Until then, the docs and examples set `rewritePath=false` explicitly.

### Values

Added in 4.2 (#115), as proposed here. The old `ingress.*` names map to the new ones: `pathPrefix` wins over `ingress.pathPrefix`, which still needs `ingress.configured`, and a `false` `rewritePath` in either name wins. The install notes list any old names in use.

```yaml
# Serve the app under a path prefix, behind an ingress or gateway
pathPrefix: ""
rewritePath: true          # 1.x default; false from 2.0

service:
  type: LoadBalancer       # 1.x default; ClusterIP considered for 2.0
  port: 80

ingress:
  enabled: false
  className: ""            # e.g. nginx, traefik
  annotations: {}          # controller-specific, e.g. for rewriting
  host: ""
  tls: []

httpRoute:
  enabled: false
  parentRefs: []           # the Gateway(s) to attach to
  hostnames: []
```

Notes:

- **`pathPrefix` and `rewritePath` move to the top level**, because they apply to both the Ingress and the HTTPRoute (and to a user's own Ingress). The chart keeps reading `ingress.pathPrefix`, `ingress.rewritePath` and `ingress.configured` for one major version, then drops them.
- **The default Service type** stays `LoadBalancer` in 1.x, so the quick start must say so. `LoadBalancer` suits the quick start on a cloud cluster, but leaves "EXTERNAL-IP pending" on kind and bare metal (old issues #1/#14), and is wrong behind an ingress or gateway. Switching to `ClusterIP`, with `kubectl port-forward` in the quick start, is a breaking change, so it's considered for 2.0.
- All of these are in `values.schema.json` (4.3, #117). It rejects unknown keys in the parts the chart owns, allows `global`, keeps the old `ingress.*` names valid as deprecated, and requires `message` to be a string (see [site.md](site.md)).

### Example: NGINX

**Without rewriting (recommended).** No annotations, so this works with any NGINX-based controller:

```bash
helm install hello ./hello-kubernetes -n hello-kubernetes --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set pathPrefix=/app/hello \
  --set rewritePath=false
```

**With rewriting**, the annotation depends on which NGINX controller is installed:

- **F5 NGINX Ingress Controller** (`nginx.org`, still maintained): `nginx.org/rewrites: "serviceName=<service> rewrite=/"`, where `<service>` is the chart's Service name.
- **Community Ingress-NGINX** (`nginx.ingress.kubernetes.io`, retired March 2026): rewriting needs a regex path and `rewrite-target`, which the chart's simple prefix path doesn't produce. Use `rewritePath=false` instead, and plan a move off the retired controller.

Check the F5 annotation format against its docs before publishing.

### Example: Traefik

Traefik is the default ingress controller in k3s and k3d, which many users run (see [testing.md](testing.md)).

**Without rewriting (recommended):**

```bash
helm install hello ./hello-kubernetes -n hello-kubernetes --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=traefik \
  --set pathPrefix=/app/hello \
  --set rewritePath=false
```

**With rewriting**, Traefik strips the prefix with a `Middleware`, referenced from an Ingress annotation as `<namespace>-<name>@kubernetescrd`:

```yaml
# strip-prefix.yaml
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-hello
  namespace: hello-kubernetes
spec:
  stripPrefix:
    prefixes:
      - /app/hello
```

```bash
kubectl apply -f strip-prefix.yaml
helm install hello ./hello-kubernetes -n hello-kubernetes \
  --set ingress.enabled=true \
  --set ingress.className=traefik \
  --set pathPrefix=/app/hello \
  --set rewritePath=true \
  --set-string 'ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.middlewares=hello-kubernetes-strip-hello@kubernetescrd'
```

### Example: Gateway API

With the Gateway API, rewriting is part of the standard, so the chart handles it with no controller-specific settings. NGINX Gateway Fabric and Traefik (with its Gateway API provider enabled) both implement `HTTPRoute`; check that the implementation in use supports the `URLRewrite` filter, which is an extended feature.

```bash
helm install hello ./hello-kubernetes -n hello-kubernetes --create-namespace \
  --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=my-gateway' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' \
  --set pathPrefix=/app/hello \
  --set rewritePath=true
```

What the chart renders:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: hello-kubernetes
spec:
  parentRefs:
    - name: my-gateway
      namespace: gateway-system
  rules:
    - matches:
        - path: { type: PathPrefix, value: /app/hello }
      filters:                       # only when rewritePath=true
        - type: URLRewrite
          urlRewrite:
            path: { type: ReplacePrefixMatch, replacePrefixMatch: / }
      backendRefs:
        - name: hello-kubernetes
          port: 80
```

The Gateway must allow routes from the app's namespace (its listener's `allowedRoutes`).

### Testing

[testing.md](testing.md) currently plans ingress tests with Ingress-NGINX on kind and Traefik on k3d. With Ingress-NGINX retired, switch kind to a maintained controller, and add Gateway API scenarios (e.g. NGINX Gateway Fabric on kind, Traefik's Gateway API provider on k3d). Test both `rewritePath` settings on each.

## Kustomize

Kustomize is still widely used. It's built into `kubectl` (`kubectl apply -k`), maintained under Kubernetes SIGs, and common with GitOps tools like Argo CD and Flux.

### Why not a Kustomize version alongside the chart

Two parallel sets of templates means every change is made twice and has to be kept in step, which is the kind of drift behind the current backlog. The chart is small, so Kustomize would add little that Helm doesn't already cover. [GOAL.md](../../GOAL.md) puts a separately maintained Kustomize version out of scope.

### Rendered YAML on each release

From the `helm template` request in `community.md` (#60): render the chart in the release workflow and attach `hello-kubernetes.yaml` to each GitHub release. Then this works without Helm:

```bash
kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
```

Kustomize users can list the same URL as a resource and patch it. It could also replace the `cd deploy/helm` step in the README quick start for people without Helm. Much of the real-world usage found in the review (tutorials, 42-school projects) is plain `kubectl apply`.

Render with release name `demo` and default values (no Ingress or HTTPRoute), so the resources are named `hello-kubernetes-demo` (decided 2026-10-30; the release name `hello-kubernetes` gave `hello-kubernetes-hello-kubernetes`). The chart derives resource names from the release name, and the patches below rely on those names.

## Changing options without Helm

### Example: ingress with Kustomize

The release YAML has no Ingress, so Kustomize users add their own and patch the app to serve under the prefix. This uses `rewritePath: false` behaviour, so the Ingress needs no annotations:

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: hello-kubernetes
resources:
  - https://github.com/paulbouwer/hello-kubernetes/releases/download/v1.11.0/hello-kubernetes.yaml
  - ingress.yaml
patches:
  - target: { kind: Service, name: hello-kubernetes }
    patch: |-
      - op: replace
        path: /spec/type
        value: ClusterIP
  - target: { kind: Deployment, name: hello-kubernetes }
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: { name: HANDLER_PATH_PREFIX, value: /app/hello }
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: { name: RENDER_PATH_PREFIX, value: /app/hello }
      - op: replace
        path: /spec/template/spec/containers/0/livenessProbe/httpGet/path
        value: /app/hello/
      - op: replace
        path: /spec/template/spec/containers/0/readinessProbe/httpGet/path
        value: /app/hello/
```

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-kubernetes
spec:
  ingressClassName: traefik          # or nginx
  rules:
    - http:
        paths:
          - path: /app/hello
            pathType: Prefix
            backend:
              service:
                name: hello-kubernetes
                port:
                  number: 80
```

Then `kubectl apply -k .`. The same pattern covers a custom message, replicas or resources, or an `HTTPRoute` instead of an Ingress.

Caveats:

- 4.5 (#121) ran this, with the release name `demo`, in [docs/deploy-using-kubectl-and-kustomize.md](../../../docs/deploy-using-kubectl-and-kustomize.md). The release URL exists from 1.11.0.
- JSON-patch `env/-` appends to the list. Adding a variable the YAML already has (e.g. `MESSAGE`) creates a duplicate; use a strategic-merge patch for those.

### Chart values and what they change

The Helm templates are currently the only place that says what each value actually does. Anyone not using Helm needs this spelled out in the docs. Covers the proposed values above.

| Chart value | What it changes in the rendered YAML |
|---|---|
| `message` | Adds the `MESSAGE` env var to the container |
| `pathPrefix` | Sets `RENDER_PATH_PREFIX`; the path on the Ingress or HTTPRoute |
| `rewritePath: false` | Also sets `HANDLER_PATH_PREFIX` to `pathPrefix`; probes use the prefix |
| `rewritePath: true` | `HANDLER_PATH_PREFIX` is empty; the HTTPRoute gets a `URLRewrite` filter (Ingress needs annotations) |
| `service.type` | Service `spec.type` |
| `service.port` | Service port (default `80`) |
| `ingress.enabled` | Creates an Ingress |
| `ingress.className`, `host`, `tls`, `annotations` | The Ingress's `ingressClassName`, rule host, `tls` and annotations |
| `httpRoute.enabled` | Creates an HTTPRoute |
| `httpRoute.parentRefs`, `hostnames` | The HTTPRoute's `parentRefs` and `hostnames` |
| `deployment.replicaCount` | Deployment `spec.replicas` |
| `deployment.container.image.*` | Container `image` and `imagePullPolicy`, plus the `CONTAINER_IMAGE` env var |
| `deployment.container.port` | `containerPort`, and a `PORT` env var when it isn't `8080` |
| `deployment.resources`, `nodeSelector`, `tolerations`, `affinity` | Copied as-is into the pod spec |

Update this table whenever the chart changes, e.g. when `securityContext` is added.

### How much to ship

From least to most upkeep:

1. **Docs only (recommended).** A "Customising without Helm" page with the example and table above.
2. **A few pre-rendered variants**, e.g. `hello-kubernetes.yaml` and `hello-kubernetes-ingress.yaml`, generated by CI with `helm template --set ...`. Cheap because they're generated, but they only cover the combinations chosen, and each new option can double the number of files.
3. **Kustomize components in the repo** (`deploy/kustomize/components/ingress`, …). These are hand-written and must be kept in step with the chart, which [GOAL.md](../../GOAL.md) rules out.
