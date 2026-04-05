# Lab 06: AI/ML Container Security - Securing Inference Workloads

**Level:** Intermediate  
**Time:** 1-1.5 hours  
**Prerequisites:** Basic Docker knowledge, understanding of REST APIs  

---

## 🎯 Learning Objectives

By the end of this lab, you will understand:

- **ML Container Hardening** - Securing inference workloads with container security best practices
- **Resource Limits** - Preventing resource exhaustion attacks on ML endpoints
- **Input Validation** - Protecting against malicious payloads that could crash inference services
- **Read-Only Filesystems** - Preventing runtime tampering of ML models and application code
- **Non-Root Execution** - Running ML inference as unprivileged user
- **Kubernetes Security Contexts** - Deploying hardened ML workloads in production

---

## 🔴 The Production Problem

**Scenario:** An ML inference API serving sentiment analysis predictions experiences a Denial of Service (DoS) attack.

**The Attack:**

Attackers discovered the `/predict` endpoint accepts JSON text input. They sent:
- Extremely large text payloads (>100MB) causing OOM kills
- Concurrent request floods exhausting CPU resources
- Malformed JSON causing Python exceptions and container restarts

**Impact:**

- Service downtime: 4 hours
- Legitimate users unable to access predictions
- Container restarts triggered cascading failures
- No resource limits = single tenant affected entire node

**Root Cause:**

1. ✅ No input size validation (accepted unlimited text length)
2. ✅ No resource limits (CPU/memory unbounded)
3. ✅ Running as root (compromised container = full access)
4. ✅ Writable filesystem (attacker could modify model files)
5. ✅ No rate limiting or circuit breaking

---

## 📚 What This Lab Covers

### Part 1: Insecure ML Inference Container (Baseline)
- Flask API serving ML predictions
- No security hardening
- Root user execution
- Writable filesystem
- Unbounded resources

### Part 2: Container Hardening
- Read-only root filesystem
- Non-root user execution
- Drop all Linux capabilities
- Resource limits (CPU, memory, PID)
- tmpfs for temporary storage

### Part 3: Input Validation & Rate Limiting
- Input size validation
- Request timeout enforcement
- Graceful error handling

### Part 4: Stress Testing
- Large input payload testing
- Concurrent request simulation
- Resource exhaustion validation

### Part 5: Production Kubernetes Deployment
- Security contexts
- Pod disruption budgets
- Resource requests/limits
- Health checks

---

## 🛠️ Lab Files

```
labs/06-ai-model-security/
├── README.md                    # This file
├── build-ml-container.sh        # Build Flask ML inference container
├── Dockerfile.ml                # Hardened container image
├── inference.py                 # Simple ML inference API
├── requirements.txt             # Python dependencies (Flask)
├── deploy-secure.sh             # Deploy with security hardening
├── secure-deployment.yaml       # Kubernetes deployment manifest
├── monitor-resources.sh         # Resource monitoring script
├── stress-test.sh               # Load testing script
└── cleanup.sh                   # Remove all lab resources
```

---

## 🚀 Quick Start

### Prerequisites

**Required:**
- Docker 20.10+
- 8GB+ RAM available
- `curl` and `jq` installed

**Optional:**
- Kubernetes cluster (for K8s deployment scenario)

### Setup

```bash
# 1. Clone the repository
git clone https://github.com/opscart/docker-security-practical-guide.git
cd docker-security-practical-guide/labs/06-ai-model-security

# 2. Build the ML inference container
./build-ml-container.sh

# 3. Deploy with security hardening
./deploy-secure.sh

# 4. Test the API
curl -X POST http://localhost:5001/predict \
  -H "Content-Type: application/json" \
  -d '{"text":"This API is now secured!"}'

# 5. Run stress tests
./stress-test.sh

# 6. Monitor resources
./monitor-resources.sh

# 7. Clean up
./cleanup.sh
```

---

## 📖 Detailed Walkthrough

### Part 1: Understanding the ML Inference Application

**What the Application Does:**

The `inference.py` Flask application provides a simple ML inference API with three endpoints:

