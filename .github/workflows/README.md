# GitHub Actions CI/CD Workflows

This directory contains automated testing workflows for the ansible-kubernetes project.

## Workflows

### 1. test.yml - Kubernetes Cluster Tests

**Purpose:** Tests fresh installations of Kubernetes clusters across all supported versions and operating systems.

**Trigger:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch with optional parameters

**Test Matrix:**
- **Kubernetes versions:** 1.33, 1.34, 1.35
- **Operating systems:** Ubuntu 24.04, Ubuntu 25.10, CentOS Stream 9, CentOS Stream 10
- **Total combinations:** 12 test scenarios

**Test Steps:**
1. Spin up 7 VMs using KubeVirt (1 proxy, 3 control planes, 3 workers)
2. Install Kubernetes cluster using `install.sh`
3. Verify cluster health (node readiness, pod status)
4. Run smoke tests (deploy nginx, verify replicas)
5. Collect logs on failure
6. Clean up test environment

**Runtime:** ~90 minutes per test combination

**Artifacts:** Logs are uploaded on failure (7-day retention)

### 2. upgrade-test.yml - Kubernetes Cluster Upgrade Tests

**Purpose:** Tests upgrading Kubernetes clusters from older versions to 1.35.

**Trigger:**
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual workflow dispatch with optional start version

**Test Matrix:**
- **Upgrade paths tested:**
  - 1.33 → 1.34 → 1.35
  - 1.34 → 1.35
  - 1.33 → 1.35 (direct, may fail - tests compatibility)
- **Operating systems:** Ubuntu 24.04, CentOS Stream 9
- **Total scenarios:** 3 upgrade paths

**Test Steps:**
1. Spin up test environment
2. Install initial Kubernetes version
3. Deploy test workload (nginx deployment)
4. Upgrade through intermediate versions
5. Verify workload persists through upgrades
6. Verify all nodes reach target version
7. Run post-upgrade smoke tests
8. Clean up

**Runtime:** ~120 minutes per upgrade path

**Artifacts:** Upgrade logs uploaded on failure (7-day retention)

## Requirements

### Self-Hosted Runner Prerequisites

These workflows require a self-hosted GitHub Actions runner with:

1. **Base Operating System:**
   - Ubuntu-based Linux (tested on Ubuntu 22.04+)
   - sudo access for package installation
   - Internet connectivity for downloading dependencies

2. **Automatically Installed Dependencies:**
   The workflows automatically install the following on each run:
   - **OpenTofu** - Infrastructure provisioning (via official installer)
   - **Ansible** - Installed via pipx with all dependencies
   - **Ansible Collections** - Automatically installed from `requirements.yaml`:
     - `cloud.terraform`
     - `community.general`
     - `ansible.posix`
     - `community.dns`
   - **dnspython** - Python DNS library injected into Ansible's virtual environment
   - **kubectl** - Latest stable Kubernetes CLI
   - **jq** - JSON processor for parsing terraform/kubectl output

3. **KubeVirt Environment:**
   - Running Kubernetes cluster with KubeVirt installed
   - DataVolumes enabled
   - Storage class `ceph-block` configured (or modify in tofu config)
   - Sufficient resources for 7 VMs per test

4. **VM Resources (per test):**
   - 7 VMs × 4GB RAM = 28GB RAM minimum
   - 7 VMs × 2 CPUs = 14 vCPUs minimum
   - ~140GB storage (20GB max per VM)

