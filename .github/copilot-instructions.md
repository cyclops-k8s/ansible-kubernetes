# Copilot Instructions for ansible-kubernetes

## Project Overview

This is an Ansible-based project that provisions CIS-hardened, Kubernetes clusters using `kubeadm`. It supports Ubuntu 22.04+, is STIG-compliant, and includes a modular hook system for extending cluster capabilities (CNI, CSI, CPI installation).

**Key Architecture:** Sequential playbooks orchestrate infrastructure phases (proxy config → container runtime → control planes → workers), with a custom hooks system allowing injection of deployment-specific tasks at defined lifecycle points.

## Critical Workflows

### 1. Full Cluster Installation
- **Entry point:** [install.yaml](install.yaml) - Main orchestration playbook
- **Execution:** `ansible-playbook -i inventory install.yaml`
- **Key sequence:** Proxies → Containerd → K8s prereqs → Pre-control-plane hooks → Control planes (serial: 1) → Post-control-plane hooks → Workers → Post-worker hooks
- **Critical setting:** `kubernetes_control_plane_ip` (required) - IP proxies bind to; `kubernetes_api_endpoint` (required) - client-facing FQDN
- **Expected output:** `/var/log/kubernetes/` output directory with logs, configs, and manifests created on first control plane

### 2. Cluster Upgrades
- **Entry point:** [upgrade.yaml](upgrade.yaml)
- **Note:** Serial execution (serial: 1) prevents cluster disruption; upgrade role handles kubeadm upgrade logic
- **Use:** When `kubernetes_version` variable changes in defaults

### 3. Node Addition
- Add new nodes to inventory (existing `proxies`, `control_planes`, or `worker_nodes` groups)
- Re-run [install.yaml](install.yaml) - playbook automatically detects and skips already-configured nodes
- Hooks should implement idempotency checks (e.g., `creates:` or state validation)

## Role Structure & Responsibilities

All roles are sourced from [roles/](roles/) directory. Each role is **independent and composable**:

| Role | Purpose | Dependencies |
|------|---------|--------------|
| `kubernetes-defaults` | **Must load first** - provides all variables from [roles/kubernetes-defaults/defaults/main.yml](roles/kubernetes-defaults/defaults/main.yml) (445 lines, extensively commented with CIS/STIG references) | None |
| `kubernetes-proxy` | HAProxy + Keepalived config for control plane load balancing | kubernetes-defaults |
| `containerd` | Container runtime setup with credential injection support | kubernetes-defaults |
| `kubernetes` | Base Kubernetes prerequisites (kubeadm, kubelet, kubectl, system tuning) | kubernetes-defaults |
| `pre-kubernetes-control-plane` | Pre-init hooks before first control plane bootstrap | kubernetes-defaults |
| `kubernetes-control-plane` | kubeadm init, RBAC, encryption, audit policies; manages version-specific templates (1.33-1.35+) | kubernetes-defaults |
| `post-kubernetes-control-plane` | Per-node hooks after control plane joins (certificate renewal services, cluster config distribution) | kubernetes-defaults |
| `kubernetes-worker` | Worker node join via kubeadm | kubernetes-defaults |
| `post-kubernetes-worker` | Post-worker-join hooks (apps, monitoring agents) | kubernetes-defaults |
| `kubernetes-upgrade` | kubeadm upgrade-plan, drain, upgrade, uncordon | kubernetes-defaults |

**Critical:** Always prepend `kubernetes-defaults` role to ensure variables load first.

## Hooks System

Hooks enable extensible deployment post-bootstrap (CNI, CSI, CPI installation, OIDC setup, backups).

### Hook Types & Timing
- `pre_control_planes` - Before first control plane kubeadm init (e.g., proxy config on control planes)
- `post_cluster_init` - After cluster initialization, before control plane joins (CNI: Calico, Cilium; OIDC admin binding)
- `post_control_planes` - After each individual control plane joins (per-node tasks)
- `post_all_control_planes` - Once all control planes ready; runs per-node but supports `run_once`, `delegate_to` (cert backups, kubeconfig setup)
- `post_workers` - After all workers join (monitoring, ArgoCD bootstrap)

### Hook Implementation Patterns
See [example-hooks/](example-hooks/) for working examples:

1. **Structure:** `example-hooks/{feature}/hook-point/` containing YAML task files
2. **Task content:** Hooks are `include_tasks` blocks - write standard Ansible tasks with shell commands for kubectl operations
3. **Idempotency:** Use `creates:` clauses (e.g., [example-hooks/install-calico/post-cluster-init/install-calico.yaml](example-hooks/install-calico/post-cluster-init/install-calico.yaml)) or state validation to prevent re-execution
4. **Kubectl config:** Use `--kubeconfig /etc/kubernetes/admin.conf` explicitly; hooks run as root on control planes
5. **Output location:** Store state files in `{{ kubernetes_output_directory }}/` (typically `/var/log/kubernetes/`)

### Referencing Hooks in Playbook
Define hooks via `kubernetes_hookfiles` variable in inventory or group_vars. Each key maps to a hook point, values are YAML task file paths:

