


when using autopilot clusters

FROM golang:1.18 as builder

# Set the working directory
WORKDIR /code

# Copy source files
COPY main.go .
COPY go.mod .

# Set cross-compilation environment variables for ARM64
ARG TARGETOS=linux
ARG TARGETARCH=arm64

# Optionally, you can allow for SKAFFOLD_GO_GCFLAGS to disable compiler optimizations
ARG SKAFFOLD_GO_GCFLAGS

# Set environment variables for cross-compilation
ENV GOOS=${TARGETOS}
ENV GOARCH=${TARGETARCH}

# Build the Go application
RUN go build -gcflags="${SKAFFOLD_GO_GCFLAGS}" -trimpath -o /app main.go


FROM arm64v8/alpine:3
# Define GOTRACEBACK to mark this container as using the Go language runtime
# for `skaffold debug` (https://skaffold.dev/docs/workflows/debug/).
ENV GOTRACEBACK=single
CMD ["./app"]
COPY --from=builder /app .



ccolin@cloudshell:~/skaffold/examples/getting-started (ccolin-experiments)$ cat skaffold.yaml 
apiVersion: skaffold/v4beta11
kind: Config
build:
  artifacts:
  - image: skaffold-example
    platforms: ["linux/amd64"]
  - image: skaffold-example-arm64
    docker:
      dockerfile: Dockerfile.arm64
    platforms: ["linux/amd64"]
manifests:
  rawYaml:
  - k8s-pod.yaml
  - k8s-pod.arm64.yaml



apiVersion: v1
kind: Pod
metadata:
  name: getting-started-t2a
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
    cloud.google.com/machine-family: t2a
    cloud.google.com/compute-class: Performance
  containers:
  - name: getting-started-arm64-t2a-default-image
    image: skaffold-example
---
apiVersion: v1
kind: Pod
metadata:
  name: getting-started-arm64-t2a
spec:
  nodeSelector:
    kubernetes.io/arch: arm64
    cloud.google.com/machine-family: t2a
    cloud.google.com/compute-class: Performance
  containers:
  - name: getting-started-arm64-t2a
    image: skaffold-example-arm64
