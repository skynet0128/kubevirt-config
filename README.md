# KubeVirt Config Repository

## 概述

本仓库用于管理 KubeVirt Hub 虚拟机的配置模板和环境配置，采用 Git 作为配置管理的核心存储，通过分层结构实现灵活的配置管理。

现在支持使用 Helm 模板引擎来生成标准的 KubeVirt VM YAML 清单。

## 目录结构

```
kubevirt-config/
├── Chart.yaml                 # Helm Chart元数据
├── values.yaml                # Helm默认配置值
├── templates/                 # Helm模板目录
│   ├── _helpers.tpl          # Helm模板辅助函数
│   └── virtualmachine.yaml   # 虚拟机主资源模板
├── ha-virt/                   # 环境和主机配置
│   ├── {environment}/        # 环境配置
│   │   ├── values.yaml       # 环境默认配置
│   │   └── {hostname}/       # 主机配置
│   │       └── values.yaml   # 主机特定配置
├── system-templates/          # 系统模板
│   ├── fedora-latest.yaml    # Fedora (KubeVirt推荐)
│   ├── ubuntu-22.04.yaml     # Ubuntu 22.04 LTS
│   ├── centos-stream-9.yaml  # CentOS Stream 9
│   └── cirros-demo.yaml      # CirrOS (轻量级Demo)
```

## 开源镜像说明

