# Lab 11: Docker MCP Gateway for AI-Powered Container Remediation

**An intelligent Docker container management system using the Model Context Protocol (MCP), AutoGen, and GPT-3.5-turbo for automated failure detection and remediation.**

---

## 🎯 **Overview**

This lab demonstrates a production-grade **Docker MCP Gateway** - an AI-powered system that automatically detects and remediates Docker container failures using:

- **Model Context Protocol (MCP)** - Standardized tool interface for AI agents
- **AutoGen** - Multi-agent conversation framework
- **GPT-3.5-turbo** - Decision-making and reasoning
- **Docker API** - Container management and monitoring

**Real-world use case:** Reduce on-call burden by automatically handling common container failures (OOMKilled, health check failures, transient crashes) while escalating complex issues to humans.

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│  Docker Container Failure (OOMKilled, Crash, Unhealthy)     │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  AutoGen AI Agent (GPT-3.5-turbo)                                   │
│  - Receives alert                                            │
│  - Analyzes container state                                  │
│  - Makes remediation decision                                │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  MCP Server (Security Pipeline)                             │
│  ┌──────────────────────────────────────────────────────┐   │
│  │ 1. HMAC Authentication                               │   │
│  │ 2. Redis Rate Limiting (100 req/hour)               │   │
│  │ 3. Input Validation                                  │   │
│  │ 4. Audit Logging                                     │   │
│  └──────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│  Docker API                                                  │
│  - docker logs (diagnose)                                    │
│  - docker restart (remediate)                                │
│  - docker update (scale resources)                           │
└─────────────────────────────────────────────────────────────┘
```

---

## ✨ **Features**

### **AI-Powered Decision Making**
- ✅ Automatic failure classification (OOMKilled, CrashLoop, Exit codes, Health checks)
- ✅ Context-aware remediation (restart vs escalate vs resource scaling)
- ✅ Smart escalation (knows when human intervention is needed)

### **Security Pipeline**
- ✅ HMAC signature authentication
- ✅ Rate limiting (100 requests/hour per agent)
- ✅ Input validation (injection protection)
- ✅ Complete audit trail (all decisions logged)

### **Production-Ready Patterns**
- ✅ Multi-stage Docker builds
- ✅ Non-root users (UID 1000)
- ✅ Read-only filesystems
- ✅ Capability dropping
- ✅ Resource limits
- ✅ Health checks
- ✅ Docker secrets

---

## 📋 **Prerequisites**

- **Docker Desktop** (or Docker Engine)
- **Docker Compose** v2.0+
- **OpenAI API Key** (GPT-3.5-turbo access)
- **macOS/Linux** (tested on macOS)
- **8GB RAM minimum** (for running services + test containers)

---

## 🚀 **Quick Start**

### **1. Setup**

```bash
# Navigate to lab directory
cd labs/11-docker-mcp-gateway

# Create secrets directory
mkdir -p security-pipeline/auth/secrets

# Generate API keys
openssl rand -hex 32 > security-pipeline/auth/secrets/mcp_api_key.txt
openssl rand -hex 32 > security-pipeline/auth/secrets/agent_key.txt

# Set OpenAI API key
export OPENAI_API_KEY="sk-your-key-here"

# Update .env file
cat > .env << EOF
OPENAI_API_KEY=${OPENAI_API_KEY}
AGENT_ID=docker-ops-agent-001
MCP_SERVER_URL=http://mcp-server:3000
LOG_LEVEL=INFO
DOCKER_GID=1
EOF
```

### **2. Start Services**

```bash
# Build and start
./setup.sh
./start.sh

# Verify all services are healthy
docker-compose ps

# Should show:
# mcp-redis          Up (healthy)
# mcp-server         Up (healthy)
# remediation-agent  Up (healthy)
```

### **3. Run Test Scenarios**

```bash
cd scenarios

# Test individual scenarios
./scenario-1-oom.sh           # OOMKilled remediation
./scenario-2-crash.sh         # CrashLoopBackOff escalation
./scenario-3-exit.sh          # Exit code analysis
./scenario-4-healthcheck.sh   # Health check failure

