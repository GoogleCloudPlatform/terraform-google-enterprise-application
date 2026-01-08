# We use build arguments to allow version upgrades without changing the Dockerfile
ARG VLLM_VERSION=v0.8.5

# Security: We pin the exact version of the public image as the base
FROM vllm/vllm-openai:${VLLM_VERSION}

RUN useradd -m -u 1000 -s /bin/bash vllm-runner
USER vllm-runner
ENV HOME="/home/vllm-runner"
