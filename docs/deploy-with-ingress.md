# Deploy with an Ingress or a Gateway

The chart can create an [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) or a [Gateway API](https://gateway-api.sigs.k8s.io/) `HTTPRoute` for the app, under a path prefix such as `/app/hello`. Several releases can then share one address, each under its own path.

You bring the Ingress controller or the Gateway. The chart doesn't install either, because the right one depends on your cluster.

## Prerequisites

- [Helm 4](https://helm.sh/docs/intro/install/) and `kubectl`
- For an Ingress: an Ingress controller, such as the [NGINX Ingress Controller](https://docs.nginx.com/nginx-ingress-controller/) or [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-ingress/). Traefik is built into k3s and k3d.
- For an HTTPRoute: a Gateway API implementation, such as [NGINX Gateway Fabric](https://docs.nginx.com/nginx-gateway-fabric/) or [Traefik](https://doc.traefik.io/traefik/providers/kubernetes-gateway/), and a `Gateway` that accepts routes from the app's namespace.

The community Ingress-NGINX controller (`kubernetes/ingress-nginx`) was retired in March 2026. The Ingress API itself is stable and still supported.

## Path prefixes and rewriting

Behind a prefix, either the proxy strips the prefix before it passes a request on, or the app serves under the prefix itself:

| `rewritePath` | The proxy | The app | Works with |
|---|---|---|---|
| `false` (recommended) | passes `/app/hello/...` on unchanged | serves under `/app/hello` | every Ingress controller and Gateway, with no annotations |
| `true` (the 1.x default) | strips `/app/hello` | serves at `/`, and links its assets under `/app/hello` | an HTTPRoute, which uses the standard `URLRewrite` filter; an Ingress needs your controller's rewrite annotation |

Set `rewritePath=false` unless you have a reason not to. The default changes to `false` in 2.0.

Behind an Ingress or a Gateway, set `service.type=ClusterIP`. The Ingress or the Gateway reaches the Service inside the cluster, and a `LoadBalancer` Service would give the app a second, public address that bypasses them.

## Ingress

### Without rewriting (recommended)

Install two releases, each under its own path. Set `ingress.className` to your controller's class: `nginx` for the NGINX Ingress Controller, or `traefik` for Traefik.

```bash
helm install hello-world oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes --create-namespace \
  --set ingress.enabled=true --set ingress.className=traefik \
  --set pathPrefix=/app/hello-world --set rewritePath=false \
  --set service.type=ClusterIP \
  --wait

helm install custom-message oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes \
  --set ingress.enabled=true --set ingress.className=traefik \
  --set pathPrefix=/app/custom-message --set rewritePath=false \
  --set service.type=ClusterIP \
  --set-string message="This is my custom message!" \
  --wait

kubectl get ingress --namespace hello-kubernetes
```

You see two Ingresses, `hello-kubernetes-hello-world` and `hello-kubernetes-custom-message`, with your controller's address. Open:

- `http://<ingress address>/app/hello-world/`: **Hello world!**
- `http://<ingress address>/app/custom-message/`: **This is my custom message!**

To use a host name, add `--set ingress.host=hello.example.com`. For TLS, add `ingress.tls` in a values file, as in the Ingress `spec.tls` field.

### With rewriting

With `rewritePath=true`, the controller must strip the prefix. That needs an annotation, which is different for each controller.

**Traefik** strips a prefix with a `Middleware`, which the Ingress names in an annotation as `<namespace>-<middleware name>@kubernetescrd`:

```bash
kubectl apply -f - <<'EOF'
apiVersion: traefik.io/v1alpha1
kind: Middleware
metadata:
  name: strip-hello
  namespace: hello-kubernetes
spec:
  stripPrefix:
    prefixes:
      - /app/hello
EOF

helm install hello oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes \
  --set ingress.enabled=true --set ingress.className=traefik \
  --set pathPrefix=/app/hello \
  --set-string 'ingress.annotations.traefik\.ingress\.kubernetes\.io/router\.middlewares=hello-kubernetes-strip-hello@kubernetescrd' \
  --set service.type=ClusterIP \
  --wait
```

Open `http://<ingress address>/app/hello/`. You see **Hello world!**.

**NGINX:** use `rewritePath=false`, as above. It needs no annotation, and works with any NGINX-based controller.

## Gateway API

An `HTTPRoute` attaches to a `Gateway` that you name in `httpRoute.parentRefs`. The Gateway's listener must allow routes from the app's namespace (`allowedRoutes`).

With `rewritePath=true`, the route strips the prefix with the standard `URLRewrite` filter, so it needs no settings for your Gateway implementation. `URLRewrite` is an extended Gateway API feature: check that your implementation supports it, or use `rewritePath=false`.

```bash
helm install hello-world oci://ghcr.io/paulbouwer/charts/hello-kubernetes \
  --namespace hello-kubernetes --create-namespace \
  --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=my-gateway' \
  --set 'httpRoute.parentRefs[0].namespace=gateway-system' \
  --set pathPrefix=/app/hello-world \
  --set service.type=ClusterIP \
  --wait

kubectl get httproute --namespace hello-kubernetes
```

You see the route `hello-kubernetes-hello-world`. Open `http://<gateway address>/app/hello-world/`. You see **Hello world!**.

Add `--set rewritePath=false` to pass the prefix on instead, and `--set 'httpRoute.hostnames[0]=hello.example.com'` for a host name.

### Example: Traefik's Gateway on k3s or k3d

k3s and k3d include the Gateway API resources, and Traefik can serve them. Turn on Traefik's Gateway API provider, and let its Gateway accept routes from every namespace:

```bash
kubectl apply -f - <<'EOF'
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesGateway:
        enabled: true
    gateway:
      listeners:
        web:
          namespacePolicy:
            from: All
EOF
until kubectl get gateway traefik-gateway --namespace kube-system >/dev/null 2>&1; do sleep 5; done
kubectl wait gateway/traefik-gateway --namespace kube-system --for=condition=Programmed --timeout=180s
```

You see `gateway.gateway.networking.k8s.io/traefik-gateway condition met`. Install the chart with `httpRoute.parentRefs[0].name=traefik-gateway` and `httpRoute.parentRefs[0].namespace=kube-system`. With k3d, create the cluster with `-p "8080:80@loadbalancer"`, and the address is `localhost:8080`.

## Clean up

Uninstall every release in the namespace, then delete it:

```bash
helm list --namespace hello-kubernetes --short | xargs helm uninstall --namespace hello-kubernetes
kubectl delete namespace hello-kubernetes
```

For the Traefik rewrite example, the namespace delete also removes the `Middleware`.

## Moving from the old values

Before 1.11, the chart didn't create an Ingress: you wrote your own, and set `ingress.configured`, `ingress.pathPrefix` and `ingress.rewritePath`. These still work in 1.x, and the install notes list them as deprecated. They are removed in 2.0.

| Old value | New value |
|---|---|
| `ingress.configured=true` | Not needed. Set `pathPrefix`, and `ingress.enabled=true` or `httpRoute.enabled=true` for the chart to create the route. |
| `ingress.pathPrefix` | `pathPrefix` |
| `ingress.rewritePath` | `rewritePath` |

If you keep your own Ingress, set only `pathPrefix` and `rewritePath`, and point your Ingress at the Service `hello-kubernetes-<release name>`, port `80`.