```python
# Health check endpoint
GET /health
Response: {"status": "healthy", "model": "sample-model"}

# Prediction endpoint (simulates ML inference)
POST /predict
Body: {"text": "your text here"}
Response: {"prediction": "positive", "confidence": 0.85, "length": 42}

# Metrics endpoint
GET /metrics
Response: {"requests": 1000, "avg_latency": 0.1, "memory_mb": 256}
```

**Security Vulnerabilities in Baseline:**

```python
# VULNERABILITY #1: No input size validation initially
def predict():
    data = request.get_json()
    text = data.get('text', '')
    # No length check - accepts unlimited size!
    
# VULNERABILITY #2: Running as root (Dockerfile default)
# VULNERABILITY #3: Writable filesystem (can modify code)
# VULNERABILITY #4: No resource limits (unbounded CPU/memory)
```

---

### Part 2: Building the Secure Container

**Review the Dockerfile:**

```bash
cat Dockerfile.ml
```

**Key Security Features:**

```dockerfile
FROM python:3.11.9-slim  # Pinned version (not 'latest')

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir flask==2.3.0  # Pinned version

# Create non-root user
RUN groupadd -r mluser && useradd -r -g mluser mluser

# Copy application
COPY inference.py /app/
RUN chown -R mluser:mluser /app

# Switch to non-root user
USER mluser  # <-- NOT running as root!

EXPOSE 5000

# Health check built into container
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "inference.py"]
```

**Build the container:**

```bash
./build-ml-container.sh
```

**Expected output:**

```
Building ML inference container...
[+] Building 12.3s (10/10) FINISHED
Successfully tagged ml-inference:secure
ML inference container built successfully!
```

**Verify the image:**

```bash
docker images | grep ml-inference
# ml-inference   secure   abc123def456   1 minute ago   176MB
```

---

### Part 3: Deploying with Runtime Security Hardening

**Review the deployment script:**

```bash
cat deploy-secure.sh
```

**Security Flags Explained:**

```bash
docker run -d \
  --name ml-inference \
  --read-only \                        # ← Filesystem is immutable
  --tmpfs /tmp:rw,noexec,nosuid,size=2g \  # ← Temp storage (no binaries)
  --memory="4g" \                      # ← Hard memory limit
  --memory-swap="4g" \                 # ← No swap allowed
  --cpus="2" \                         # ← CPU quota (2 cores max)
  --pids-limit="100" \                 # ← Max 100 processes (fork bomb protection)
  --security-opt=no-new-privileges:true \  # ← Prevent privilege escalation
  --cap-drop=ALL \                     # ← Drop ALL Linux capabilities
  --user=mluser \                      # ← Run as non-root (UID from Dockerfile)
  -p 5001:5000 \                       # ← Expose on port 5001
  -e MODEL_NAME="secure-bert-classifier" \
  ml-inference:secure
```

**What Each Flag Prevents:**

| Flag | Attack Vector Prevented |
|------|------------------------|
| `--read-only` | Runtime code/model tampering, malware installation |
| `--tmpfs /tmp` | Binary execution in temp directory, persistent malware |
| `--memory="4g"` | Memory exhaustion DoS, OOM kills affecting other containers |
| `--cpus="2"` | CPU exhaustion, noisy neighbor problems |
| `--pids-limit="100"` | Fork bomb attacks, process exhaustion |
| `--security-opt=no-new-privileges` | SUID binary exploitation, privilege escalation |
| `--cap-drop=ALL` | Capability-based attacks (mount, network admin, etc.) |
| `--user=mluser` | Root access if container is compromised |

**Deploy the secure container:**

```bash
./deploy-secure.sh
```

**Expected output:**

```
Deploying ML inference with security hardening...
Waiting for service to start...
Testing health endpoint...
{
  "status": "healthy",
  "model": "secure-bert-classifier"
}

ML inference service deployed on port 5001
Test with: curl -X POST http://localhost:5001/predict -H 'Content-Type: application/json' -d '{"text":"sample"}'
```

**Verify security settings:**

