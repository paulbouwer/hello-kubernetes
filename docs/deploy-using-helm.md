# Deploy using Helm

The hello-kubernetes Helm chart creates:

- a ServiceAccount
- a Service, `LoadBalancer` by default
- a Deployment with 2 pods
- an Ingress or a Gateway API HTTPRoute, if you turn one on (see [Deploy with an Ingress or a Gateway](deploy-with-ingress.md))

Every resource is named `hello-kubernetes-<release name>`.

## Prerequisites

- [Helm 4](https://helm.sh/docs/intro/install/)
- `kubectl`, and a cluster to install into

The [development environment](development-environment.md) has both.

## Install

The chart is published on GHCR as an OCI artifact, with the same version as the app and the image. It is also listed on [Artifact Hub](https://artifacthub.io/packages/search?repo=hello-kubernetes).

```bash
helm install hello-world oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes --create-namespace \
  --wait
```

You see `STATUS: deployed`, and notes that say how to reach the app for the Service type you chose.

To install a specific version, add `--version`, for example `--version 1.11.0`. Without it, Helm installs the newest release.

Set values with `--set` or with a values file:

```bash
helm install custom-message oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes --create-namespace \
  --set-string message="I just deployed this on Kubernetes!" \
  --set service.type=ClusterIP \
  --wait
kubectl port-forward service/hello-kubernetes-custom-message 8080:80 --namespace hello-kubernetes
```

Open `http://localhost:8080/`. You see **I just deployed this on Kubernetes!**.

Helm checks your values against the chart's `values.schema.json` on every install and upgrade. A misspelled or unknown key, a wrong type or a value that isn't allowed stops the install, with a message that names the value, for example `additional properties 'pathPrefx' not allowed`. Editors that read JSON Schema show each value's description and allowed values.

## Upgrade

Change a value, or move to a newer chart, with `helm upgrade`. `--reuse-values` keeps the values you set before:

```bash
helm upgrade custom-message oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes --reuse-values \
  --set-string message="Upgraded!" \
  --wait
```

The pods are replaced one at a time, and the page then shows **Upgraded!**.

## Uninstall

```bash
helm uninstall hello-world --namespace hello-kubernetes
helm uninstall custom-message --namespace hello-kubernetes
kubectl delete namespace hello-kubernetes
```

`helm list --all-namespaces` shows the releases, if you don't remember their names.

## Values

| Value | Type | Default | Description |
|---|---|---|---|
| `message` | string | `""` | A message to show instead of **Hello world!**. It must be a string: quote it in a values file, or use `--set-string`. |
| `pathPrefix` | string | `""` | Serve the app under a path prefix, such as `/app/hello`, behind an Ingress, an HTTPRoute or your own proxy. Leading and trailing slashes are optional. |
| `rewritePath` | bool | `true` | `false` (recommended): the proxy passes the prefix on, and the app serves under it. `true`: the proxy strips the prefix, and the app serves at `/`. See [Deploy with an Ingress or a Gateway](deploy-with-ingress.md). |
| `ingress.enabled` | bool | `false` | Create a `networking.k8s.io/v1` Ingress for `pathPrefix`. |
| `ingress.className` | string | `""` | The Ingress class, such as `nginx` or `traefik`. Empty uses the cluster's default class. |
| `ingress.annotations` | object | `{}` | Annotations for the Ingress, such as your controller's rewrite annotation when `rewritePath` is `true`. |
| `ingress.host` | string | `""` | The host name for the Ingress rule. Empty matches all hosts, but the NGINX Ingress Controller needs a host. |
| `ingress.tls` | list | `[]` | The Ingress TLS settings, as in the Ingress `spec.tls` field. |
| `httpRoute.enabled` | bool | `false` | Create a Gateway API `HTTPRoute` for `pathPrefix`. With `rewritePath` `true`, it strips the prefix with the standard `URLRewrite` filter. |
| `httpRoute.parentRefs` | list | `[]` | The Gateways to attach to. Required when `httpRoute.enabled` is `true`. |
| `httpRoute.hostnames` | list | `[]` | The host names for the route. Empty matches the Gateway's host names. |
| `service.type` | string | `LoadBalancer` | `ClusterIP`, `NodePort` or `LoadBalancer`. Use `ClusterIP` behind an Ingress or a Gateway. |
| `service.port` | int | `80` | The port the Service exposes. |
| `deployment.replicaCount` | int | `2` | The number of pods. |
| `deployment.container.image.repository` | string | `paulbouwer/hello-kubernetes` | The image, such as `ghcr.io/paulbouwer/hello-kubernetes`. |
| `deployment.container.image.tag` | string or number | `""` | The image tag. Empty uses the chart's `appVersion`. |
| `deployment.container.image.pullPolicy` | string | `IfNotPresent` | `Always`, `IfNotPresent` or `Never`. |
| `deployment.container.port` | int | `8080` | The port the app listens on. The probes and the Service follow it. |
| `deployment.container.securityContext` | object | no privilege escalation, all capabilities dropped, read-only root filesystem | The container security context. With `deployment.podSecurityContext`, it meets the restricted Pod Security Standard. |
| `deployment.podSecurityContext` | object | `runAsNonRoot`, user and group `1000`, `RuntimeDefault` seccomp | The pod security context. |
| `deployment.nodeSelector` | object | `kubernetes.io/os: linux` | The node selector. The image runs on `amd64` and `arm64` nodes. |
| `deployment.resources` | object | `{}` | The container resource requests and limits. |
| `deployment.tolerations` | list | `[]` | The pod tolerations. |
| `deployment.affinity` | object | `{}` | The pod affinity. |
| `ingress.configured`, `ingress.pathPrefix`, `ingress.rewritePath` | | | Deprecated. They still work in 1.x, and the install notes list them. Use `pathPrefix` and `rewritePath`. They are removed in 2.0. |

To see the descriptions and defaults from the chart itself:

```bash
helm show values oci://ghcr.io/paulbouwer/charts/hello-kubernetes
```

## Check the chart's signature

Each chart version has signed provenance from this repo's release workflow. `helm pull` prints the chart's digest, which `gh attestation verify` checks:

```bash
helm pull oci://ghcr.io/paulbouwer/charts/hello-kubernetes --version 1.11.0
gh attestation verify oci://ghcr.io/paulbouwer/charts/hello-kubernetes@<digest> --repo paulbouwer/hello-kubernetes
```
