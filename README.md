# KubeVirt Config Repository

> 🇨🇳 **中文说明**：[点击这里查看中文版文档](README_CN.md)

> 💡 **Quick Start**: If you just want to try the Demo, you can use this repository directly without Forking.
> 
> 🔒 **Production Environment**: It is recommended to **Fork** this repository to your own GitHub/GitLab account and set it as a **Private Repository**, or import it to an internal Git server (GitLab CE / Gitea / Gogs).

## Overview

This repository is used to manage configuration templates and environment configurations for KubeVirt Hub virtual machines. It uses Git as the core storage for configuration management and achieves flexible configuration management through a layered structure.

It now supports using the Helm template engine to generate standard KubeVirt VM YAML manifests.

## Directory Structure

```
cubevirt-config/
├── Chart.yaml                 # Helm Chart metadata
├── values.yaml                # Helm default configuration values
├── templates/                 # Helm template directory
│   ├── _helpers.tpl          # Helm template helper functions
│   └── virtualmachine.yaml   # Main VM resource template
├── ha-virt/                   # Environment and host configuration
│   ├── {environment}/        # Environment configuration
│   │   ├── values.yaml       # Environment default configuration
│   │   └── {hostname}/       # Host configuration
│   │       └── values.yaml   # Host-specific configuration
├── system-templates/          # System templates
│   ├── fedora-latest.yaml    # Fedora (Recommended by KubeVirt)
│   ├── ubuntu-22.04.yaml     # Ubuntu 22.04 LTS
│   ├── centos-stream-9.yaml  # CentOS Stream 9
│   └── cirros-demo.yaml      # CirrOS (Lightweight Demo)
```

## Open Source Image Instructions