```yaml
# group_vars/all.yml - Define hook execution
kubernetes_hookfiles:
  pre_control_planes:
    - /path/to/example-hooks/proxy-on-control-planes/pre_control_planes/proxy-on-control-planes.yaml
  post_cluster_init:
    - /path/to/example-hooks/install-calico/post-cluster-init/install-calico.yaml
    - /path/to/example-hooks/add-adminrolebinding/post-cluster-init/add-adminbinding.yaml
  post_all_control_planes:
    - /path/to/example-hooks/etcd-backup/post-control-planes/etcd-backup.yaml
  post_workers:
    - /path/to/example-hooks/argocd/post-workers/install-argocd.yaml
```

**Key naming rules:**
- Dictionary keys must match hook point names exactly: `pre_control_planes`, `post_cluster_init`, `post_control_planes`, `post_all_control_planes`, `post_workers`
- Values are arrays of file paths (supports multiple hooks per point, executed in order)
- Hook task files use standard Ansible `include_tasks` syntax with shell/command tasks
- See [example-hooks/](example-hooks/) for working implementations of each hook type

## Configuration & Variable System

### Variable Resolution Hierarchy
1. **Defaults:** [roles/kubernetes-defaults/defaults/main.yml](roles/kubernetes-defaults/defaults/main.yml) - 445 lines with CIS/STIG annotations
2. **Inventory/group_vars:** Override defaults (node-specific tuning, hook paths, OIDC client IDs)
3. **Ad-hoc:** `ansible-playbook -e kubernetes_version=1.35` (highest priority)

### Key Required Variables
- `kubernetes_control_plane_ip` - IP proxies listen on (kubeadm will bind APIs here)
- `kubernetes_api_endpoint` - FQDN for clients; must have DNS resolution before playbook run

### Key Optional Variables
- `kubernetes_install_helm`, `kubernetes_install_kustomize` - Control plane tools (default: true)
- `kubernetes_manage_cert_renewal` - Auto-renew kubelet/CA certs (default: true)
- `kubernetes_admission_control_plugins` - List of kube-apiserver admission controllers
- `kubernetes_admission_configuration` - Pod security policies (STIG V-254800)
- `kubernetes_containerd_credentials` - Array of {username, password, registry} for image pulls

### Template Versioning
Control plane role uses **version-specific templates** for kubeadm configurations:
- `encryption-1.33.yaml.j2`, `encryption-1.34.yaml.j2`, `encryption-1.35.yaml.j2` (file name must match `kubernetes_version`)
- Audit, authorization, admission templates similarly versioned
- When adding new versions: copy prior version template, update content (API group changes, feature additions)

## Compliance & Hardening

### CIS Kubernetes Benchmark 1.12
- Each security control mapped in [CIS hardening.md](CIS%20hardening.md)
- Defaults annotated with CIS test numbers (e.g., `# CIS 1.1.12` in main.yml)
- Most controls automated; some require admin runtime governance (default service account isolation)

### STIG DoD Kubernetes
- Mapped in [Stig checklist - Kubernetes.cklb](Stig%20checklist%20-%20Kubernetes.cklb) (view with DoD STIG Viewer)
- Only one unfixed STIG: anonymous API auth (required for kubeadm cluster join despite RBAC restrictions)

### Key Hardening Features
- RBAC default deny (admission-configuration)
- Encrypted at-rest (encryption provider)
- Audit logging enabled (audit-policy)
- PodSecurity admission policies (baseline → privileged escalation)
- mTLS for etcd
- Systemd service hardening (PrivateTmp, NoNewPrivileges, etc.)

## Testing Environment

[test/](test/) provides a local testing harness (dev container required):

### Setup & Execution
1. **VM Provisioning:** `./spin-up-test-environment.sh` creates 6 VMs via cloud-init + QEMU
   - 1 proxy (px.k8s.local)
   - 3 control planes (cp1.k8s.local, cp2.k8s.local, cp3.k8s.local)
   - 2 worker nodes (w1.k8s.local, w2.k8s.local)
2. **Cluster Installation:** `./install.sh` runs Terraform for inventory generation + `ansible-playbook install.yaml`
3. **Inventory:** Terraform auto-generates Ansible inventory from VM definitions; template at [test/inventory_terraform.yaml](test/inventory_terraform.yaml)

### Networking Architecture
- **User-mode networking:** QEMU user device type (no bridge, no host kernel module required)
- **Inter-VM communication:** Socket-based multicast via `socket` device driver on address `224.1.1.1:1234`
- **Host access:** VMs accessible via SSH on random host ports (configured in Terraform)
- **No external connectivity:** VMs isolated from host network by design (tests offline scenarios)

### VM Specifications
- **Resource allocation:** 4GB RAM, 2 CPUs per VM
- **Base image:** Latest Ubuntu LTS (downloaded via cloud-init)
- **Cloud-init config:** [test/cloud-init/](test/cloud-init/) provides network and user-data scripts
  - Network config: Multicast socket device for inter-VM communication
  - User-data: System packages, SSH setup, hostname configuration

