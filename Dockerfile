FROM python:3.10-slim

# Define build arguments for tool versions
ARG ANSIBLE_VERSION=10.0.1
ARG PYWINRM_VERSION=0.5.0
ARG APP_USER=ansible
ARG APP_UID=10001
ARG APP_GID=10001

# Set environment variables for non-interactive, predictable Python behavior
ENV DEBIAN_FRONTEND=noninteractive \
  PIP_DISABLE_PIP_VERSION_CHECK=1 \
  PYTHONDONTWRITEBYTECODE=1 \
  PYTHONUNBUFFERED=1

# Install system dependencies
RUN set -eux; \
  apt-get update && \
  apt-get install -y --no-install-recommends \
  ca-certificates \
  sshpass \
  openssh-client \
  && rm -rf /var/lib/apt/lists/*

# Install Ansible and WinRM support with a single pip layer
RUN python -m pip install --no-cache-dir --upgrade pip && \
  python -m pip install --no-cache-dir \
  "ansible==${ANSIBLE_VERSION}" \
  "pywinrm==${PYWINRM_VERSION}"

# Create and use a non-root runtime user
RUN groupadd --gid "${APP_GID}" "${APP_USER}" && \
  useradd --uid "${APP_UID}" --gid "${APP_GID}" --create-home --shell /bin/bash "${APP_USER}" && \
  mkdir -p /workspace/ansible /workspace/sshkey && \
  chown -R "${APP_UID}:${APP_GID}" /workspace /home/"${APP_USER}"

USER ${APP_UID}:${APP_GID}

# Set runtime environment and workdir for ansible execution
ENV HOME=/home/${APP_USER}
WORKDIR /workspace/ansible

# Set the entrypoint to run Ansible commands
ENTRYPOINT ["/bin/sh", "-c"]