# Or run all scenarios
./run-all-scenarios.sh
```

---

## 🧪 **Test Scenarios**

### **Scenario 1: OOMKilled (Auto-Remediation)**

**Failure:** Container killed due to out-of-memory  
**Expected Behavior:**
1. Agent detects OOMKilled (exit code 137)
2. Agent checks logs to confirm OOM
3. Agent increases memory limit by 50-100%
4. Container can now run successfully

**Result:** ✅ **Validated** - Memory increased from 50MB → 200MB

```bash
./scenario-1-oom.sh

# Output:
# ✓ Container created with 50MB limit
# ✓ OOM triggered
# ✓ Agent increased memory to 200MB
# ✓ SUCCESS: Memory limit was increased by agent!
```

---

### **Scenario 2: CrashLoopBackOff (Escalation)**

**Failure:** Container crashes immediately on startup  
**Expected Behavior:**
1. Agent detects crash loop
2. Agent checks logs (sees repeated "Starting..." with immediate exit)
3. Agent recognizes: Config/code issue (not temporary)
4. Agent escalates to human (does NOT restart)

**Result:** ✅ **Validated** - Agent correctly escalated

```bash
./scenario-2-crash.sh

# Output:
# ✓ Container in crash loop (restart count: 7+)
# ✓ Agent checked logs
# ✓ Agent decision: "This requires manual intervention"
# ✓ Container still crashing (expected - agent didn't touch it)
```

**Key Learning:** Agent knows when NOT to auto-remediate. Crash loops indicate code/config bugs that require human debugging.

---

### **Scenario 3: Exit Code Analysis (Smart Decision)**

**Failure:** Container exited with error code 1  
**Expected Behavior:**
1. Agent detects single exit (not a loop)
2. Agent checks logs: "Error: Database connection failed"
3. Agent identifies: Possibly temporary network issue
4. Agent tries restart (reasonable for network errors)
5. Container still exits → Agent escalates

**Result:** ✅ **Validated** - Agent tried restart, then escalated

```bash
./scenario-3-exit.sh

# Output:
# ✓ Container exited (code 1)
# ✓ Agent saw "Database connection failed"
# ✓ Agent attempted restart (reasonable)
# ✓ Container still exited
# ✓ Agent escalated to human (correct decision)
```

**Key Learning:** Agent attempts remediation for temporary-looking issues but escalates when restart doesn't help.

---

### **Scenario 4: Health Check Failure (Auto-Restart)**

**Failure:** Container running but failing health checks  
**Expected Behavior:**
1. Agent detects "unhealthy" status
2. Agent checks logs (sees 404 on /health endpoint)
3. Agent recognizes: App stuck/deadlocked/unresponsive
4. Agent restarts container to recover

**Result:** ✅ **Fix Applied** - Needs final validation with GPT-3.5-turbo

```bash
./scenario-4-healthcheck.sh

# Expected output:
# ✓ Container unhealthy (health check failing)
# ✓ Agent detects unhealthy status
# ✓ Agent restarts container
# ✓ Container recovered
```

**Key Learning:** Health check failures often indicate app-level issues (deadlock, memory leak) that restart can fix.

---


---

## 📊 **Validation Results**

The agent was validated across all four scenarios in two phases:
**before-fixes** (development data) and **after-fixes** (post-fix
validation runs). Full per-incident audit logs, CSV results, and
the analyzer script are committed under `monitoring/analysis/`.

### Headline metrics

| Phase | Runs | Correct | Avg turns/incident |
|-------|------|---------|--------------------|
| Before fixes | 7 | 3/7 (**43%**) | 22.7 |
| After fixes | 6 | 6/6 (**100%**) | 11.7 |

The 43% → 100% improvement reflects the engineering iteration captured
in the [Troubleshooting](#-troubleshooting) section above. Specifically:

- **Challenge 3** (memory-swap blocking memory updates) → fixed; OOMKilled
  scenario went from 0/2 to 2/2 correct
- **Challenge 6** (agent over-eager on CrashLoopBackOff) → fixed; agent
  now consistently escalates rather than auto-restarting
- **Challenge 9** (conversation looping) → fixed; turn count roughly
  halved across all scenarios

### Reproducing the analysis

```bash
cd monitoring/analysis
python3 analyze_audit.py before-fixes/
python3 analyze_audit.py after-fixes/
```

See [`monitoring/analysis/README.md`](./monitoring/analysis/README.md) for
methodology, dataset descriptions, and known limitations.



---

## 🔧 **How It Works**

### **Agent Decision Flow**

```
Alert Received
    ↓
