#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

FROM node:15

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# The node image includes a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=node
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Configure apt and install packages
RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-utils \
        bash-completion \
        ca-certificates \
        curl \
        dialog \
        git \
        iproute2 \
        jq \
        procps \
        less \
        vim \
    #
    # Install bash completion
    && echo ". /etc/bash_completion" >> ~/.bashrc \
    && mkdir -p ~/completions \
    #
    # Install node packages globally
    && npm install -g eslint pino-pretty \
    #
    # Add add sudo support for non-root user
    && apt-get install -y sudo \
    && echo node ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Install Docker CE CLI
RUN apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common lsb-release \
    && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | (OUT=$(apt-key add - 2>&1) || echo $OUT) \
    && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && curl -L https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o ~/completions/docker.bash \
    && echo "source ~/completions/docker.bash" >> ~/.bashrc

# Install Helm
RUN mkdir /tmp/helm \
    && curl -L https://get.helm.sh/helm-$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)-linux-amd64.tar.gz | tar xz -C /tmp/helm --strip-components 1 \
    && mv /tmp/helm/helm /usr/local/bin/ \
    && chmod +x /usr/local/bin/helm \
    && rm -fr /tmp/helm \
    && helm completion bash > ~/completions/helm.bash \
    && echo "source ~/completions/helm.bash" >> ~/.bashrc

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl \
    && kubectl completion bash > ~/completions/kubectl.bash \ 
    && echo "source ~/completions/kubectl.bash" >> ~/.bashrc \
    && echo "alias k=kubectl" >> ~/.bashrc \
    && echo "complete -o default -F __start_kubectl k" >> ~/.bashrc

# Install trivy
RUN mkdir /tmp/trivy \
    && curl -L https://github.com/aquasecurity/trivy/releases/download/v0.19.2/trivy_0.19.2_Linux-64bit.tar.gz | tar xvz -C /tmp/trivy -f - contrib trivy \
    && chmod +x /tmp/trivy/trivy \
    && mv /tmp/trivy/trivy /usr/local/bin/trivy \
    && mkdir -p /trivy/contrib \
    && mv /tmp/trivy/contrib/* /trivy/contrib/
    
# Clean up
RUN apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
