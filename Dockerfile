# Building our environment based on python
FROM python:3.10 as base

# Project name
ENV PROJECT_NAME=ansible-role-debian-setup


# Ensure non-interactive apt-get installs
ENV DEBIAN_FRONTEND noninteractive

# Versions of tools we want to use.  These are used in the builder stage to download the binaries and then copied into the staging image.
ENV SOPS_VERSION=3.8.1
ENV GITLEAKS_VERSION=8.18.1
ENV HADOLINT_VERSION=2.12.0
ENV YQ_VERSION=4.40.5 
ENV JUST_VERSION=1.18.1

# Apt package versions
ENV SSHPASS_VERSION=1.09-1
ENV ANSIBLE_VERSION=7.3.0+dfsg-1
ENV CURL_VERSION=7.88.1-10+deb12u5
ENV CA_CERTIFICATES_VERSION=20230311
ENV DIRENV_VERSION=2.32.1-2+b4
ENV APT_TRANSPORT_HTTPS_VERSION=2.6.1
ENV GNUPG_VERSION=2.2.40-1.1
ENV LSB_RELEASE_VERSION=12.0-1
ENV DOCKER_CE_CLI_VERSION=5:24.0.7-1~debian.12~bookworm
ENV CONTAINERD_IO_VERSION=1.6.26-1


# Install the tools we need for our environment
WORKDIR /tmp
SHELL ["/bin/bash", "-l", "-o", "pipefail", "-c"]
RUN <<EOF
  apt-get update
  apt-get install -y --no-install-recommends \
      sshpass=${SSHPASS_VERSION} \
      ansible=${ANSIBLE_VERSION} \
      curl=${CURL_VERSION} \
      ca-certificates=${CA_CERTIFICATES_VERSION} \
      direnv=${DIRENV_VERSION} \
      apt-transport-https=${APT_TRANSPORT_HTTPS_VERSION} \
      gnupg=${GNUPG_VERSION} \
      lsb-release=${LSB_RELEASE_VERSION}
  rm -rf /var/cache/apt/archives
EOF

# Install docker for molecule testing
RUN <<EOF
  dpkg --print-architecture > dpkg_arch
  curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
  echo "deb [arch=$(cat dpkg_arch)] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y --no-install-recommends \
    docker-ce-cli=${DOCKER_CE_CLI_VERSION} \
    containerd.io=${CONTAINERD_IO_VERSION}
  rm -rf /var/cache/apt/archives
  rm -f dpkg_arch
EOF

# Install the ansible project requirements
COPY dev-requirements.txt .
RUN pip3 install --no-cache-dir -r dev-requirements.txt && rm -f dev-requirements.txt

#
# Builder stage.  This stage is used to download the binaries we need for our environment and then copy them into the staging image.
#
FROM base as builder
WORKDIR /tmp/builder
RUN <<EOF
    dpkg --print-architecture > dpkg_arch
    if ! grep -qE '^(amd64|arm64)$' dpkg_arch; then echo "Unsupported architecture" && exit 1; fi
    cp dpkg_arch arch
    curl -LO "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.$(cat arch)"
    chmod +x "sops-v${SOPS_VERSION}.linux.$(cat arch)"
    mv "sops-v${SOPS_VERSION}.linux.$(cat arch)" /usr/local/bin/sops
    if [ "$(cat dpkg_arch)" = "amd64" ]; then echo x64 > arch; else echo arm64 > arch; fi
    curl -LO "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_$(cat arch).tar.gz"
    tar zxvf "gitleaks_${GITLEAKS_VERSION}_linux_$(cat arch).tar.gz"
    mv gitleaks /usr/local/bin
    if [ "$(cat dpkg_arch)" = "amd64" ]; then echo x86_64 > arch; else echo arm64 > arch; fi
    curl -LO "https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-$(cat arch)"
    chmod +x "hadolint-Linux-$(cat arch)"
    mv "hadolint-Linux-$(cat arch)" /usr/local/bin/hadolint
    curl -LO "https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/yq_linux_$(cat arch)"
    chmod +x yq_linux_"$(cat arch)"
    mv "yq_linux_$(cat arch)" /usr/local/bin/yq
    if [ "$(cat dpkg_arch)" = "amd64" ]; then echo x86_64-unknown-linux-musl > arch; else echo aarch64-unknown-linux-musl > arch; fi
    curl -LO "https://github.com/casey/just/releases/download/${JUST_VERSION}/just-${JUST_VERSION}-$(cat arch).tar.gz"
    tar zxvf "just-${JUST_VERSION}-$(cat arch).tar.gz"
    mv just /usr/local/bin/just
EOF

#
# The staging image takes the builds from the builder image and sets up the local user.  You can sudo to root if you need to.
# 
FROM base as staging
COPY --from=builder /usr/local/bin/sops /usr/local/bin/sops
COPY --from=builder /usr/local/bin/gitleaks /usr/local/bin/gitleaks
COPY --from=builder /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq
COPY --from=builder /usr/local/bin/just /usr/local/bin/just
RUN echo "eval '$(direnv hook bash)'" >> "/root/.bashrc"

#
# The development image builds on staging and finalizes project requirements and variables.
# 
FROM staging as development
WORKDIR /workspaces/${PROJECT_NAME}
ENV SOPS_AGE_KEY_FILE=/root/.age/ansible-key.txt
COPY galaxy-requirements.yml .
RUN <<EOF
  ansible-galaxy install -r galaxy-requirements.yml
  rm -f galaxy-requirements.yml
  cp /etc/skel/.bashrc /root/.bashrc
EOF

#
# Sets the development image as the default image
#
FROM development