### Hardware Requirements & Dev Container Setup
- **Host OS:** Linux with QEMU support (x86-64 only; Apple Silicon untested)
- **Memory:** ≥24GB available (6 VMs × 4GB = 24GB minimum; swap acceptable but slower)
- **Disk:** ≥120GB (6 VMs × 20GB max allocation; typical ~6GB per cluster)
- **WSL2 users:** Enable nested virtualization for better performance
- **Dev container requirement:** Must run within dev container; too many host-specific variables otherwise

### Key Test Files
- [test/inventory_terraform.yaml](test/inventory_terraform.yaml) - Ansible inventory template (Terraform renders with actual VM IPs)
- [test/main.tf](test/main.tf) - Terraform module for QEMU VM provisioning, networking, cloud-init injection
- [test/vars.yaml](test/vars.yaml) - Kubernetes cluster variables for test runs (e.g., `kubernetes_version`, hook paths)
- [test/ansible.cfg](test/ansible.cfg) - Ansible config pointing to `../roles` for role discovery

## Code Patterns & Conventions

### Ansible Style
- **Indentation:** 2 spaces (Ansible convention)
- **Task naming:** Descriptive, CIS/STIG references included (e.g., `# CIS 1.2.11 - Ensure...`)
- **Serial execution:** `serial: 1` for control plane bootstrap (prevents split-brain); `serial: 100` for workers (parallelizes)
- **Become:** `become: true` globally (cluster setup requires root)

### YAML Key Ordering Convention
Play and task keys follow a consistent ordering pattern:

**Play-level ordering:**
```yaml
- name: <play name>
  any_errors_fatal: true
  become: true
  gather_facts: <bool>
  hosts: <inventory group>
  serial: <int>
  vars:
    <variables>
  roles:
    - role: <role name>
```

**Task-level ordering:**
```yaml
- name: <task name>
  loop: <list>
  loop_control:
    <control>
  when: <condition>
  <module name>:
    <module args>
```

**Module argument ordering (example: file/template):**
```yaml
ansible.builtin.file:
  dest: <path>
  group: <group>
  mode: <mode>
  owner: <owner>
  state: <state>
```

This consistent ordering aids readability and is enforced during reviews. Follow the pattern: metadata (name, loop, conditionals) → module execution → module arguments (alphabetical within module).

### Template Generation
- Jinja2 templates for Kubernetes YAML configs (kubeadm patches, auth policies, audit rules)
- Runtime variable substitution: `{{ kubernetes_api_endpoint }}`, `{{ kubernetes_etcd_group_id }}`, etc.
- Version-gating: template selection based on `kubernetes_version` variable

### File Paths (Standard Locations)
- Kubernetes config: `{{ kubernetes_config_directory }}` (typically `/etc/kubernetes`)
- Output/logs: `{{ kubernetes_output_directory }}` (typically `/var/log/kubernetes/`)
- Scripts: `{{ kubernetes_scripts_directory }}` (typically `/usr/local/bin/kubernetes`)

### Error Handling
- `any_errors_fatal: true` on all plays (stop cluster setup on first error)
- `until` + `retries` loops for kubectl waits (e.g., pod ready checks)
- `creates:` clauses on shell tasks (idempotency guard)

## Common Development Tasks

### Adding a new Kubernetes version
1. Copy prior version templates: `cp roles/kubernetes-control-plane/templates/*-1.34.yaml.j2 roles/kubernetes-control-plane/templates/*-1.35.yaml.j2`
2. Update template content (API changes, feature additions) using kubeadm docs
3. Test with `kubernetes_version: 1.35` in vars
4. Run full test harness: `cd test && ./spin-up-test-environment.sh && ./install.sh`

### Adding a new hardening control
1. Update [roles/kubernetes-defaults/defaults/main.yml](roles/kubernetes-defaults/defaults/main.yml) with variable + CIS/STIG annotation
2. Add template or task logic in relevant role (control-plane, worker, etc.)
3. Document in [CIS hardening.md](CIS%20hardening.md)
4. Test in dev container with `./install.sh`

### Creating a new hook
1. Create directory: `example-hooks/{feature}/{hook-point}/`
2. Add YAML task file with standard Ansible syntax
3. Ensure idempotency: use `creates:` or state validation
4. Reference in inventory/group_vars: `kubernetes_hookfiles.{hook_point}: [path]`
5. Test with full playbook run: `ansible-playbook -i inventory install.yaml`

## Files to Reference When Modifying

- **Variable changes:** [roles/kubernetes-defaults/defaults/main.yml](roles/kubernetes-defaults/defaults/main.yml)
- **Control plane config:** [roles/kubernetes-control-plane/tasks/main.yml](roles/kubernetes-control-plane/tasks/main.yml) + [roles/kubernetes-control-plane/templates/](roles/kubernetes-control-plane/templates/)
- **Compliance mappings:** [CIS hardening.md](CIS%20hardening.md), [Stig checklist - Kubernetes.cklb](Stig%20checklist%20-%20Kubernetes.cklb)
- **Example patterns:** [example-hooks/](example-hooks/)
- **Playbook orchestration:** [install.yaml](install.yaml), [upgrade.yaml](upgrade.yaml)
