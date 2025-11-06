# Ansible KubeVela Addon

A KubeVela addon that enables running Ansible playbooks as Kubernetes Jobs. This addon creates a component that automatically clones your Ansible playbooks from a Git repository and executes them within your Kubernetes cluster.

## Features

- **Git Integration**: Automatically clone Ansible playbooks from Git repositories (supports both public and private repositories)
- **Flexible Authentication**: Support for both SSH key and username/password authentication for target hosts
- **Branch/Tag Support**: Deploy from specific Git branches or tags
- **Resource Management**: Configurable CPU and memory limits
- **Collection Support**: Install Ansible collections from requirements files
- **Environment Variables**: Pass custom environment variables to playbooks
- **Job Management**: Runs as Kubernetes Jobs with configurable restart policies

## Installation

Install the addon in your KubeVela environment:

```bash
vela addon enable ansible
```

## Component Usage

### Basic Example

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: my-ansible-app
spec:
  components:
  - name: deploy-servers
    type: ansible
    properties:
      git:
        url: "https://github.com/your-org/ansible-playbooks.git"
        branch: "main"
      sourcePlaybook: "site.yml"
      sourceInventory: "inventory/production"
      authConfig:
        sshKeyRef: "my-ssh-key"
```

### Advanced Example with Authentication Config

First, create authentication configuration:

```yaml
# For SSH Key Authentication
apiVersion: core.oam.dev/v1beta1
kind: Config
metadata:
  name: my-ssh-key
spec:
  type: ssh-privatekey
  properties:
    sshPrivateKey: "LS0tLS1CRUdJTi..." # Base64 encoded SSH private key
---
# For Basic Authentication (username/password)
apiVersion: core.oam.dev/v1beta1
kind: Config
metadata:
  name: my-basic-auth
spec:
  type: authentication
  properties:
    username: "ansible-user"
    password: "your-password"
```

Then use in your application:

```yaml
apiVersion: core.oam.dev/v1beta1
kind: Application
metadata:
  name: complex-ansible-deployment
spec:
  components:
  - name: provision-infrastructure
    type: ansible
    properties:
      git:
        url: "https://github.com/your-org/infrastructure-playbooks.git"
        tag: "v1.2.0"
        secretRef: "git-credentials" # For private repositories
      sourcePlaybook: "provision.yml"
      sourceInventory: "inventory/staging"
      ansibleCollections: "requirements.yml"
      authConfig:
        sshKeyRef: "my-ssh-key"
      cpu: "500m"
      memory: "1Gi"
      extraArguments:
        - "--extra-vars"
        - "environment=staging"
        - "--verbose"
      env:
        - name: "CUSTOM_VAR"
          value: "custom-value"
        - name: "SECRET_VAR"
          valueFrom:
            secretKeyRef:
              name: "app-secrets"
              key: "api-key"
```

## Configuration Parameters

### Required Parameters

| Parameter | Description | Type | Example |
|-----------|-------------|------|---------|
| `git.url` | Git repository URL containing Ansible playbooks | string | `"https://github.com/user/repo.git"` |
| `authConfig` | Authentication configuration for target hosts | object | See authentication section |

### Optional Parameters

| Parameter | Description | Type | Default | Example |
|-----------|-------------|------|---------|---------|
| `git.branch` | Git branch to checkout | string | `"main"` | `"develop"` |
| `git.tag` | Git tag to checkout (overrides branch) | string | - | `"v1.0.0"` |
| `git.secretRef` | Secret for Git authentication | string | - | `"git-token"` |
| `sourcePlaybook` | Path to playbook file in repository | string | `"playbook.yaml"` | `"site.yml"` |
| `sourceInventory` | Path to inventory file in repository | string | `"inventory"` | `"inventory/prod"` |
| `ansibleCollections` | Path to collections requirements file | string | - | `"requirements.yml"` |
| `extraArguments` | Additional ansible-playbook arguments | array | - | `["--check", "--diff"]` |
| `cpu` | CPU resource limit | string | - | `"500m"` |
| `memory` | Memory resource limit | string | - | `"1Gi"` |
| `restartPolicy` | Job restart policy | string | `"Never"` | `"OnFailure"` |
| `imagePullPolicy` | Image pull policy | string | `"IfNotPresent"` | `"Always"` |

### Authentication Configuration

#### SSH Key Authentication (Recommended)

```yaml
authConfig:
  sshKeyRef: "my-ssh-key-config"
```

Create the SSH key config:
```yaml
apiVersion: core.oam.dev/v1beta1
kind: Config
metadata:
  name: my-ssh-key-config
spec:
  type: ssh-privatekey
  properties:
    sshPrivateKey: "LS0tLS1CRUdJTi..." # Base64 encoded private key
```

#### Basic Authentication (Username/Password)

```yaml
authConfig:
  basicAuthRef: "my-basic-auth-config"
```

Create the basic auth config:
```yaml
apiVersion: core.oam.dev/v1beta1
kind: Config
metadata:
  name: my-basic-auth-config
spec:
  type: authentication
  properties:
    username: "ansible-user"
    password: "secure-password"
```

## Environment Variables

The following environment variables are automatically available in your Ansible playbooks:

- `APP_NAME`: The KubeVela application name
- `ANSIBLE_USER`: Username (when using basic auth)
- `ANSIBLE_PASSWORD`: Password (when using basic auth)

## Best Practices

1. **Use SSH Key Authentication**: More secure than username/password authentication
2. **Resource Limits**: Always set appropriate CPU and memory limits
3. **Git Tags**: Use specific tags for production deployments instead of branches
4. **Inventory Management**: Organize inventories by environment (dev/staging/prod)
5. **Collection Requirements**: Use `requirements.yml` for consistent collection versions
6. **Secret Management**: Store sensitive data in KubeVela configs, not in Git repositories

## Troubleshooting

### Common Issues

1. **Job Fails to Start**: Check image pull policy and secrets
2. **Git Clone Fails**: Verify repository URL and authentication credentials
3. **Ansible Playbook Fails**: Check playbook syntax and inventory file
4. **SSH Connection Issues**: Verify SSH key format and target host connectivity

### Monitoring Job Status

```bash
# Check job status
kubectl get jobs -l app.oam.dev/name=<app-name>

# View job logs
kubectl logs -l app.oam.dev/name=<app-name>

# Check application status
vela status <app-name>
```

## Container Image

This addon uses the `nggocnn/ansible-playbook:v0.2` container image, which includes:

- Python 3.10
- Ansible 10.0.1
- PyWinRM 0.5.0 (for Windows host support)
- SSH client and sshpass utilities

## Contributing

This addon follows the KubeVela addon development guidelines. For more information on building custom addons, see: https://kubevela.net/docs/platform-engineers/addon/intro