This project uses official KubeVirt community-maintained images from **[quay.io/containerdisks](https://quay.io/organization/containerdisks)**. These images are specially optimized for KubeVirt DataVolumes and can be used directly.

### Available Images List

| Template Name | Image URL | Default User | Usage |
|--------|----------|---------|------|
| Fedora Latest | `docker://quay.io/containerdisks/fedora:latest` | fedora | Functional verification, latest kernel testing |
| CentOS Stream 9 | `docker://quay.io/containerdisks/centos-stream:9` | centos | Enterprise production environment |
| Ubuntu 22.04 | `docker://quay.io/containerdisks/ubuntu:22.04` | ubuntu | Development, software installation scenarios |
| CirrOS Demo | `docker://quay.io/kubevirt/cirros-container-disk-demo:latest` | cirros | Quick Demo verification |

### ⚠️ QEMU Guest Agent Note

Official images are usually very clean and may not have `qemu-guest-agent` pre-installed. If your platform relies on the Guest Agent to obtain IP addresses, please ensure it is installed in cloud-init:

```yaml
#cloud-config
packages:
  - qemu-guest-agent

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
```

## Configuration Instructions

### values.yaml
Helm default configuration values, including global configuration, VM basic configuration, etc.

### ha-virt/{environment}/values.yaml
Default configuration for each environment, including the default resource configuration for VMs in that environment.

Example (`ha-virt/dev/values.yaml`):
```yaml
cpu_cores: 1
memory: "2Gi"
rootfs_size: "60Gi"
data_size: "50Gi"
# storage_class_name is obtained from cluster configuration, not defined here
run_strategy: "Always"
app_label: "dev-app"
```

### ha-virt/{environment}/{hostname}/values.yaml
Host-specific configuration, defining resource configuration fine-tuning for specific hosts.

Example (`ha-virt/dev/host01/values.yaml`):
```yaml
name: host01
namespace: dev
cpu_cores: 4
memory: "8Gi"
data_size: "20Gi"
```

### system-templates/
System template directory containing predefined system templates. Each template file contains image URL, system disk and data disk sizes, CPU, memory presets, cloudinit configuration, etc.

The metadata information of system templates is stored in the database and associated with the template files in Git through the template's `name` field. The `vm_templates` table in the database stores metadata such as the template's UUID and name, while the template files in the Git repository use the template name as the file name.

Example (`system-templates/ubuntu-22.04.yaml`):
```yaml
template_name: ubuntu-22.04
image_url: docker://quay.io/containerdisks/ubuntu:22.04
cpu_cores: 2
memory: "4Gi"
rootfs_size: "40Gi"
data_size: "30Gi"
# storage_class_name is obtained from cluster configuration
run_strategy: "Always"
app_label: "ubuntu-app"
cloud_init_user: ubuntu
cloudinit_data: |
  #cloud-config
  hostname: ${hostname}
  manage_etc_hosts: true
  ssh_pwauth: true
  packages:
    - qemu-guest-agent
  runcmd:
    - systemctl enable --now qemu-guest-agent
```

## Using Helm to Generate VM Manifests

### 1. Generate VM Manifest for Specific System Template

Use the following command to generate a VM manifest for a specific system template:

```bash
# Generate VM manifest for Ubuntu system
helm template vm-release .
  -f system-templates/ubuntu-22.04.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml
```

### 2. Generate and Save VM Manifest to Temporary Directory

```bash
# Generate VM manifest and save to temporary directory
helm template vm-release .
  -f system-templates/fedora-latest.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml > temp/generated-vm.yaml
```

### 3. Generate and Apply VM Manifest

```bash
# Generate and apply VM manifest
helm template vm-release .
  -f system-templates/centos-stream-9.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml | kubectl apply -f -
```

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone https://github.com/your-org/kubevirt-config.git
   cd kubevirt-config
   ```

2. **Configure StorageClass**:
   StorageClass is obtained from the cluster configuration, set in KubeVirt Hub System Configuration -> Cluster Management.
   If not configured, the Kubernetes cluster's default StorageClass will be used.
   
   Common StorageClasses:
   - Rook Ceph: `rook-ceph-block`
   - Longhorn: `longhorn`
   - Local Path: `local-path`
   - NFS: `nfs-client`

3. **Verify Template**:
   ```bash
   helm template test . -f system-templates/cirros-demo.yaml
   ```

## Workflow

### Administrator Operations

1. **Add New System Template**:
   - Create a new system template file in the `system-templates/` directory
   - Commit to the Git repository

2. **Update Environment Default Configuration**:
   - Modify `ha-virt/{environment}/values.yaml`
   - Commit to the Git repository

### User Request Workflow

When requesting a virtual machine, users only need to provide:
1. **Hostname** - e.g., `host01`
2. **Select Environment** - dev/test/uat/prod
3. **Select System Template** - Select from `system-templates/`
4. **Optional Editing** - CPU cores, memory size, data disk size

### System Processing Workflow

1. **On System Startup**:
   - Read `system-templates/` to get the list of system templates
   - Read the default configuration for each environment

2. **On User Request**:
   - User selects environment and system template
   - The system automatically obtains the corresponding environment default configuration and system template configuration
   - User optionally edits resource configuration

3. **Configuration Generation**:
   - Generate host configuration file to `ha-virt/{environment}/{hostname}/values.yaml`

4. **VM Creation**:
   - Create VM using the generated configuration

## Configuration Merge Strategy

Configuration merge order (from low priority to high priority):
1. `system-templates/{template}.yaml` - System template configuration
2. `ha-virt/{environment}/values.yaml` - Environment default configuration
3. `ha-virt/{environment}/{hostname}/values.yaml` - Host-specific configuration

## Advantages

1. **Out of the Box** - Uses official community-maintained container disk images
2. **Simple Design** - System templates predefine common configurations, reducing user configuration complexity
3. **Easy to Extend** - Adding a new system template only requires creating a new template file
4. **User Friendly** - Provides preset system template selection
5. **Version Control** - Git provides complete configuration version management
6. **Collaborative Management** - Supports multi-person collaboration to maintain configuration
7. **Reduced Dependencies** - Minimizes dependence on the database
8. **Standardization** - Uses Helm template engine, consistent with Kubernetes ecosystem standards

## License

Apache License 2.0