```bash
# Check read-only filesystem
docker exec ml-inference touch /test.txt
# Expected: touch: cannot touch '/test.txt': Read-only file system

# Check non-root user
docker exec ml-inference whoami
# Expected: mluser

# Check capabilities dropped
docker exec ml-inference capsh --print | grep Current
# Expected: Current: = (empty set - all capabilities dropped)

# Check resource limits
docker inspect ml-inference | grep -A 5 '"Memory"'
# Expected: "Memory": 4294967296 (4GB)
```

---

### Part 4: Input Validation Implementation

**Review the input validation in `inference.py`:**

```python
@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()
        text = data.get('text', '')
        
        # INPUT VALIDATION: Reject oversized payloads
        if len(text) > 10000:
            return jsonify({"error": "Input too large"}), 400
        
        # Simulate inference (0.1s delay)
        time.sleep(0.1)
        
        result = {
            "prediction": "positive" if len(text) % 2 == 0 else "negative",
            "confidence": 0.85,
            "length": len(text)
        }
        
        return jsonify(result)
    except Exception as e:
        # Graceful error handling (don't leak stack traces)
        return jsonify({"error": str(e)}), 500
```

**Test normal input:**

```bash
curl -X POST http://localhost:5001/predict \
  -H "Content-Type: application/json" \
  -d '{"text":"This is a normal request"}'
```

**Expected response:**

```json
{
  "prediction": "positive",
  "confidence": 0.85,
  "length": 24
}
```

**Test oversized input (should be rejected):**

```bash
# Generate 20,000 character string
LARGE_TEXT=$(python3 -c "print('a' * 20000)")

curl -X POST http://localhost:5001/predict \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"$LARGE_TEXT\"}"
```

**Expected response:**

```json
{
  "error": "Input too large"
}
```

**Why This Matters:**

Without input validation, attackers could:
- Send 100MB+ payloads → OOM kill the container
- Exhaust memory → affect other services on same host
- Cause cascading failures → entire cluster instability

---

### Part 5: Stress Testing

**Run comprehensive stress tests:**

```bash
./stress-test.sh
```

**What the script tests:**

**Test 1: Normal Request (Baseline)**
```bash
curl -X POST http://localhost:5001/predict \
  -H "Content-Type: application/json" \
  -d '{"text":"This is a normal request for sentiment analysis"}'
```

**Test 2: Large Input Rejection**
```bash
# 20,000 character string (exceeds 10,000 limit)
LARGE_TEXT=$(python3 -c "print('a' * 20000)")
curl -X POST http://localhost:5001/predict \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"$LARGE_TEXT\"}"
# Should return: {"error": "Input too large"}
```

**Test 3: Concurrent Requests (Load Test)**
```bash
# Send 10 simultaneous requests
for i in {1..10}; do
  curl -X POST http://localhost:5001/predict \
    -H "Content-Type: application/json" \
    -d '{"text":"concurrent request '$i'"}' &
done
wait
```

**Test 4: Resource Usage Check**
```bash
docker stats ml-inference --no-stream
```

**Expected output:**

```
CONTAINER ID   CPU %     MEM USAGE / LIMIT   MEM %     NET I/O
abc123def456   15.23%    245MiB / 4GiB      6.13%     1.2kB / 890B
```

**Key observations:**
- CPU stays under 50% (2 core limit enforced)
- Memory stays well below 4GB limit
- Large inputs rejected (no memory spike)
- Concurrent requests handled without crashes

---

### Part 6: Resource Monitoring

**Start continuous monitoring:**

```bash
./monitor-resources.sh
```

**Expected output (updates every 1 second):**

```
CONTAINER ID   NAME           CPU %     MEM USAGE / LIMIT   MEM %
abc123def456   ml-inference   12.34%    256MiB / 4GiB      6.40%

PIDS           NET I/O         BLOCK I/O
5              1.23kB / 890B   0B / 0B
```

**What to monitor:**

1. **CPU %** - Should stay under 50% (2 core limit)
2. **MEM USAGE** - Should not approach 4GB limit
3. **PIDS** - Should stay well below 100 (fork bomb protection)
4. **NET I/O** - Spikes indicate high request volume

**Detecting anomalies:**

