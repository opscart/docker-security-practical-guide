# Troubleshooting Guide

This guide covers problems shared across multiple labs. Each lab README remains the source of truth for lab-specific prerequisites, commands, expected output, and cleanup.

Do not apply generic cleanup commands to every lab. Some labs intentionally create evidence files, Kubernetes resources, Docker Swarm state, Vault data, or local registries.

## Before Troubleshooting

Capture the environment first:

```bash
docker version
docker info
docker compose version
uname -a
```

For Kubernetes-based labs:

```bash
kubectl version --client
kubectl cluster-info
kubectl get nodes -o wide
```

When opening an issue, include:

- Operating system and architecture
- Docker Engine or Docker Desktop version
- Docker Compose version
- Lab number and exact command
- Full error output
- Relevant container logs
- Changes made from the documented lab instructions

## Docker Daemon and Permissions

### Permission Denied Connecting to Docker

**Typical error**

```text
permission denied while trying to connect to the Docker daemon socket
```

**Linux**

```bash
sudo usermod -aG docker "$USER"
newgrp docker
docker info
```

Log out and back in if the new group membership is not applied.

> Membership in the `docker` group grants daemon-level control and should be treated as root-equivalent access.

**macOS and Windows**

Confirm Docker Desktop is running, then retry:

```bash
docker info
```

### Docker Daemon Not Running

**Linux**

```bash
sudo systemctl status docker
sudo systemctl start docker
```

**Docker Desktop**

Open Docker Desktop and wait until the engine reports that it is running.

## Docker Compose Compatibility

Use Compose v2 syntax:

```bash
docker compose version
docker compose up
docker compose down
```

Some older examples may use `docker-compose`. Prefer `docker compose` unless a lab explicitly requires otherwise.

## Port Conflicts

**Typical error**

```text
port is already allocated
```

Find the process or container using the port:

```bash
docker ps --format 'table {{.Names}}\t{{.Ports}}'
lsof -i :8080
```

Stop the conflicting workload or update the lab's documented port mapping. Do not arbitrarily change internal service ports without reviewing dependent configurations.

## Image Pull and Registry Authentication

Inspect the exact pull error:

```bash
docker pull IMAGE_NAME
docker login REGISTRY_HOST
```

Common causes:

- Authentication required
- Incorrect registry hostname
- Unsupported architecture
- Rate limits
- Missing or mistyped image tag
- Corporate proxy or TLS interception

For Docker Hardened Images, follow the authentication instructions in [Lab 12](../labs/12-docker-hardened-images/).

## Script Permission and Line-Endings

### Permission Denied Running a Script

```bash
chmod +x script-name.sh
./script-name.sh
```

### `/bin/bash^M` or `bad interpreter`

The file likely uses Windows CRLF line endings.

```bash
sed -i.bak 's/\r$//' script-name.sh
chmod +x script-name.sh
```

On Linux with `dos2unix` installed:

```bash
dos2unix script-name.sh
```

## Memory and Resource Problems

### Container Killed by OOM

Inspect the container:

```bash
docker inspect CONTAINER_NAME \
  --format '{{.State.OOMKilled}} {{.State.ExitCode}} {{.State.Error}}'
```

Review current usage:

```bash
docker stats --no-stream
```

For Docker Desktop, increase the VM memory allocation when the lab requires more memory.

For Compose workloads, inspect the lab's resource configuration before changing limits. Lab 11 intentionally tests OOM behavior, so an OOM event may be expected rather than an environment failure.

### Disk Space Exhaustion

```bash
docker system df
df -h
```

Review objects before deleting them:

```bash
docker ps -a
docker image ls
docker volume ls
docker network ls
```

Avoid `docker system prune --volumes` unless you understand which lab evidence and persistent data will be removed.

## Falco Installation Issues

**Typical symptoms**

- Falco fails to start
- Kernel module cannot load
- Driver or probe mismatch

On Linux, verify kernel headers:

```bash
uname -r
sudo apt-get update
sudo apt-get install "linux-headers-$(uname -r)"
```

Review Falco's current driver-selection guidance before forcing a specific kernel module or eBPF mode:

