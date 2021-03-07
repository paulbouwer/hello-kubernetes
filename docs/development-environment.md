# Development environment

If you have [VS Code](https://code.visualstudio.com/) and the [Visual Studio Code Remote Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension installed, the `.devcontainer` folder will be used to provide a container based development environment for this repo.

## Terminal

The following utilities will be avaialble in the VS Code Terminal:

- curl
- Docker cli
- Helm 3.x
- jq
- kubectl 
- vim

## Application development

Port `8080` has been configured to be forwarded to your host. If you run `npm start` in the `src/app` folder in the **VS Code Remote Containers** terminal, you will be able to access the website on `http://localhost:8080`. You can change the port in the `.devcontainer/devcontainer.json` file under the `appPort` key.

See the **Visual Studio Code Remote Containers** [guidance](https://code.visualstudio.com/docs/remote/containers) for more details on working with this setup.