```bash
# If you see this, investigate:
CPU % > 90%          # ← Possible CPU exhaustion attack
MEM USAGE > 3.5GB    # ← Approaching OOM kill threshold
PIDS > 80            # ← Possible fork bomb attempt
```

**Press Ctrl+C to stop monitoring.**

---

### Part 7: Production Kubernetes Deployment

**Review the secure Kubernetes manifest:**

```bash
cat secure-deployment.yaml
```

**Key Security Features:**

**1. Pod Security Context (applies to all containers):**

```yaml
securityContext:
  runAsNonRoot: true      # Reject root containers
  runAsUser: 1000         # Specific UID
  fsGroup: 1000           # File ownership group
  seccompProfile:
    type: RuntimeDefault  # Apply seccomp filtering
```

**2. Container Security Context:**

```yaml
securityContext:
  allowPrivilegeEscalation: false  # No SUID binaries
  readOnlyRootFilesystem: true     # Immutable filesystem
  capabilities:
    drop:
    - ALL                            # Drop all capabilities
```

**3. Resource Limits:**

```yaml
resources:
  requests:
    memory: "2Gi"   # Guaranteed allocation
    cpu: "1000m"    # Guaranteed 1 core
  limits:
    memory: "4Gi"   # Hard limit (OOM kill if exceeded)
    cpu: "2000m"    # Throttle at 2 cores
```

**4. Health Checks:**

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health
    port: 5000
  initialDelaySeconds: 5
  periodSeconds: 10
```

**5. tmpfs Volume for Temporary Storage:**

```yaml
volumeMounts:
- name: tmp
  mountPath: /tmp
volumes:
- name: tmp
  emptyDir:
    sizeLimit: 2Gi   # Limit temp storage
```

**Deploy to Kubernetes:**

```bash
# Create namespace
kubectl create namespace ml-workloads

# Deploy
kubectl apply -f secure-deployment.yaml

# Verify deployment
kubectl get pods -n ml-workloads
```

**Expected output:**

```
NAME                            READY   STATUS    RESTARTS   AGE
ml-inference-7d5f6c8b9d-abc12   1/1     Running   0          30s
ml-inference-7d5f6c8b9d-def34   1/1     Running   0          30s
ml-inference-7d5f6c8b9d-ghi56   1/1     Running   0          30s
```

**Test the service:**

```bash
# Port-forward to test
kubectl port-forward -n ml-workloads service/ml-inference-service 8080:80

# In another terminal
curl -X POST http://localhost:8080/predict \
  -H "Content-Type: application/json" \
  -d '{"text":"Testing Kubernetes deployment"}'