Check container_id from alert
    ↓
call_tool("check_container_logs", container_id="...", tail_lines="50")
    ↓
Analyze logs + status
    ↓
┌─────────────────────────────────────────────┐
│ Decision Tree:                              │
│                                             │
│ IF status = "OOMKilled"                     │
│   → update_container_resources (memory +50%)│
│                                             │
│ IF status = "CrashLoopBackOff"              │
│   → ESCALATE (never restart crash loops)    │
│                                             │
│ IF status = "exited" (single exit)          │
│   → IF network error: restart               │
│   → ELSE: escalate                          │
│                                             │
│ IF status = "unhealthy"                     │
│   → restart_container (app stuck/deadlock)  │
└─────────────────────────────────────────────┘
    ↓
Execute remediation OR escalate
    ↓
Log decision to audit trail
```

### **MCP Tools Available**

**1. check_container_logs**
```python
call_tool("check_container_logs", 
          container_id="nginx-web", 
          tail_lines="50")
```
Returns: Container status + recent logs

**2. restart_container**
```python
call_tool("restart_container", 
          container_id="nginx-web")
```
Returns: Success message + new status

**3. update_container_resources**
```python
call_tool("update_container_resources", 
          container_id="nginx-web",
          memory_limit="200m",
          cpu_limit="1")
```
Returns: Updated resource limits

---

## 🐛 **Troubleshooting**

### **Challenge 1: Docker CLI Not Installed**

**Problem:** `exec: "docker": executable file not found in $PATH`

**Solution:** Install docker-ce-cli in mcp-server/Dockerfile

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates \
    && curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
       https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
       | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli
```

---

### **Challenge 2: Docker Socket Permission Denied**

**Problem:** `permission denied while trying to connect to the docker API at unix:///var/run/docker.sock`

**Root Cause:** The mcp user (UID 1000) doesn't have permission to access Docker socket (owned by root:docker)

**Solution (Local Testing):**
```yaml
# docker-compose.yml
mcp-server:
  user: root  # ⚠️ Local testing only - NOT for production
```

**Solution (Production):**
```yaml
# Option 1: Match Docker GID
mcp-server:
  group_add:
    - "${DOCKER_GID}"  # Set DOCKER_GID=1 in .env

# Option 2: Use rootless Docker
# Follow Docker rootless mode setup
```

**Security Note:** Running as root is acceptable for local testing but NOT recommended for production. Use proper GID mapping or rootless Docker in production.

---

### **Challenge 3: Memory-Swap Limit Blocking Updates**

**Problem:** Agent tries to increase memory but gets error:
```
Error: new memory limit is larger than the existing memory swap limit
```

**Root Cause:** Container created with `--memory-swap="50m"` which prevents updating memory beyond 50MB

**Solution:** Create containers with unlimited swap for testing:
```bash
docker run -d \
    --name test-container \
    --memory="50m" \
    --memory-swap="-1" \  # -1 = unlimited swap
    nginx:alpine
```

**Production Note:** Set appropriate swap limits based on your infrastructure, but ensure swap >= 2x memory for update flexibility.

---

### **Challenge 4: AutoGen Cache Permission Error**

**Problem:** `PermissionError: Cache directory ".cache/41" does not exist and could not be created`

**Root Cause:** When mcp-server runs as root, the agent also needs root to access shared cache

**Solution:** Add tmpfs mount with root ownership:
```yaml
# docker-compose.yml
agent:
  user: root  # Match mcp-server user
  tmpfs:
    - /app/.cache:size=100m,uid=0,gid=0  # Root ownership
```

