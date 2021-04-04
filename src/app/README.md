# Hello Kubernetes demo app

A demo app that can be deployd to a Kubernetes cluster. It displays a message, the name of the pod and details of the node it's deployed to.

## Paths

| Method | Path | Description |
| -------| ---- | ----------- |
| GET    | /    | Displays message, pod and node details |

## Configuration

The application can be configured via the following environment variables.

| Env | Required | Default Value | Description |
| --- | -------- | ------------- | ----------- |
| PORT | No | 8080 | The port that the app listens on. |
| MESSAGE | No | "Hello world!" | The message displayed by the app. |
| RENDER_PATH_PREFIX | No | "" | The path prefix to use when rendering the urls for the static assets in the handlebar templates. <br/> Must be used when app is deployed with an ingress using a backend path for traffic to app. |
| HANDLER_PATH_PREFIX | No | "" | The path prefix to use by handlers when serving the static asset and services. <br/> Note: Must be used when app is deployed with an ingress that has a backend path for traffic to the app, but which does not rewrite the backend paths to '/'. |

