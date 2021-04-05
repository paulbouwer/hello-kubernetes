# Deploy using Helm

The `hello-kubernetes` Helm chart can be used to deploy the `hello-kubernetes` application. The chart will deploy the following resources:

- ServiceAccount
- Service
- Deployment

## Prerequisites

- [Helm 3](https://v3.helm.sh/)

If you are using the [VS Code Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) based development environment, all of the prerequisites will be available in the terminal.

## Configuration and installation

The following table lists the configuration parameters of the hello-kubernetes chart and their default values.

| Parameter | Type | Default | Description |
| --------- | ---- | ------- | ----------- |
| `message` | `string` | `""` | A custom message to display instead of the default. |
| `ingress.configured` | `bool` | `false` | Indicates whether an ingress has been configured in the cluster. <br/>Note: this chart will not install or configure an ingress. You will need to install an ingress controller and add ingress record to the app namespace. |
| `ingress.rewritePath` | `bool` | `true` | Indicates whether pathPrefix is rewritten by the ingress. <br/> If this is set to `true` then the hello-kubernetes dynamic content and static assets will be served from `/`, otherwise, they will be served from `/$pathPrefix`. |
| `ingress.pathPrefix` | `string` | `""` | The path prefix configured in the ingress for the hello-kubernetes service.<br/> Must be provided when ingress is used. |
| `service.type` | `string` | `"LoadBalancer"` | The service type. |
| `service.port` | `int` | `80` | The port exposed by the service. |
| `deployment.replicaCount` | `int` | `2` | The number of replicas for the hello-kubernetes deployment. |
| `deployment.container.image.repository` | `string` | `paulbouwer/hello-kubernetes` | The container image to run in the  hello-kubernetes pods. |
| `deployment.container.image.tag` | `string` | `""` | The container image tag. If not specified, the chart's appVersion is used. |
| `deployment.container.image.pullPolicy` | `string` | `"IfNotPresent"` | The pull policy for the container image. |
| `deployment.container.port` | `int` | `"8080"` | The port that hello-kubernetes app listens on. |
| `deployment.nodeSelector` | `object` | `{"kubernetes.io/os":"linux", "kubernetes.io/arch":"amd64"}` | The node selector for the deployment. |
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