---

### **Challenge 5: AutoGen/OpenAI Version Compatibility**

**Problem:** Multiple version conflicts between pyautogen and openai packages

**Tested Combinations:**
- ❌ pyautogen 0.2.32 + openai 1.12.0 → `Client.__init__() got unexpected keyword 'proxies'`
- ❌ pyautogen 0.2.18 + openai 1.12.0 → Same error
- ❌ pyautogen 0.2.0 + openai 0.28.1 → Dependency conflict
- ✅ **pyautogen 0.1.14 + openai 0.28.1** → **WORKING**

**Solution:**
```txt
# agent/requirements.txt
pyautogen==0.1.14
openai==0.28.1
requests==2.31.0
```

**Root Cause:** AutoGen 0.2.x passes parameters to OpenAI client that were removed in OpenAI v1.0+. AutoGen 0.1.14 is the last version compatible with openai 0.28.x API.

---

### **Challenge 6: Agent Too Optimistic on CrashLoopBackOff**

**Problem:** Agent initially tried to restart crash loops instead of escalating

**Root Cause:** Ambiguous logs ("Starting..." repeated) + optimistic decision-making

**Solution:** Updated system message with explicit rule:
```python
4. For CrashLoopBackOff (CRITICAL - DO NOT AUTO-FIX):
   - Check logs to document the issue
   - ALWAYS escalate to human with log details
   - NEVER restart - crash loops indicate code/config bugs
   - Restarting won't fix it and wastes resources
```

**Result:** Agent now correctly escalates CrashLoopBackOff to humans

---

### **Challenge 7: Missing container_id in Tool Calls**

**Problem:** Agent called tools without required `container_id` parameter:
```python
call_tool("check_container_logs", tail_lines="50")  # Missing container_id!
```

**Root Cause:** Agent didn't extract container_id from alert message

**Solution:** Added explicit reminder in system message:
```python
## CRITICAL: Tool Parameter Names (USE EXACTLY AS SHOWN):

**ALWAYS extract container_id from the alert message first!**
The alert contains "Container ID/Name: XXXXX" - use this exact value in all tool calls.
```

**Result:** Agent now consistently includes container_id in all tool calls

---

### **Challenge 8: OpenAI Rate Limits During Testing**

**Problem:** Hitting 10,000 tokens/minute limit repeatedly during testing

**Solutions:**

**Option 1: Reduce conversation turns**
```python
user_proxy = autogen.UserProxyAgent(
    max_consecutive_auto_reply=3,  # Reduced from 10
)
```

**Option 2: Use cheaper model for testing**
```python
config_list = [{
    "model": "gpt-3.5-turbo",  # 60x cheaper than GPT-4
    "api_key": OPENAI_API_KEY,
}]
```

**Option 3: Use local LLM (Ollama)**
```python
# Requires AutoGen with newer OpenAI client
config_list = [{
    "model": "llama3.1:8b",
    "base_url": "http://host.docker.internal:11434/v1"
}]
```

**Note:** Option 3 requires AutoGen 0.2+ which has other compatibility issues. For production validation, stick with GPT-4 or GPT-3.5-turbo.

---

### **Challenge 9: Agent Hallucinating Fake Containers**

**Problem:** After handling real alert, agent creates fake alerts for non-existent containers:
```
Container: memory-hungry-app  ← Doesn't exist!
Container: app-crash-loop     ← Doesn't exist!
```

**Root Cause:** `max_consecutive_auto_reply=10` allowed too many conversation turns

**Solution:** Limit to 3 turns:
```python
user_proxy = autogen.UserProxyAgent(
    max_consecutive_auto_reply=3,  # Prevents runaway conversations
)
```

**Result:** Agent stops after handling the real alert

---

## 🔒 **Production Considerations**

### **Security**

**Current Setup (Local Testing):**
- ⚠️ Running as root for Docker socket access
- ⚠️ Docker socket mounted read-write
- ⚠️ Secrets in filesystem (not vault)

