# Deploy with ingress

The `hello-kubernetes` Helm chart can be used to deploy and configure the `hello-kubernetes` application for use with an ingress controller. 

> **Note:**
> 
> The `hello-kubernetes` Helm chart does **not** deploy an [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) and does **not** deploy the [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) definition.
>
> The chart aims to support deployment to as many platforms and providers as possible, so the choice of Ingress Controller and configuration of Ingress resource is left to the person deploying.

## Prerequisites

- [Helm 3](https://v3.helm.sh/)

## Install ingress controller

Install an [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) that is available for your platform or provider. Here is an example that uses the [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/) on a cloud provider:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm install nginx-ingress ingress-nginx/ingress-nginx \
    --create-namespace --namespace ingress \
    --set controller.replicaCount=2
```

## Use hello-kubernetes with ingress

### Deploy hello-kubernetes instances

Install two `hello-kubernetes` instances that will be available via 2 different paths on the ingress. 

The `hello-world` instance will display the default "Hello world!" message, and the `custom-message` instance will display a "This is my custom message!" message.

```bash
helm install --create-namespace --namespace hello-kubernetes hello-kubernetes ./hello-kubernetes \
  --set ingress.enabled=true --set ingress.pathPrefix="/hello-kubernetes" \
  --set service.type=ClusterIP

helm install --create-namespace --namespace custom-message custom-message ./hello-kubernetes \
  --set ingress.enabled=true --set ingress.pathPrefix="/custom-message" \
  --set service.type=ClusterIP \
  --set message="This is my custom message!"
```

### Deploy ingress definition

The `hello-kubernetes` Helm chart has a `ingress.rewritePath` configuration parameter that is `true` by default. When used together with the `ingress.enabled=true` configuration parameter, there is an assumption that the ingress being used supports path rewrites. See the [Deploy using Helm](deploy-using-helm.md) guidance for more details.

So from our example, a request to `/hello-world` should be rewritten to `/` before being passed to the `hello-world` app instance.

The default ingress definition provided by this chart will be serviced by the nginx ingress controller due to the `kubernetes.io/ingress.class: nginx` annotation. It will also leverage the path rewrite capabilities of nginx via the `nginx.ingress.kubernetes.io/rewrite-target: /$2` annotation.

### Browse

You can browse to each of the `hello-kubernetes` apps via the $INGRESS_CONTROLLER_IPADDRESS and each of the configured paths. So for our example at:

- `$INGRESS_CONTROLLER_IPADDRESS/hello-kubernetes` - the `hello-kubernetes` instance with the default "Hello Kubernetes!" message
- `$INGRESS_CONTROLLER_IPADDRESS/custom-message` - the `custom-message` instance with the "This is my custom message!" message

## Alternatives

You can deploy the `hello-kubernetes` app via the Helm chart with the `ingress.rewritePath=false` configuration parameter if you are deploying with an ingress controller that does not support path rewrites.

In this case, the `hello-kubernetes` apps will serve dynamic content and static assets from the path defined by the `ingress.pathPrefix` configuration parameter.