```

---

## 🔒 Production Security Checklist

### Container Build
- [x] Use pinned base image versions (`python:3.11.9-slim` not `latest`)
- [x] Install pinned dependency versions (`flask==2.3.0`)
- [x] Create and use non-root user (`mluser`)
- [x] Set file ownership correctly (`chown -R mluser:mluser`)
- [x] Add health check to Dockerfile

### Runtime Security
- [x] Read-only root filesystem (`--read-only`)
- [x] tmpfs volumes for writable paths (`--tmpfs /tmp`)
- [x] Drop all capabilities (`--cap-drop=ALL`)
- [x] No new privileges (`--security-opt=no-new-privileges:true`)
- [x] Resource limits (memory, CPU, PID)
- [x] Run as non-root user (`--user=mluser`)

### Application Security
- [x] Input validation (size limits, type checking)
- [x] Graceful error handling (no stack trace leaks)
- [x] Request timeouts
- [x] Health check endpoint
- [x] Metrics endpoint for monitoring

### Kubernetes Security
- [x] Pod security context (`runAsNonRoot: true`)
- [x] Container security context (`readOnlyRootFilesystem: true`)
- [x] Resource requests and limits
- [x] Liveness and readiness probes
- [x] Pod disruption budgets
- [x] Network policies (if needed)

---

## 📊 Before vs. After Comparison

| Security Control | Before (Insecure) | After (Hardened) | Risk Reduction |
|------------------|-------------------|------------------|----------------|
| **Filesystem** | Writable | Read-only + tmpfs | ✅ Prevents tampering |
| **User** | root (UID 0) | mluser (UID 1000) | ✅ Limits impact of compromise |
| **Capabilities** | ALL (default) | NONE (dropped ALL) | ✅ Blocks capability-based attacks |
| **Memory Limit** | Unbounded | 4GB hard limit | ✅ Prevents OOM DoS |
| **CPU Limit** | Unbounded | 2 cores | ✅ Prevents CPU exhaustion |
| **PID Limit** | Unlimited | 100 processes | ✅ Prevents fork bombs |
| **Input Validation** | None | 10,000 char limit | ✅ Blocks oversized payloads |
| **Health Checks** | None | Liveness + Readiness | ✅ Auto-recovery from failures |

---

## 🚨 Common Mistakes

### Mistake #1: Running ML Containers as Root
**Problem:** If compromised, attacker has full container privileges  
**Solution:** Always create and use non-root user (UID 1000+)

### Mistake #2: No Resource Limits
**Problem:** Single container can exhaust node resources  
**Solution:** Set memory, CPU, and PID limits

### Mistake #3: Writable Filesystem
**Problem:** Attacker can modify code, install malware  
**Solution:** `--read-only` + tmpfs for temp storage

### Mistake #4: No Input Validation
**Problem:** Large payloads cause OOM kills  
**Solution:** Validate input size before processing

### Mistake #5: Using 'latest' Tags
**Problem:** Unpredictable updates, dependency drift  
**Solution:** Pin all versions (`python:3.11.9-slim`, `flask==2.3.0`)

---

## 🔄 Clean Up

```bash
# Stop and remove container
./cleanup.sh

# Or manually
docker stop ml-inference
docker rm ml-inference
docker rmi ml-inference:secure

# Kubernetes cleanup
kubectl delete namespace ml-workloads
```

---

## 🎓 Key Takeaways

1. **ML inference containers need the same hardening as any production workload** - read-only FS, non-root user, resource limits

2. **Input validation is critical for ML APIs** - large payloads can exhaust memory and crash services

3. **Resource limits prevent cascading failures** - unbounded CPU/memory usage affects entire node

4. **Read-only filesystems prevent runtime tampering** - attackers can't modify model files or inject code

5. **Kubernetes security contexts provide defense-in-depth** - multiple layers of protection (pod + container contexts)

6. **Health checks enable automatic recovery** - Kubernetes restarts failed containers without manual intervention

---

## 📚 Additional Resources

**Docker Security:**
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

**Kubernetes Security:**
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- [NSA/CISA Kubernetes Hardening Guide](https://www.nsa.gov/Press-Room/News-Highlights/Article/Article/2716980/)

**Related Labs:**
- [Lab 02: Secure Configurations](../02-secure-configs/) - Capabilities, read-only FS, AppArmor
- [Lab 03: Vulnerability Scanning](../03-vulnerability-scanning/) - Trivy for image scanning
- [Lab 05: Network Security Basics](../05-network-security-basics/) - Network isolation

---

## 📝 Lab Completion Checklist

After completing this lab, you should be able to:

- [ ] Build hardened ML inference containers
- [ ] Implement read-only filesystems with tmpfs
- [ ] Configure resource limits (CPU, memory, PID)
- [ ] Drop all Linux capabilities
- [ ] Run containers as non-root user
- [ ] Validate input to prevent resource exhaustion
- [ ] Deploy secure ML workloads to Kubernetes
- [ ] Monitor container resource usage
- [ ] Stress test ML APIs for DoS vulnerabilities

---

## 📧 Questions or Issues?

- **GitHub Issues:** https://github.com/opscart/docker-security-practical-guide/issues
- **OpsCart Guide:** https://opscart.com/docker-security-guide/
- **Author:** Shamsher Khan - [LinkedIn](https://www.linkedin.com/in/shamsher-khan)

---

**Next Lab:** [Lab 07: Supply Chain Security (SBOM & Vulnerability Scanning)](../07-supply-chain-sbom/)  
**Previous Lab:** [Lab 05: Network Security Basics](../05-network-security-basics/)  
**Back to:** [Main README](../../README.md)