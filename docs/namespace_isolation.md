# Namespace Isolation in Kubernetes: Network Policies and Istio Authorization Policies with mTLS

## Overview

Namespace isolation is an aspect of Kubernetes security that helps to limit the access of different services and components within the cluster. Two common mechanisms for enforcing namespace isolation are **Network Policies** and **Istio Authorization Policies** in conjunction with **mTLS (Mutual TLS)**. Each approach has its strengths and is suited for different use cases.

## Network Policies

Network Policies are Kubernetes resources that control the traffic flow at the IP ranges and port level. They allow you to define rules that specify how groups of pods can communicate with each other and with other network endpoints.

Network Policies operate at Layer 3-4 (L3-4) of the OSI model. They are implemented within the kernel and enforced on the node-level.

### Use Cases

- Basic allow/deny rules for traffic.
- Situations where fine-grained control of HTTP methods and paths is not required.

## Istio Authorization Policies with mTLS

Istio is a service mesh that provides advanced traffic management, security, and observability features. With Istio, you can use Authorization Policies to define access control rules at the application layer.

Istio operates at Layer 7 (L7) of the OSI model, allowing for more granular control over HTTP requests. It runs in user space and the enforcement point is at the pod level.

### mTLS Modes

- **STRICT Mode:** In this mode, communication between services must use mTLS. This ensures encrypted and authenticated traffic.
- **PERMISSIVE Mode:** This mode allows for both mTLS and non-mTLS traffic. It can be useful during migration or to allow external services to interact with your services or when namespaces can't have istio sidecar proxies.

### Use Cases

- When you need application-aware policies that define specific actions (e.g., GET, PUT, DELETE) on certain endpoints.
- High granularity in access control.
- Observability/Audit requests.

## Comparison Table

| Feature            | Istio Policy               | Network Policy            |
|--------------------|----------------------------|----------------------------|
| **Layer**          | “Service” — L7            | “Network” — L3-4          |
| **Implementation** | User space                 | Kernel                     |
| **Enforcement Point** | Pod                     | Node                       |

## Examples in this Repository

You can find an example for isolating a namespace using Istio in the following [file](../examples/cymbal-bank/6-appsource/cymbal-bank/accounts-contacts/k8s/overlays/development/anthos-service-mesh-security-config.yaml).
