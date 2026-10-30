# Development environment

The `.devcontainer` folder defines a container based development environment for this repo. Open it with any tool that supports [dev containers](https://containers.dev/), for example the VS Code [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension or the [devcontainer CLI](https://github.com/devcontainers/cli):

```bash
devcontainer up --workspace-folder .
devcontainer exec --workspace-folder . bash
```

The container runs as the `vscode` user on Ubuntu 26.04, and builds on both `amd64` and `arm64` hosts.

## Tools

| Tool | Version |
| ---- | ------- |
| Node.js | pinned in `test/ci/install-tools.sh` |
| kubectl | pinned in `test/ci/install-tools.sh` |
| Helm | pinned in `test/ci/install-tools.sh` |
| Trivy | pinned in `test/ci/install-tools.sh` |
| kind | pinned in `test/ci/install-tools.sh` |
| k3d | pinned in `test/ci/install-tools.sh` |
| cloud-provider-kind | pinned in `test/ci/install-tools.sh` |
| GitHub CLI (`gh`) | latest 2.x |
| GitHub Copilot CLI (`copilot`) | latest, updates itself |
| Claude Code (`claude`) | stable channel, updates itself |
| Docker | via the docker-in-docker feature |

The tools that build, test and scan what is deployed are pinned in `test/ci/install-tools.sh`, the same table that CI uses, so a test that passes here passes in CI for the same reason. Each download is checked against a SHA-256 kept in that table, and each version was published at least 7 days before it was chosen (AGENTS.md rule 8). Node.js matches the version in the app image. To change a version, change it in the table: CI and the devcontainer both follow.

The developer tools that are never deployed (`gh`, the Copilot CLI and Claude Code) track their latest release, and are checked against the checksum published with that release. Change the `gh` major version with `GH_MAJOR` in `.devcontainer/Dockerfile`. Its version lookup uses the GitHub API without a token, which allows 60 requests an hour.

The container builds from the repo root, and `/.dockerignore` sends only the files the Dockerfile copies.

## Application development

Port `8080` is forwarded to your host. Run the app from the repo root:

```bash
make run
```

Then browse to `http://localhost:8080`. Stop it with Ctrl+C.

`make run` installs the dependencies from `src/app/package-lock.json` with `npm ci` when they are missing or older than the lockfile, for example after a `git pull` that changed them. Otherwise it starts the app at once. To set the app's environment variables, put them before the command, for example `PORT=9090 MESSAGE="Hi" make run`.

You can also start the app directly from any directory with `node src/app/server.js`, after `npm ci` in `src/app`.

## Kubernetes clusters

Docker runs inside the container (docker-in-docker), so `kind` and `k3d` clusters are created there and are isolated from your host:

```bash
kind create cluster --name hello-kubernetes
k3d cluster create hello-kubernetes
```

Their contexts are written to `~/.kube/config` inside the container. The clusters and contexts are lost when the container is rebuilt.

### Using clusters from your host

Your host's `~/.kube` folder isn't mounted by default. To use clusters defined on your host, mount it read-only in `.devcontainer/devcontainer.json` and rebuild the container:

```jsonc
"mounts": [
  "source=${localEnv:HOME}${localEnv:USERPROFILE}/.kube,target=/home/vscode/.kube-host,type=bind,readonly"
]
```

Then merge your host contexts into the container's own kubeconfig:

```bash
mkdir -p ~/.kube
KUBECONFIG=~/.kube/config:~/.kube-host/config kubectl config view --flatten > /tmp/kubeconfig \
  && mv /tmp/kubeconfig ~/.kube/config \
  && chmod 600 ~/.kube/config
```

This copies the contexts rather than linking them, so `kind`, `k3d` and `kubectl config` only ever write to the container's file and your host config isn't changed. Run it again to pick up changes from your host. Don't add the mounted file to `KUBECONFIG` instead: `kind delete cluster` locks every file listed there and fails on the read-only one.

Contexts that point at `127.0.0.1` on your host, like a local kind cluster, won't be reachable from inside the container. Remote and cloud clusters work.

## Signing in

Sign-ins for `gh`, `copilot` and `claude` are stored inside the container and are lost when it's rebuilt. Sign in again after a rebuild, or pass tokens in from your host, for example `GH_TOKEN` for `gh`.
