#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------

FROM mcr.microsoft.com/dotnet/core/sdk:3.1

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ARG INSTALL_NODE="true"
ARG NODE_VERSION="lts/*"
ENV NVM_DIR=/home/vscode/.nvm

ARG INSTALL_AZURE_CLI="true"
ARG INSTALL_POWERSHELL_CORE="true"
ARG INSTALL_DOCKER_CLI="true"
ARG INSTALL_KUBERNETES_CLI="true"
ARG INSTALL_ISTIOCTL="true"

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# Configure apt and install packages
RUN apt-get update \
    && apt-get -y install --no-install-recommends apt-utils dialog 2>&1 \
    #
    # Verify git, process tools, lsb-release (common in install instructions for CLIs) installed
    && apt-get -y install wget git iproute2 procps apt-transport-https gnupg2 curl lsb-release \
    #
    # Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
    && groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    # [Optional] Add sudo support for the non-root user
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    # Install Node.js
    && if [ "$INSTALL_NODE" = "true" ]; then \
    #
        # Install nvm and Node
        mkdir ${NVM_DIR} \
        && curl -so- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash 2>&1 \
        && chown -R vscode:vscode ${NVM_DIR} \
        && /bin/bash -c "source $NVM_DIR/nvm.sh \
        && nvm install ${NODE_VERSION} \
        && nvm alias default ${NODE_VERSION}" 2>&1 \
        && INIT_STRING='[ -s "$NVM_DIR/nvm.sh" ] && \\. "$NVM_DIR/nvm.sh"  && [ -s "$NVM_DIR/bash_completion" ] && \\. "$NVM_DIR/bash_completion"' \
        && echo $INIT_STRING >> /home/vscode/.bashrc \
        && echo $INIT_STRING >> /home/vscode/.zshrc \
        && echo $INIT_STRING >> /root/.zshrc \
        #
        # Install yarn
        && curl -sS https://dl.yarnpkg.com/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/pubkey.gpg | apt-key add - 2>/dev/null \
        && echo "deb https://dl.yarnpkg.com/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
        && apt-get update \
        && apt-get -y install --no-install-recommends yarn; \
    fi \
    #   
    # Install the Azure CLI
    && if [ "$INSTALL_AZURE_CLI" = "true" ]; then \
        echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/azure-cli.list \
        && curl -sL https://packages.microsoft.com/keys/microsoft.asc | apt-key add - 2>/dev/null \
        && apt-get update \
        && apt-get install -y azure-cli; \
    fi \
    #    
    # Install PowerShell Core
    && if [ "$INSTALL_POWERSHELL_CORE" = "true" ]; then \
        wget https://packages.microsoft.com/config/debian/10/packages-microsoft-prod.deb \
        && dpkg -i packages-microsoft-prod.deb \
        && apt-get update \
        && apt-get install -y powershell; \
    fi \
    #
    # Install Docker CE CLI
    # https://github.com/Microsoft/vscode-dev-containers/tree/master/containers/docker-in-docker
    && if [ "$INSTALL_DOCKER_CLI" = "true" ]; then \
        apt-get update \
        && apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common lsb-release \
        && curl -fsSL https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]')/gpg | apt-key add - 2>/dev/null \
        && add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/$(lsb_release -is | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" \
        && apt-get update \
        && apt-get install -y docker-ce-cli; \
    fi \
    #
    # Install Kubernetes CLI
    # https://kubernetes.io/docs/tasks/tools/install-kubectl/
    && if [ "$INSTALL_KUBERNETES_CLI" = "true" ]; then \
        apt-get update && sudo apt-get install -y apt-transport-https \
        && curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add - \
        && echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list \
        && apt-get update \
        && apt-get install -y kubectl; \
    fi \
    #
    # Install istioctl
    && if [ "$INSTALL_ISTIOCTL" = "true" ]; then \
        curl -sL https://istio.io/downloadIstioctl | sh - \
        && sudo mv $HOME/.istioctl/bin/* /bin; \
    fi \
    #
    # Clean up
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog