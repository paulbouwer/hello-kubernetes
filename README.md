# Hello Kubernetes!

This image can be deployed on a Kubernetes cluster. It displays a default **Hello world!** message, the name of the pod it was deployed to, and some os information about the node the pod was deployed to.

The message displayed can be overridden using the `MESSAGE` environment variable.

## DockerHub

It is available on DockerHub as:

- [paulbouwer/hello-kubernetes:1.4](https://hub.docker.com/r/paulbouwer/hello-kubernetes/)

## Deploy

You can deploy the image to your Kubernetes cluster one of two ways:

Deploy using the hello-kubernetes.yaml, which contains definitions for the service and deployment objects:

```yaml
# hello-kubernetes.yaml

apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: hello-kubernetes
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hello-kubernetes
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: hello-kubernetes
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.4                
        ports:
        - containerPort: 8080
```

```bash
$ kubectl apply -f yaml/hello-kubernetes.yaml
```

Or, deploy by executing the following `run` and `expose` commands on `kubectl`. 

```bash
$ kubectl run hello-kubernetes --replicas=3 --image=paulbouwer/hello-kubernetes:1.4 --port=8080
$ kubectl expose deployment hello-kubernetes --type=LoadBalancer --port=80 --target-port=8080 --name=hello-kubernetes
```

This will display a **Hello world!** message when you hit the service endpoint in a browser. You can get the service endpoint ip address by executing the following command and grabbing the returned external ip address value:

```bash
$ kubectl get service hello-kubernetes
```

## Custom Message

You can customise the message displayed by the `hello-kubernetes` container as follows:

Deploy using the hello-kubernetes.custom-message.yaml, which contains definitions for the service and deployment objects:

In the definition for the deployment, add an `env` variable with a name of `MESSAGE`. The value you provide will be displayed as the custom message.

```yaml
# hello-kubernetes.custom-message.yaml

apiVersion: v1
kind: Service
metadata:
  name: hello-kubernetes-custom
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: hello-kubernetes-custom
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: hello-kubernetes-custom
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: hello-kubernetes-custom
    spec:
      containers:
      - name: hello-kubernetes
        image: paulbouwer/hello-kubernetes:1.4                
        ports:
        - containerPort: 8080
        env:
        - name: MESSAGE
          value: I just deployed this on Kubernetes!
```

```bash
$ kubectl apply -f yaml/hello-kubernetes.custom-message.yaml
```

Or, deploy by executing the following `run` and `expose` commands on `kubectl`, with the environment variable `MESSAGE` provided as part of the `run` command.

```bash
$ kubectl run hello-kubernetes --replicas=3 --image=paulbouwer/hello-kubernetes:1.4 --port=8080 --env="MESSAGE=I just deployed this on Kubernetes!"
$ kubectl expose deployment hello-kubernetes --type=LoadBalancer --port=80 --target-port=8080 --name=hello-kubernetes
```

## Build

If you'd like to build the image yourself, then you can do so as follows. The `build-arg` parameters provide values to the Docker image labels which follow the [Label Schema](http://label-schema.org/rc1/) convention.

Bash
```bash
$ docker build --no-cache --build-arg IMAGE_VERSION="1.4" --build-arg BUILD_DATE="`date -u +"%Y-%m-%dT%H:%M:%SZ"`" --build-arg VCS_REF="`git rev-parse HEAD`" -f Dockerfile -t "hello-kubernetes:1.4" .
```

Powershell
```powershell
PS> docker build --no-cache --build-arg IMAGE_VERSION="1.4" --build-arg BUILD_DATE="$(Get-Date((Get-Date).ToUniversalTime()) -UFormat '%Y-%m-%dT%H:%M:%SZ')" --build-arg VCS_REF="$(git rev-parse HEAD)" -f Dockerfile -t "hello-kubernetes:1.4" .
```