本项目使用来自 **[quay.io/containerdisks](https://quay.io/organization/containerdisks)** 的官方 KubeVirt 社区维护镜像，这些镜像专门为 KubeVirt DataVolume 优化，可以直接使用。

### 可用镜像列表

| 模板名称 | 镜像地址 | 默认用户 | 用途 |
|---------|----------|---------|------|
| Fedora Latest | `docker://quay.io/containerdisks/fedora:latest` | fedora | 功能验证、最新内核测试 |
| CentOS Stream 9 | `docker://quay.io/containerdisks/centos-stream:9` | centos | 企业级生产环境 |
| Ubuntu 22.04 | `docker://quay.io/containerdisks/ubuntu:22.04` | ubuntu | 开发、软件安装场景 |
| CirrOS Demo | `docker://quay.io/kubevirt/cirros-container-disk-demo:latest` | cirros | 快速 Demo 验证 |

### ⚠️ QEMU Guest Agent 注意事项

官方镜像通常非常干净，可能没有预装 `qemu-guest-agent`。如果您的平台依赖 Guest Agent 获取 IP 地址，请确保在 cloud-init 中安装：

```yaml
#cloud-config
packages:
  - qemu-guest-agent

runcmd:
  - [ systemctl, enable, --now, qemu-guest-agent ]
```

## 配置说明

### values.yaml
Helm 默认配置值，包含全局配置、VM 基础配置等。

### ha-virt/{environment}/values.yaml
各环境的默认配置，包含该环境下 VM 的默认资源配置。

示例（ha-virt/dev/values.yaml）：
```yaml
cpu_cores: 1
memory: "2Gi"
rootfs_size: "60Gi"
data_size: "50Gi"
# storage_class_name 从集群配置获取，不在此处定义
run_strategy: "Always"
app_label: "dev-app"
```

### ha-virt/{environment}/{hostname}/values.yaml
主机特定配置，定义特定主机的资源配置微调。

示例（ha-virt/dev/host01/values.yaml）：
```yaml
name: host01
namespace: dev
cpu_cores: 4
memory: "8Gi"
data_size: "20Gi"
```

### system-templates/
系统模板目录，包含预定义的系统模板，每个模板文件包含镜像地址、系统盘和数据盘大小、CPU、内存预设值、cloudinit 配置等。

系统模板的元数据信息存储在数据库中，通过模板的 `name` 字段与 Git 中的模板文件关联。数据库中的 `vm_templates` 表存储模板的 UUID 和名称等元数据，而 Git 仓库中的模板文件使用模板名称作为文件名。

示例（system-templates/ubuntu-22.04.yaml）：
```yaml
template_name: ubuntu-22.04
image_url: docker://quay.io/containerdisks/ubuntu:22.04
cpu_cores: 2
memory: "4Gi"
rootfs_size: "40Gi"
data_size: "30Gi"
# storage_class_name 从集群配置获取
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

## 使用 Helm 生成 VM 清单

### 1. 生成特定系统模板的 VM 清单

使用以下命令生成特定系统模板的 VM 清单：

```bash
# 生成 Ubuntu 系统的 VM 清单
helm template vm-release . \
  -f system-templates/ubuntu-22.04.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml
```

### 2. 生成并保存 VM 清单到临时目录

```bash
# 生成 VM 清单并保存到临时目录
helm template vm-release . \
  -f system-templates/fedora-latest.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml > temp/generated-vm.yaml
```

### 3. 生成并应用 VM 清单

```bash
# 生成并应用 VM 清单
helm template vm-release . \
  -f system-templates/centos-stream-9.yaml \
  -f ha-virt/dev/values.yaml \
  -f ha-virt/dev/host01/values.yaml | kubectl apply -f -
```

## 快速开始

1. **克隆本仓库**:
   ```bash
   git clone https://github.com/your-org/kubevirt-config.git
   cd kubevirt-config
   ```

2. **配置 StorageClass**:
   StorageClass 从集群配置获取，在 KubeVirt Hub 系统配置 → 集群管理中设置。
   如果不配置，将使用 Kubernetes 集群的默认 StorageClass。
   
   常见的 StorageClass：
   - Rook Ceph: `rook-ceph-block`
   - Longhorn: `longhorn`
   - Local Path: `local-path`
   - NFS: `nfs-client`

3. **验证模板**:
   ```bash
   helm template test . -f system-templates/cirros-demo.yaml
   ```

## 工作流程

### 管理员操作

1. **添加新系统模板**:
   - 在 `system-templates/` 目录下创建新的系统模板文件
   - 提交到 Git 仓库

2. **更新环境默认配置**:
   - 修改 `ha-virt/{environment}/values.yaml`
   - 提交到 Git 仓库

### 用户申请流程

用户申请虚拟机时只需提供：
1. **主机名** - 如 `host01`
2. **选择环境** - dev/test/uat/prod
3. **选择系统模板** - 从 `system-templates/` 中选择
4. **可选编辑** - CPU 核心数、内存大小、数据盘大小

### 系统处理流程

1. **系统启动时**:
   - 读取 `system-templates/` 获取系统模板列表
   - 读取各环境的默认配置

2. **用户申请时**:
   - 用户选择环境和系统模板
   - 系统自动获取对应环境的默认配置和系统模板配置
   - 用户可选编辑资源配置

3. **配置生成**:
   - 生成主机配置文件到 `ha-virt/{environment}/{hostname}/values.yaml`

4. **VM 创建**:
   - 使用生成的配置创建 VM

## 配置合并策略

配置合并顺序（从低优先级到高优先级）：
1. `system-templates/{template}.yaml` - 系统模板配置
2. `ha-virt/{environment}/values.yaml` - 环境默认配置
3. `ha-virt/{environment}/{hostname}/values.yaml` - 主机特定配置

## 优势

1. **开箱即用** - 使用官方社区维护的容器磁盘镜像
2. **简洁设计** - 系统模板预定义了常用配置，降低用户配置复杂度
3. **易于扩展** - 添加新系统模板只需创建新的模板文件
4. **用户友好** - 提供预设的系统模板选择
5. **版本控制** - Git 提供完整的配置版本管理
6. **协作管理** - 支持多人协作维护配置
7. **减少依赖** - 最大限度减少对数据库的依赖
8. **标准化** - 使用 Helm 模板引擎，符合 Kubernetes 生态系统标准

## License

Apache License 2.0