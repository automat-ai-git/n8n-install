ARG OPENCLAW_VERSION=latest

# Stage 1: Get the static Docker CLI (the agent drives the host daemon via the mounted socket)
FROM docker:cli AS docker-cli

# Stage 2: OpenClaw with the Docker CLI (the base image currently ships openssh-client, which 'ssh host' needs)
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION}

USER root
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
USER node
