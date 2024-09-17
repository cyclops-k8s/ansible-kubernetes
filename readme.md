# Ansible-Kubernetes - CIS hardened

## Purpose

The purpose of this playbook and roles is to install a vanilla Kubernetes cluster with OIDC enabled
with the Calico CNI and the VSphere CPI.

It is a vanilla `kubeadm` cluster that can be managed by `kubeadm` going forward, or for easy upgrades
you can use the `upgrade` playbook.

It uses official helm charts or manifests to install the VSphere CPI and Calico CNI.

It installs HAProxy and Keepalived on the proxy nodes, this is needed for high availability of the cluster's
control plane.

## CIS Benchmark

Review the `CIS hardening.md` to see the status of each benchmark test. Most of them were handeled out of the box
by kubeadm, the ones that could be resolved are.

## STIG's

The Kubernetes STIG Version 2 Release 1, dated 24 July 2024 has also been applied. Using the STIG viewer available for free from the DoD of the US,
you can view the checklist `Stig checklist - Kubernetes.cklb` and review what has been fixed, or not. Of the ones not fixed, there is only one
that is not up to the kubernetes administrator. It is the one related to anonymous auth of the API. The RBAC restricts what the anonymous
user can access and it is required to join nodes to the cluster using Kubeadm.

The stig viewer can be found here: https://public.cyber.mil/stigs/srg-stig-tools/
