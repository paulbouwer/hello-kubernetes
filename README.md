# Hello Kubernetes!

[![Docker Image Version (latest semver)](https://img.shields.io/docker/v/paulbouwer/hello-kubernetes?sort=semver)](https://hub.docker.com/r/paulbouwer/hello-kubernetes) [![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/paulbouwer/hello-kubernetes?sort=semver)](https://hub.docker.com/r/paulbouwer/hello-kubernetes) [![Docker Pulls](https://img.shields.io/docker/pulls/paulbouwer/hello-kubernetes)](https://hub.docker.com/r/paulbouwer/hello-kubernetes) [![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/hello-kubernetes)](https://artifacthub.io/packages/search?repo=hello-kubernetes)

hello-kubernetes is a small web app to deploy on a Kubernetes cluster. Its page shows:

- a message, **Hello world!** by default
- the namespace, pod and node it runs on
- the container image and its architecture

![Hello world! from the hello-kubernetes image](hello-kubernetes.png)

The image runs on `linux/amd64` and `linux/arm64` nodes, as a non-root user. It is on Docker Hub as `paulbouwer/hello-kubernetes` and on GHCR as `ghcr.io/paulbouwer/hello-kubernetes`.

**Documentation: [paulbouwer.github.io/hello-kubernetes](https://paulbouwer.github.io/hello-kubernetes/)**

## Quick start

Deploy it into your current namespace with `kubectl`, from the release file:

```bash e2e
kubectl apply -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
kubectl rollout status deployment/hello-kubernetes-demo
```

Reach it on `http://localhost:8080/`:

```bash
kubectl port-forward service/hello-kubernetes-demo 8080:80
```

You see **Hello world!**, and the pod that answered. Remove it:

```bash e2e
kubectl delete -f https://github.com/paulbouwer/hello-kubernetes/releases/latest/download/hello-kubernetes.yaml
```

To deploy with Helm, behind an Ingress or a Gateway, or with Kustomize, see the [documentation](https://paulbouwer.github.io/hello-kubernetes/docs/start-here/overview/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The repo has a [devcontainer](docs/development-environment.md) with every tool at a known version, and [docs/](docs/) has the contributor docs.
