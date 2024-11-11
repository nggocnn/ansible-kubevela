FROM python:3.10-slim

# Define a build argument for the Ansible version, with a default value
ARG ANSIBLE_VERSION=10.0.1
ARG PYWINRM_VERSION=0.5.0

# Set environment variables to minimize prompts and enable pip cache
ENV DEBIAN_FRONTEND=noninteractive \
  PIP_NO_CACHE_DIR=off \
  PIP_DISABLE_PIP_VERSION_CHECK=on

# Install system dependencies
RUN apt-get clean && \
  apt-get update --fix-missing && \
  apt-get install -y --no-install-recommends \
  sshpass \
  openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Install Ansible using pip
RUN pip3 install --upgrade pip && \
  pip3 install ansible==$ANSIBLE_VERSION && \
  pip3 install pywinrm==$PYWINRM_VERSION

# Set the workdir to run Ansible playbook
WORKDIR /workspace/ansible

# Set the entrypoint to run Ansible commands
ENTRYPOINT ["/bin/sh", "-c"]