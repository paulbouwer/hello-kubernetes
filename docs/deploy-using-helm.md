# Deploy using Helm

The `hello-kubernetes` Helm chart can be used to deploy the `hello-kubernetes` application. The chart will deploy the following resources:

- ServiceAccount
- Service
- Deployment

## Prerequisites

- [Helm 4](https://helm.sh/docs/intro/install/)

If you are using the [VS Code Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) based development environment, all of the prerequisites will be available in the terminal.

## Configuration and installation

The following table lists the configuration parameters of the hello-kubernetes chart and their default values.

Helm checks your values against the chart's `values.schema.json` on every install and upgrade. A misspelled or unknown key, a wrong type or a value that isn't allowed stops the install, with a message that names the value. Editors that read JSON Schema show each value's description and allowed values.

| Parameter | Type | Default | Description |
| --------- | ---- | ------- | ----------- |
| `message` | `string` | `""` | A custom message to display instead of the default. It must be a string: quote it in a values file, or use `--set-string message=42`, even when it is only a number. |
| `pathPrefix` | `string` | `""` | Serve the app under a path prefix, for example `/app/hello`, behind an Ingress, an HTTPRoute or your own proxy. |
| `rewritePath` | `bool` | `true` | `true`: the proxy strips the prefix, and the app serves at `/`. `false` (recommended): the proxy passes the prefix on, and the app serves under it, with no Ingress annotations needed. |
| `ingress.enabled` | `bool` | `false` | Create a `networking.k8s.io/v1` Ingress for `pathPrefix`. Set `service.type` to `ClusterIP` with it. |
| `ingress.className` | `string` | `""` | The Ingress class, for example `nginx` or `traefik`. |
| `ingress.annotations` | `object` | `{}` | Annotations for the Ingress, for example a controller's rewrite annotation when `rewritePath` is `true`. |
| `ingress.host` | `string` | `""` | The host name for the Ingress rule. All hosts when empty. |
| `ingress.tls` | `list` | `[]` | The Ingress TLS settings. |
| `httpRoute.enabled` | `bool` | `false` | Create a Gateway API `HTTPRoute` for `pathPrefix`. With `rewritePath` `true`, it strips the prefix with the standard `URLRewrite` filter. |
| `httpRoute.parentRefs` | `list` | `[]` | The Gateways to attach to. Required when `httpRoute.enabled` is `true`. |
| `httpRoute.hostnames` | `list` | `[]` | The host names for the route. |
| `ingress.configured`, `ingress.pathPrefix`, `ingress.rewritePath` | | | Deprecated. They still work in 1.x, and are removed in 2.0. Use `pathPrefix` and `rewritePath`. |
| `service.type` | `string` | `"LoadBalancer"` | The service type. |
| `service.port` | `int` | `80` | The port exposed by the service. |
| `deployment.replicaCount` | `int` | `2` | The number of replicas for the hello-kubernetes deployment. |
| `deployment.container.image.repository` | `string` | `paulbouwer/hello-kubernetes` | The container image to run in the  hello-kubernetes pods. |
| `deployment.container.image.tag` | `string` or `number` | `""` | The container image tag. If not specified, the chart's appVersion is used. |
| `deployment.container.image.pullPolicy` | `string` | `"IfNotPresent"` | The pull policy for the container image. |
| `deployment.container.port` | `int` | `"8080"` | The port that hello-kubernetes app listens on. |
| `deployment.container.securityContext` | `object` | `{"allowPrivilegeEscalation":false, "readOnlyRootFilesystem":true, "capabilities":{"drop":["ALL"]}}` | The container security context. With `deployment.podSecurityContext`, it meets the restricted Pod Security Standard. |
| `deployment.podSecurityContext` | `object` | `{"runAsNonRoot":true, "runAsUser":1000, "runAsGroup":1000, "seccompProfile":{"type":"RuntimeDefault"}}` | The pod security context. The app runs as the numeric user 1000. |
| `deployment.nodeSelector` | `object` | `{"kubernetes.io/os":"linux"}` | The node selector for the deployment. The image runs on `amd64` and `arm64` nodes. |
| `deployment.resources` | `object` | `{}` | The resource limits for the deployment. |
| `deployment.tolerations` | `object` | `[]` | The tolerations for the deployment. |
| `deployment.affinity` | `object` | `{}` | The affinity for the deployment. |

### Installing the chart

Ensure that you are in the chart directory in the repo, since the instructions reference a local helm chart.

```bash
cd deploy/helm
```

To install `hello-kubernets` via the Helm chart, use the following to:
- create the hello-kubernetes namespace if it doesn't exist
- deploy the chart located in the ./hello-kubernetes folder into the hello-kubernetes namespace
- create a Helm release named hello-world

```bash
helm install --create-namespace --namespace hello-kubernetes hello-world ./hello-kubernetes
```

You can override the values for the configuration parameter defined in the table above, either directly in the `hello-kubernetes/values.yaml` file, or via the `--set` switches.

```bash
helm install --create-namespace --namespace hello-kubernetes custom-message ./hello-kubernetes \
  --set message="I just deployed this on Kubernetes!"
```

### Upgrading the chart

Ensure that you are in the chart directory in the repo, since the instructions reference a local helm chart.

```bash
cd deploy/helm
```

You can modify the `hello-kubernetes` app by providing new values for the configuration parameter defined in the table above, either directly in the `hello-kubernetes/values.yaml` file, or via the `--set` switches.

```bash
helm upgrade --namespace hello-kubernetes custom-message ./hello-kubernetes \
  --set message="This is a different message"
```

### Uninstalling the chart

You can uninstall the `hello-kubernetes` app as follows:

```bash
helm uninstall --namespace hello-kubernetes custom-message
```