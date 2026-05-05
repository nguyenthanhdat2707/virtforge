# syntax=docker/dockerfile:1

FROM ubuntu:24.04

ARG TERRAFORM_VERSION=1.14.8
ARG ANSIBLE_CORE_VERSION=2.20.5

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/ansible/bin:${PATH}"

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      libvirt-dev \
      openssh-client \
      pkg-config \
      python3 \
      python3-pip \
      python3-venv \
      unzip \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64) terraform_arch="amd64" ;; \
      arm64) terraform_arch="arm64" ;; \
      *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${terraform_arch}.zip"; \
    unzip -q /tmp/terraform.zip -d /tmp; \
    install -m 0755 /tmp/terraform /usr/local/bin/terraform; \
    rm -f /tmp/terraform /tmp/terraform.zip

RUN python3 -m venv /opt/ansible \
    && /opt/ansible/bin/pip install --no-cache-dir --upgrade pip setuptools wheel \
    && /opt/ansible/bin/pip install --no-cache-dir "ansible-core==${ANSIBLE_CORE_VERSION}"

RUN terraform version \
    && ansible --version \
    && jq --version