5. **Network Access:**
   - Access to OS image repositories (http://assets.cyclops-assets/os-images/)
   - Or configure custom image URLs
   - Access to package repositories (Ubuntu/Debian apt, pip, etc.)
   - Access to OpenTofu installer (get.opentofu.org)
   - Access to Kubernetes release repositories (dl.k8s.io)

6. **Runner Environment:**
   - Runner must have access to `~/.kube/config` for KubeVirt operations
   - SSH client installed
   - Git installed (for repository checkout)

## Dependency Installation

The workflows automatically handle all dependency installation at the start of each job. You don't need to pre-install any tools on your self-hosted runner except for:
- A working `sudo` setup
- Basic build tools (usually already present)
- Access to the internet for downloading packages

The installation process includes:
1. **Package manager updates** - Ensures latest package lists
2. **pipx installation** - For isolated Python application management
3. **Ansible via pipx** - Clean, isolated Ansible installation with all dependencies
4. **dnspython injection** - Injected into Ansible's virtual environment using `pipx inject`
5. **Ansible collections** - All required collections from requirements.yaml
6. **OpenTofu** - Official installer script from get.opentofu.org
7. **kubectl** - Latest stable version from Kubernetes releases
8. **jq** - For JSON parsing in shell scripts

Each installation step includes verification to confirm successful setup.

## Manual Workflow Execution

### Test Specific Version and OS

```bash
# From GitHub UI: Actions → Kubernetes Cluster Tests → Run workflow
# Parameters:
#   kubernetes_version: 1.35
#   os_image: ubuntu-24.04
```

### Test Specific Upgrade Path

```bash
# From GitHub UI: Actions → Kubernetes Cluster Upgrade Tests → Run workflow
# Parameters:
#   start_version: 1.33
#   os_image: centos9
```

## Workflow Customization

### Testing Additional Versions

To add support for new Kubernetes versions:

1. Add version-specific templates to `roles/kubernetes-control-plane/templates/`
2. Update the matrix in both workflow files:
   ```yaml
   matrix:
     kubernetes_version:
       - "1.33"
       - "1.34"
       - "1.35"
       - "1.36"  # Add new version
   ```

### Testing Additional Operating Systems

To add new OS distributions:

1. Update `ci-cd/test/spin-up-test-environment.sh` with new OS image URLs
2. Add to workflow matrix:
   ```yaml
   matrix:
     os_image:
       - ubuntu-24.04
       - centos9
       - debian-12  # Add new OS
   ```

### Adjusting Timeouts

Default timeouts:
- **test.yml:** 90 minutes per job
- **upgrade-test.yml:** 120 minutes per job

Adjust in workflow file:
```yaml
jobs:
  test-cluster:
    timeout-minutes: 90  # Increase if needed
```

### Storage Class Configuration

The default storage class is `ceph-block`. To use a different storage class:

1. Modify `ci-cd/test/tofu/machines.tf` or relevant terraform file
2. Update storage class references in the tofu configuration

## Monitoring and Debugging

### View Test Results

1. Navigate to **Actions** tab in GitHub repository
2. Select workflow run
3. View individual job logs

### Download Failure Logs

When tests fail, logs are automatically collected:
- Kubelet logs (500-1000 lines per node)
- Containerd logs
- Kubernetes events
- Node status
- Pod status

Download from: **Actions → Workflow Run → Artifacts**

### Common Failure Scenarios

1. **VM Startup Timeout:**
   - Verify KubeVirt resources available
   - Check storage class provisioning
   - Review QEMU process status

2. **SSH Connection Failures:**
   - Verify network connectivity in KubeVirt
   - Check cloud-init completion
   - Review security policies

3. **Cluster Installation Failures:**
   - Check Ansible playbook logs in job output
   - Verify kubeadm prerequisites
   - Review node requirements (CPU, RAM, disk)

4. **Upgrade Failures:**
   - Verify version compatibility
   - Check for breaking changes between versions
   - Review kubeadm upgrade logs

## Integration with Pull Requests

Both workflows run automatically on pull requests, providing:
- ✅ Status checks for all test combinations
- 📊 Test summary in PR checks
- 📝 Detailed logs via job links

**Branch Protection:** Consider requiring these checks before merging:
- `test-cluster` job success
- `test-upgrade` job success (for sequential upgrades)

## Cost and Resource Optimization

### Reducing Test Matrix

For faster PR checks, consider:
```yaml
# Reduced matrix for PRs
matrix:
  kubernetes_version: ["1.35"]  # Test only latest
  os_image: ["ubuntu-24.04"]     # Test only primary OS
```

### Parallel Execution

Jobs run in parallel by default. Limit concurrent jobs if resources are constrained:
```yaml
jobs:
  test-cluster:
    strategy:
      max-parallel: 2  # Limit to 2 concurrent tests
```

### On-Demand Testing

For development branches, consider:
```yaml
on:
  push:
    branches:
      - main  # Only main branch
  pull_request:
    branches:
      - main
  workflow_dispatch:  # Keep manual trigger
```

## Troubleshooting

### Workflow Not Running

1. Verify self-hosted runner is online: **Settings → Actions → Runners**
2. Check runner labels match: `runs-on: self-hosted`
3. Review runner logs for errors

### Test Environment Conflicts

If multiple tests run simultaneously on the same runner:
- VM names include `GITHUB_RUN_NUMBER` for uniqueness
- Cleanup always runs (even on failure)
- Consider dedicated runners for CI/CD

### Storage Exhaustion

Monitor storage on runner host:
- Each test uses ~20GB (max allocation per VM)
- Cleanup removes VMs but may leave orphaned volumes
- Periodically run: `kubectl get pvc -A` and clean up

## Contributing

When modifying workflows:
1. Test changes on a feature branch first
2. Use `workflow_dispatch` for manual testing
3. Monitor resource usage during test runs
4. Update this README with any new requirements or procedures
