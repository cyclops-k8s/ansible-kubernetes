# CIS Benchmark

I used the CIS Kubernetes Benchmark 1.12

## 1.1 - Control plane

### 1.1.1 - 1.1.11

Set by default

### 1.1.12 - Ensure that the etcd data directory ownership is set to etcd:etcd

Fixed

### 1.1.13 - 1.1.19

Set by default

### 1.1.20 - Ensure that the Kubernetes PKI certificate file permissions are set to 600 or more restrictive (Manual)

Fixed

### 1.1.21

Set by default

## 1.2 - API Server

### 1.2.1

Disabling anonymousAuth breaks joining nodes to the cluster

### 1.2.2

Set by default

### 1.2.3

We use externalIP services

### 1.2.4

Set by default

### 1.2.5 - Ensure that the --kubelet-certificate-authority argument is set as appropriate (Automated)

Fixed using automatic certificate renewal and issuing to kubelets

### 1.2.6 - Ensure that the --authorization-mode argument is not set to AlwaysAllow
### 1.2.7 - Ensure that the --authorization-mode argument includes Node
### 1.2.8 - Ensure that the --authorization-mode argument includes RBAC

We set the auth mode to RBAC,Node by default with the ability to add webhooks

### 1.2.9 - Ensure that the admission control plugin EventRateLimit is set (Manual)

**Not implemented yet**

### 1.2.10

Set by default

### 1.2.11 - Ensure that the admission control plugin AlwaysPullImages is set (Manual)

Fixed

### 1.2.12 - 1.2.14

Set by default

### 1.2.15

Fixed

### 1.2.16 - Ensure that the --audit-log-path argument is set

Fixed

### 1.2.17 - Ensure that the --audit-log-maxage argument is set to 30 or as appropriate

Fixed

### 1.2.18 - Ensure that the --audit-log-maxbackup argument is set to 10 or as appropriate (Automated)

Fixed

### 1.2.19 - Ensure that the --audit-log-maxsize argument is set to 100 or as appropriate (Automated)

Fixed

### 1.2.20 - Ensure that the --request-timeout argument is set as appropriate

Set by default

### 1.2.21 - 1.2.28

Set by default

### 1.2.29 - Ensure that the API Server only makes use of Strong Cryptographic Ciphers (Manual)

Fixed

### 1.2.30 - Ensure that the --service-account-extend-token-expiration parameter is set to false

Fixed

## 1.3 - Controller Manager

### 1.3.1 Ensure that the --terminated-pod-gc-threshold argument is set as appropriate

Fixed

### 1.3.2 - Ensure that the --profiling argument is set to false

Fixed

### 1.3.3 - 1.3.7

Set by default

## 1.4 - Scheduler

### 1.4.1 - Ensure that the --profiling argument is set to false

Fixed

### 1.4.2

Set by default

## 2 - Etcd

### 2.1 - 2.7

Set by default

## 3.1 - Authentication and Authorization

### 3.1.1 - 3.1.3

We use oauth as recommended

## 3.2 - Logging

### 3.2.1 - Ensure that a minimal audit policy is created (Manual)

Fixed

### 3.2.2 - Ensure that the audit policy covers key security concerns (Manual)

Fixed

## 4 - Worker Nodes

## 4.1 - Worker node configuration files

Service file location: `/usr/lib/systemd/system/kubelet.service`

### 4.1.1 - Ensure that the kubelet service file permissions are set to 600 or more restrictive

Fixed

### 4.1.2

Set by default

### 4.1.3 - If proxy kubeconfig file exists ensure permissions are set to 600 or more restrictive (Manual)

Set by default - config file is stored in the container

### 4.1.4 - If proxy kubeconfig file exists ensure ownership is set to root:root (Manual)

Set by default - config file is stored in the container

### 4.1.5 - 4.1.8

Set by default

### 4.1.9 -  If the kubelet config.yaml configuration file is being used validate permissions set to 600 or more restrictive (Automated)

Fixed

### 4.1.10

Set by default

## 4.2 - Kubelet

### 4.2.1 - 4.2.4

Set by default

### 4.2.5 - Ensure that the --streaming-connection-idle-timeout argument is not set to 0 (Manual)

Fixed, setting to 5m per STIG recommendation

### 4.2.6, 4.2.7

Set by default

### 4.2.8 Ensure that the eventRecordQPS argument is set to a level which ensures appropriate event capture (Manual)

Set by default

### 4.2.9 - Ensure that the --tls-cert-file and --tls-private-key-file arguments are set as appropriate (Manual)

Setting serverTLSBootstrap resolves this

### 4.2.10

Set by default

### 4.2.11 - Verify that the RotateKubeletServerCertificate argument is set to true (Manual)

Set by default

### 4.2.12 - Ensure that the Kubelet only makes use of Strong Cryptographic Ciphers (Manual)

Fixed

### 4.2.13 - Ensure that a limit is set on pod PIDs (Manual)

Fixed

### 4.2.14 - Ensure that the --seccomp-default parameter is set to true

Fixed

## 4.3 - Kube Proxy

### 4.3.1 - Ensure that the kube-proxy metrics service is bound to localhost (Automated)

Fixed

## 5 - Policies

## 5.1 - RBAC and Service Accounts

### 5.1.1 - 5.1.13

### 5.1.1 - 5.1.4

Set by default

### 5.1.5 - Disable service account automount

Fixed for initally created namespaces, it's a mnaul process to maintain the configuration on all default service accounts

### 5.1.6 - 5.1.13

Set by default