**Production Recommendations:**
1. **Use proper GID mapping** instead of root
2. **Implement rootless Docker** where possible
3. **Store secrets in vault** (HashiCorp Vault, AWS Secrets Manager)
4. **Add TLS** for MCP server communication
5. **Implement proper RBAC** for multi-tenant environments
6. **Monitor audit logs** for suspicious activity

### **Scalability**

**Current Limits:**
- Rate limit: 100 requests/hour per agent
- Single MCP server instance
- No agent orchestration

**Production Scaling:**
1. **Horizontal scaling:** Run multiple MCP servers behind load balancer
2. **Agent pool:** Multiple agents for parallel remediation
3. **Event-driven:** Integrate with Prometheus/Alertmanager for real alerts
4. **Distributed rate limiting:** Redis Cluster for high availability

### **Cost Optimization**

**GPT-4 Costs:**
- ~$0.03 per remediation (assuming 1K tokens)
- ~$30/month for 1000 remediations
- Consider gpt-3.5-turbo for 60x cost reduction

**Alternatives:**
- Fine-tune smaller models on remediation patterns
- Use rule-based system for common failures, LLM for complex cases
- Implement caching for repeated failure patterns

---

## 📊 **Audit Trail**

All agent decisions are logged to `/var/log/agent/audit/` in JSON format:

```json
{
  "timestamp": "2026-05-03T17:17:10Z",
  "agent_id": "docker-ops-agent-001",
  "alert": {
    "container_id": "nginx-oom-test",
    "status": "OOMKilled",
    "description": "Docker container crashed with OOMKilled"
  },
  "tools_called": [
    {
      "tool": "check_container_logs",
      "arguments": {"container_id": "nginx-oom-test", "tail_lines": "50"},
      "result": "Container Status: exited\nLogs: OOM killed...",
      "success": true
    },
    {
      "tool": "update_container_resources",
      "arguments": {"container_id": "nginx-oom-test", "memory_limit": "200m"},
      "result": "Memory limit updated to 200m",
      "success": true
    }
  ],
  "decision": "Increased memory from 50MB to 200MB",
  "outcome": "success"
}
```

---

## 🎓 **Key Learnings**

1. **MCP provides a clean interface** between AI agents and infrastructure tools
2. **Explicit instructions matter** - Generic "check logs and fix" leads to unpredictable decisions
3. **Conservative escalation is safer** - Agent should escalate complex issues rather than guess
4. **Security layers are essential** - Auth, rate limiting, validation, and audit logging
5. **Version compatibility is critical** - AutoGen + OpenAI version combinations matter
6. **Local testing accelerates development** - Ollama/gpt-3.5-turbo for iteration, GPT-4 for validation

---

## 📚 **References**

- **Model Context Protocol (MCP):** https://modelcontextprotocol.io/
- **AutoGen Documentation:** https://microsoft.github.io/autogen/
- **Docker API:** https://docs.docker.com/engine/api/
- **OpenAI GPT-3.5-turbo:** https://platform.openai.com/docs/models/gpt-4

---

## 🤝 **Contributing**

This lab is part of the `docker-security-practical-guide` repository.

**To contribute:**
1. Test scenarios on your infrastructure
2. Report issues or improvements
3. Share production deployment experiences
4. Suggest new remediation scenarios

---

## 📜 **License**

MIT License - see repository root for details

---

## 👤 **Author**

**Shamsher Khan**
- GitHub: [@opscart](https://github.com/opscart)
- Website: [OpsCart.com](https://opscart.com)
- DZone: [Core Member](https://dzone.com/authors/shamsherkhan-1)

**Built for Docker Captain Application** - Inspired by Docker community feedback on MCP integration.

---

## 🎯 **Next Steps**

1. ✅ Complete all 4 scenarios
2. ✅ Document challenges and solutions
3. 🔄 Integrate with production monitoring (Prometheus/Alertmanager)
4. 🔄 Add more remediation patterns (disk pressure, network issues)
5. 🔄 Build web UI for audit trail visualization
6. 🔄 Publish technical blog post on Docker MCP patterns
---

**🐳 Docker MCP Gateway - Bringing AI-powered automation to Docker container management!**