# Namespace Isolation in Kubernetes: Network Policies and Istio Authorization Policies with mTLS

## Overview

Namespace isolation is an aspect of Kubernetes security that helps to limit the access of different services and components within the cluster. Two common mechanisms for enforcing namespace isolation are **Network Policies** and **Istio Authorization Policies** in conjunction with **mTLS (Mutual TLS)**.

## Network Policies

Network Policies are Kubernetes resources that control the traffic flow at the IP ranges and port level. They allow you to define rules that specify how groups of pods can communicate with each other and with other network endpoints.

Network Policies operate at Layer 3-4 (L3-4) of the OSI model. They are implemented within the kernel and enforced on the node-level.

## Istio Authorization Policies with mTLS

Istio operates at Layer 7 (L7) of the OSI model, allowing for more granular control over HTTP requests. It runs in user space and the enforcement point is at the pod level.

### Use Cases

- When you need application-aware policies that define specific actions (e.g., GET, PUT, DELETE) on certain endpoints.
- High granularity in access control.
- Observability/Audit requests.

## Comparison Table

| Feature            | Istio Policy               | Network Policy            |
|--------------------|----------------------------|----------------------------|
| **Layer**          | L7            | L3-4          |
| **Implementation** | User space                 | Kernel                     |
| **Enforcement Point** | Pod                     | Node                       |

## Examples in this Repository

Network policies for cymbal-bank isolation are configured on 3-fleetscope in this repository.