- [Falco installation documentation](https://falco.org/docs/setup/)

The previous troubleshooting file included a privileged `docker run` command with `latest`. It is intentionally not carried forward as a default fix because driver setup is version- and platform-dependent and privileged execution should not be suggested without context.

## Security Tool Installation

Verify tools independently:

```bash
trivy --version
syft version
grype version
cosign version
```

Use official installation documentation:

- [Trivy](https://trivy.dev/)
- [Syft](https://github.com/anchore/syft)
- [Grype](https://github.com/anchore/grype)
- [Cosign](https://docs.sigstore.dev/cosign/)

The repository's shared setup instructions are in [setup-guide.md](./setup-guide.md). Lab-specific version requirements remain in the lab README.

## Certificate and TLS Problems

Confirm OpenSSL is available:

```bash
openssl version
```

For Lab 08:

```bash
cd labs/08-network-security/certs
chmod +x generate-certs.sh
./generate-certs.sh
```

If TLS still fails, inspect:

- Certificate subject and validity
- File permissions
- Container mount paths
- Nginx configuration
- Hostname used by the client
- Whether the lab uses a self-signed certificate

## Docker Networks

List networks:

```bash
docker network ls
```

Inspect the relevant network:

```bash
docker network inspect NETWORK_NAME
```

Use the cleanup script provided by the selected lab rather than deleting all Docker networks.

For Lab 08:

```bash
cd labs/08-network-security
./cleanup.sh
```

## Kubernetes-Based Labs

### Cluster Not Reachable

```bash
kubectl config current-context
kubectl cluster-info
kubectl get nodes
```

For kind-based labs:

```bash
kind get clusters
docker ps --filter name=kind
```

### Admission Policy Does Not Trigger

Check policy and webhook status:

```bash
kubectl get validatingwebhookconfigurations
kubectl get mutatingwebhookconfigurations
kubectl get clusterpolicies,policies -A
kubectl get policyreports,clusterpolicyreports -A
```

For Kyverno-specific problems, follow the Lab 12 documentation and inspect the Kyverno pods:

```bash
kubectl get pods -n kyverno
kubectl logs -n kyverno -l app.kubernetes.io/part-of=kyverno --tail=200
```

## Secrets and Credentials

Never post real credentials in issues or logs.

Before sharing output, review it for:

- API keys
- Registry tokens
- Vault tokens
- Cloud credentials
- SSH keys
- `.env` values
- Docker authentication files

Lab 11 requires generated local keys and an OpenAI API key. Lab 13 may interact with agent configuration and sandbox environments. Follow their README instructions exactly and use test-only credentials.

## Lab-Specific Troubleshooting

Use these documents before opening a general issue:

- [Lab 09 Testing Guide](../labs/09-runtime-escape/TESTING-GUIDE.md)
- [Lab 10 README](../labs/10-secrets-management/)
- [Lab 10 Tier 2 VM Setup](../labs/10-secrets-management/TIER2-VM-SETUP.md)
- [Lab 11 README](../labs/11-docker-mcp-gateway/)
- [Lab 11 Analysis Notes](../labs/11-docker-mcp-gateway/monitoring/analysis/README.md)
- [Lab 12 Troubleshooting](../labs/12-docker-hardened-images/docs/troubleshooting.md)
- [Lab 12 Runbook](../labs/12-docker-hardened-images/docs/runbook.md)
- [Lab 13 README](../labs/13-ai-context-poisoning/)

## Cleanup and Recovery

Before cleanup, record what the lab created:

```bash
docker ps -a
docker image ls
docker volume ls
docker network ls
```

Run the lab's cleanup script where provided:

```bash
./cleanup.sh
```

Some labs use different commands such as `stop.sh`, `cleanup-all.sh`, or platform teardown scripts. Read the lab README before removal.

## Getting Help

1. Re-run the failing command and capture its complete output.
2. Review the selected lab README.
3. Review this shared troubleshooting guide.
4. Search existing repository issues.
5. Open a new issue with sanitized diagnostic information.

Repository issues:

- [Report a problem](https://github.com/opscart/docker-security-practical-guide/issues)
