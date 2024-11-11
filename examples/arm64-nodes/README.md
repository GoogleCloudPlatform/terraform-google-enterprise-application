# Running ARM64 Nodes on GKE Autopilot

When utilizing Autopilot clusters, you have the option to request ARM nodes. For more details, please visit [this documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/autopilot-arm-workloads).

This documentation will walk you through the essential steps to modify the default `hello-world` example from this repository, enabling it to run on ARM64 nodes instead of the default x86 nodes.

## Modifying the Dockerfile

You will find the original Dockerfile on `6-appsource/hello-world/Dockerfile`. It contains a multi-stage build. At the first stage, in which the code is compiled, you will adapt it to tell the Golang compiler to compile the binary to arm64 instead of x86. At the second stage, you will change the container that runs the binary from a x86 based image, to a arm64 alpine image. The diff below illustrates the necessary changes:

```diff
FROM golang:1.22 as builder
WORKDIR /code
COPY main.go .
COPY go.mod .
# `skaffold debug` sets SKAFFOLD_GO_GCFLAGS to disable compiler optimizations
ARG SKAFFOLD_GO_GCFLAGS
+# Set cross-compilation environment variables for ARM64
+ARG TARGETOS=linux
+ARG TARGETARCH=arm64
+# Set environment variables for cross-compilation
+ENV GOOS=${TARGETOS}
+ENV GOARCH=${TARGETARCH}

RUN go build -gcflags="${SKAFFOLD_GO_GCFLAGS}" -trimpath -o /app main.go

-FROM alpine:3
+FROM arm64v8/alpine:3
# Define GOTRACEBACK to mark this container as using the Go language runtime
# for `skaffold debug` (https://skaffold.dev/docs/workflows/debug/).
ENV GOTRACEBACK=single
CMD ["./app"]
COPY --from=builder /app .
```

## Modifying the Skaffold File

The skaffold file is located on `6-appsource/hello-world/skaffold.yaml`.

You will need to override the values inferred through heuristics by skaffold by adding the `platforms` field:

```diff
apiVersion: skaffold/v4beta10
kind: Config
build:
  tagPolicy:
    gitCommit:
      variant: CommitSha
  artifacts:
  - image: skaffold-example
+   platforms: ["linux/amd64"]
...
```

## Modifying the Kubernetes Manifest

Add a node selector to the pod that runs the application, the node selector will request for the autopilot VM instances with arm64 architecture (C4A Machine Family on Google Compute Engine).

The manifest file is located on `6-appsource/hello-world/k8s-pod.yaml`.

```diff
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
+  nodeSelector:
+    cloud.google.com/machine-family: c4a
  containers:
  - name: getting-started
    image: skaffold-example
```
