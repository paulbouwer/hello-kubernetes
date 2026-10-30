# Deploy using kubectl and Kustomize

Each release has `hello-kubernetes.yaml`: the [Helm chart](deploy-using-helm.md) rendered with its default values and the release name `demo`. Use it with `kubectl` alone, or as a base for Kustomize, which is built into `kubectl`. You don't need Helm.

## What the file creates

| Resource | Name | Notes |
|---|---|---|
| ServiceAccount | `hello-kubernetes-demo` | |
| Service | `hello-kubernetes-demo` | `LoadBalancer`, port `80` |
| Deployment | `hello-kubernetes-demo` | 2 pods, the image `paulbouwer/hello-kubernetes` at the release's version, user `1000`, a read-only root filesystem, and the restricted Pod Security settings |

The file sets no namespace, so it goes into your current namespace, or the one you give with `--namespace`.

## Apply it

```bash
kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
kubectl rollout status deployment/hello-kubernetes-demo
kubectl get service hello-kubernetes-demo
```

You see `deployment "hello-kubernetes-demo" successfully rolled out`, then the Service with its `EXTERNAL-IP`. Open `http://<EXTERNAL-IP>/`. You see **Hello world!**.

`latest` follows the newest release. To keep one version, use its URL, for example `https://github.com/paulbouwer/hello-kubernetes/releases/download/v1.11.0/hello-kubernetes.yaml`.

### Where the external address works

| Cluster | Result |
|---|---|
| Cloud clusters, such as EKS, GKE and AKS | Works. You get a public address, and your cloud may charge for the load balancer. |
| Docker Desktop, OrbStack | Works. The address is `localhost`. |
| k3s, k3d, Rancher Desktop | `EXTERNAL-IP` stays `<pending>`, because their built-in Traefik already uses port 80. The app still runs. To give it its own address, patch the Service port to `8080` with Kustomize (below); with k3d, also create the cluster with `-p "8080:8080@loadbalancer"`. |
| kind, minikube, bare metal | `EXTERNAL-IP` stays `<pending>`. The app still runs. |

Where `EXTERNAL-IP` stays `<pending>`, forward a local port:

```bash
kubectl port-forward service/hello-kubernetes-demo 8080:80
```

Open `http://localhost:8080/`. You see **Hello world!**. Press Ctrl+C to stop.

### Remove it

```bash
kubectl delete -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
```

## Change it with Kustomize

Use the release file as a base, and patch what you need. Kustomize applies the result with `kubectl apply -k`.

### Example: a namespace, a message and ClusterIP

Create a folder with this `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: hello
resources:
  - namespace.yaml
  - https://github.com/paulbouwer/hello-kubernetes/releases/download/v1.11.0/hello-kubernetes.yaml
patches:
  - target: { kind: Service, name: hello-kubernetes-demo }
    patch: |-
      - op: replace
        path: /spec/type
        value: ClusterIP
  - target: { kind: Deployment, name: hello-kubernetes-demo }
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value: { name: MESSAGE, value: "Deployed with Kustomize" }
```

and this `namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: hello
```

Then apply it, and reach the app:

```bash
kubectl apply -k .
kubectl rollout status deployment/hello-kubernetes-demo --namespace hello
kubectl port-forward service/hello-kubernetes-demo 8080:80 --namespace hello
```

Open `http://localhost:8080/`. You see **Deployed with Kustomize**, from one of 3 pods. Remove it with `kubectl delete -k .`.

### Example: a load balancer on port 8080, for k3s, k3d and Rancher Desktop

Their built-in Traefik already uses port 80. Keep the `LoadBalancer` Service, and move it to port 8080:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - https://github.com/paulbouwer/hello-kubernetes/releases/download/v1.11.0/hello-kubernetes.yaml
patches:
  - target: { kind: Service, name: hello-kubernetes-demo }
    patch: |-
      - op: replace
        path: /spec/ports/0/port
        value: 8080
```

Apply it with `kubectl apply -k .`. `kubectl get service hello-kubernetes-demo` then shows an `EXTERNAL-IP`, and the app is at `http://<EXTERNAL-IP>:8080/`. With k3d, create the cluster with `-p "8080:8080@loadbalancer"`, and open `http://localhost:8080/`.

### Example: an Ingress

The release file has no Ingress. Add your own, and patch the app to serve under the prefix. This passes the prefix on, as `rewritePath: false` does in the chart, so the Ingress needs no annotations.

Add `ingress.yaml` to the folder:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-kubernetes-demo
spec:
  ingressClassName: traefik # or nginx, which also needs a host: below
  rules:
    - http:
        paths:
          - path: /app/hello
            pathType: Prefix
            backend:
              service:
                name: hello-kubernetes-demo
                port:
                  number: 80
```

and use this `kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: hello
resources:
  - namespace.yaml
  - https://github.com/paulbouwer/hello-kubernetes/releases/download/v1.11.0/hello-kubernetes.yaml
  - ingress.yaml
patches:
  - target: { kind: Service, name: hello-kubernetes-demo }
    patch: |-
      - op: replace
        path: /spec/type
        value: ClusterIP
  - target: { kind: Deployment, name: hello-kubernetes-demo }
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

Apply it with `kubectl apply -k .`, and open `http://<ingress address>/app/hello/`. You see **Hello world!**. The same pattern adds an `HTTPRoute` instead of an Ingress.

`op: add` with `env/-` adds to the end of the list. The release file already sets `KUBERNETES_NAMESPACE`, `KUBERNETES_POD_NAME`, `KUBERNETES_NODE_NAME` and `CONTAINER_IMAGE`. To change one of those, use `op: replace` on its position instead, or a strategic merge patch.

## What each chart value changes

To make a change that the chart has a value for, without Helm, change the YAML like this:

| Chart value | What it changes in the YAML |
|---|---|
| `message` | Adds the `MESSAGE` env var to the container |
| `pathPrefix` | Sets `RENDER_PATH_PREFIX`; the path on the Ingress or HTTPRoute |
| `rewritePath: false` | Also sets `HANDLER_PATH_PREFIX` to `pathPrefix`; the probes use `<pathPrefix>/` |
| `rewritePath: true` | Sets `HANDLER_PATH_PREFIX` to `""`; the HTTPRoute gets a `URLRewrite` filter; an Ingress needs your controller's annotation |
| `service.type`, `service.port` | The Service `spec.type` and port |
| `ingress.*` | Creates an Ingress, with the class, host, TLS and annotations |
| `httpRoute.*` | Creates an HTTPRoute, with the parent refs and host names |
| `deployment.replicaCount` | The Deployment `spec.replicas` |
| `deployment.container.image.*` | The container `image` and `imagePullPolicy`, and the `CONTAINER_IMAGE` env var |
| `deployment.container.port` | The `containerPort`, the probes' port, and a `PORT` env var when it isn't `8080` |
| `deployment.container.securityContext` | The container `securityContext` |
| `deployment.podSecurityContext` | The pod `securityContext` |
| `deployment.resources`, `nodeSelector`, `tolerations`, `affinity` | Copied into the pod spec as they are |

The root filesystem is read-only, so the Deployment mounts an `emptyDir` at `/tmp`. Keep it if you change the security settings.
