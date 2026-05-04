# agent/agent.py
"""
AutoGen Agent - Container Remediation Agent
FIXED: Actually executes MCP tools (not just talks about them)
"""

import autogen
import os
import json
import hmac
import hashlib
import requests
import re
from datetime import datetime

# ============================================================================
# CONFIGURATION
# ============================================================================

MCP_SERVER_URL = os.getenv('MCP_SERVER_URL', 'http://mcp-server:3000')
AGENT_ID = os.getenv('AGENT_ID', 'docker-ops-agent-001')
MCP_API_KEY = open('/run/secrets/agent_key', 'r').read().strip()
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY')

# ============================================================================
# MCP CLIENT
# ============================================================================

class MCPClient:
    """Client for Model Context Protocol"""
    
    def __init__(self, server_url, agent_id, api_key):
        self.server_url = server_url
        self.agent_id = agent_id
        self.api_key = api_key
        self.tools_cache = None
    
    def _generate_signature(self):
        """Generate HMAC signature for authentication"""
        return hmac.new(
            self.api_key.encode(),
            self.agent_id.encode(),
            hashlib.sha256
        ).hexdigest()
    
    def _make_request(self, method, endpoint, data=None):
        """Make authenticated request to MCP server"""
        headers = {
            'X-Agent-ID': self.agent_id,
            'X-Signature': self._generate_signature(),
            'Content-Type': 'application/json'
        }
        
        url = f"{self.server_url}{endpoint}"
        
        try:
            if method == 'GET':
                response = requests.get(url, headers=headers, timeout=30)
            elif method == 'POST':
                response = requests.post(url, headers=headers, json=data, timeout=30)
            else:
                raise ValueError(f"Unsupported method: {method}")
            
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"[ERROR] MCP request failed: {e}")
            raise
    
    def discover_tools(self):
        """Discover available tools from MCP server"""
        if self.tools_cache:
            return self.tools_cache
        
        response = self._make_request('GET', '/mcp/v1/tools')
        self.tools_cache = response['result']['tools']
        return self.tools_cache
    
    def call_tool(self, tool_name, **arguments):
        """Call a tool via MCP protocol"""
        request_data = {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": tool_name,
                "arguments": arguments
            },
            "id": 1
        }
        
        response = self._make_request('POST', '/mcp/v1/call_tool', request_data)
        
        if 'error' in response:
            raise Exception(f"MCP Error: {response['error']['message']}")
        
        # Extract text from MCP response
        content = response['result']['content']
        if content and len(content) > 0 and content[0]['type'] == 'text':
            return content[0]['text']
        
        return str(response['result'])

# Initialize MCP client
mcp = MCPClient(MCP_SERVER_URL, AGENT_ID, MCP_API_KEY)

# ============================================================================
# TOOL EXECUTION INTERCEPTOR
# ============================================================================

def execute_tool_calls(message_content):
    """
    Parse agent message for call_tool() patterns and execute them
    Returns: (modified_message, tool_results)
    """
    # Pattern: call_tool("tool_name", param="value", ...)
    pattern = r'call_tool\("([^"]+)"(?:,\s*([^)]+))?\)'
    
    matches = re.findall(pattern, message_content)
    
    if not matches:
        return message_content, []
    
    tool_results = []
    modified_message = message_content
    
    for match in matches:
        tool_name = match[0]
        args_str = match[1] if len(match) > 1 and match[1] else ""
        
        # Parse arguments
        arguments = {}
        if args_str:
            # Simple parser: key="value" or key='value'
            arg_pattern = r'(\w+)=["\']([\w\-]+)["\']'
            for arg_match in re.findall(arg_pattern, args_str):
                arguments[arg_match[0]] = arg_match[1]
        
        # Execute tool
        print(f"\n[TOOL EXECUTION] {tool_name}")
        print(f"[ARGUMENTS] {json.dumps(arguments, indent=2)}")
        
        try:
            result = mcp.call_tool(tool_name, **arguments)
            print(f"[RESULT] {result[:200]}...")
            
            tool_results.append({
                "tool": tool_name,
                "arguments": arguments,
                "result": result,
                "success": True
            })
            
            # Replace in message with result
            original_call = f'call_tool("{tool_name}"'
            replacement = f'[EXECUTED] Tool returned: {result[:100]}...'
            modified_message = modified_message.replace(original_call, replacement, 1)
            
        except Exception as e:
            error_msg = f"Tool execution failed: {str(e)}"
            print(f"[ERROR] {error_msg}")
            
            tool_results.append({
                "tool": tool_name,
                "arguments": arguments,
                "error": error_msg,
                "success": False
            })
    
    return modified_message, tool_results

# ============================================================================
# AUTOGEN AGENT CONFIGURATION
# ============================================================================

# LLM configuration
config_list = [{
    "model": "gpt-4",
    "api_key": OPENAI_API_KEY,
}]

# config_list = [{
#     "model": "llama3.1:8b",
#     "api_key": "ollama",  # Dummy key
#     "base_url": "http://host.docker.internal:11434/v1"  # Ollama endpoint
# }]

llm_config = {
    "config_list": config_list,
    "temperature": 0.1,
    "timeout": 120
    # cache_seed removed - not needed with cache directory tmpfs
}

# System message
tools = mcp.discover_tools()
tools_description = "\n".join([f"- {t['name']}: {t['description']}" for t in tools])

system_message = f"""
You are a Docker container remediation agent. Your job is to diagnose and fix Docker container failures automatically.

## Available Tools (via MCP):
{tools_description}

## CRITICAL: Tool Parameter Names (USE EXACTLY AS SHOWN):

**ALWAYS extract container_id from the alert message first!**
The alert contains "Container ID/Name: XXXXX" - use this exact value in all tool calls.

**check_container_logs:**
```python
# ALWAYS use the container_id from the alert
call_tool("check_container_logs", container_id="<value-from-alert>", tail_lines="50")
```
Parameters:
- container_id: **REQUIRED** - Container name or ID from the alert (e.g., "nginx-web", "abc123def456")
- tail_lines: Number of recent log lines (optional, default: 50)

**restart_container:**
```python
call_tool("restart_container", container_id="<value-from-alert>")
```
Parameters:
- container_id: **REQUIRED** - Container name or ID from the alert

**update_container_resources:**
```python
call_tool("update_container_resources", container_id="<value-from-alert>", memory_limit="200m", cpu_limit="1")
```
Parameters:
- container_id: **REQUIRED** - Container name or ID from the alert
- memory_limit: Memory limit (e.g., "100m", "1g") - optional
- cpu_limit: CPU limit (e.g., "0.5", "2") - optional

## Decision-Making Process:
1. Always check_container_logs first to diagnose the issue
2. Based on the error, decide the action:
   - **OOMKilled** (exit code 137): update_container_resources with 50-100% more memory
   - **CrashLoopBackOff**: ALWAYS escalate to human - never auto-restart crash loops
   - **Single exit failure**: Analyze logs, restart ONLY if clearly temporary (network timeout, etc.)
   - **Health check failure**: restart_container (running but unhealthy)

3. For OOMKilled:
   - Check logs to confirm OOM
   - Increase memory by 50-100% (e.g., 100m → 200m)
   - Use update_container_resources

4. For CrashLoopBackOff (CRITICAL - DO NOT AUTO-FIX):
   - Check logs to document the issue
   - ALWAYS escalate to human with log details
   - NEVER restart - crash loops indicate code/config bugs
   - Restarting won't fix it and wastes resources

5. For single container exits:
   - Check logs for error details
   - Only restart if: clear network error, timeout, or "connection refused"
   - Escalate if: code errors, config errors, or unknown cause

6. For Health Check Failures (status: unhealthy):
   - Container is running but health check endpoint failing
   - ALWAYS restart_container (DO NOT escalate)
   - Health check failures = app stuck/deadlocked/unresponsive
   - Restart fixes: memory leaks, deadlocks, stuck threads
   - DO NOT try to fix the health check endpoint itself
   - Simply restart the container

## Important Rules:
- Use parameter names EXACTLY as shown above
- container_id can be container name OR ID
- Always use double quotes for values
- One tool call per decision step
- Provide clear reasoning for each action

## Example Decision Chain for OOMKilled:
```python
# Step 1: Check logs
result = call_tool("check_container_logs", container_id="nginx-web", tail_lines="50")
# Result shows: "Container Status: exited, Exit Code: 137 (OOMKilled)"

# Step 2: Increase memory
result = call_tool("update_container_resources", container_id="nginx-web", memory_limit="200m")
# Result: "Memory limit updated to 200m"

# Step 3: Restart to apply
result = call_tool("restart_container", container_id="nginx-web")
# Result: "Container restarted successfully"
```
"""

# Create assistant
try:
    assistant = autogen.AssistantAgent(
        name="container_remediation_agent",
        llm_config=llm_config,
        system_message=system_message
    )
    print("[AUTOGEN] Assistant agent created successfully")
except Exception as e:
    print(f"[ERROR] Failed to create AutoGen agent: {e}")
    raise

# ============================================================================
# ALERT HANDLER WITH TOOL EXECUTION
# ============================================================================

def handle_alert(alert_data):
    """Process alert and execute remediation with actual tool execution"""
    
    print(f"\n{'='*60}")
    print(f"ALERT RECEIVED: {datetime.now().isoformat()}")
    print(f"{'='*60}")
    print(f"Description: {alert_data.get('description')}")
    print(f"Container: {alert_data.get('container_id')}")
    print(f"Status: {alert_data.get('status')}")
    print(f"{'='*60}\n")
    
    # Create user proxy
    user_proxy = autogen.UserProxyAgent(
        name="alert_system",
        human_input_mode="NEVER",
        max_consecutive_auto_reply=3,  # Limit to 3 turns to prevent runaway conversations
        code_execution_config=False
    )
    
    # Custom reply function that executes tools
    def custom_reply(recipient, messages, sender, config):
        """Intercept messages and execute tool calls"""
        
        if not messages or len(messages) == 0:
            return False, None
        
        last_message = messages[-1]
        content = last_message.get('content', '')
        
        # Check if message contains tool calls
        if 'call_tool(' in content:
            # Execute tools
            modified_content, tool_results = execute_tool_calls(content)
            
            # Return tool results as feedback to agent
            if tool_results:
                results_summary = "\n\n".join([
                    f"Tool: {tr['tool']}\nResult: {tr.get('result', tr.get('error', 'Unknown'))}"
                    for tr in tool_results
                ])
                
                return True, results_summary
        
        return False, None
    
    # Register custom reply function
    user_proxy.register_reply(
        autogen.AssistantAgent,
        custom_reply,
        position=0  # Highest priority
    )
    
    # Alert message
    alert_message = f"""
ALERT: Docker Container Failure Detected

Container ID/Name: {alert_data.get('container_id')}
Status: {alert_data.get('status')}
Description: {alert_data.get('description')}

Please diagnose and remediate this issue. Start by checking the container logs.
Use call_tool("check_container_logs", container_id="...", tail_lines="50") to check logs.
"""
    
    # Start conversation
    user_proxy.initiate_chat(
        assistant,
        message=alert_message
    )
    
    # Extract decision chain
    decision_chain = []
    for msg in user_proxy.chat_messages[assistant]:
        if msg.get('role') == 'assistant':
            decision_chain.append({
                "timestamp": datetime.now().isoformat(),
                "content": msg.get('content', ''),
                "role": "assistant"
            })
        elif msg.get('role') == 'user':
            decision_chain.append({
                "timestamp": datetime.now().isoformat(),
                "content": msg.get('content', ''),
                "role": "tool_result"
            })
    
    # Log audit
    incident_id = f"inc-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    audit_entry = {
        "timestamp": datetime.now().isoformat() + "Z",
        "incident_id": incident_id,
        "agent_id": AGENT_ID,
        "alert": alert_data,
        "decision_chain": decision_chain,
        "resolved": "resolved" in str(decision_chain).lower()
    }
    
    audit_dir = "/var/log/agent/audit"
    os.makedirs(audit_dir, exist_ok=True)
    audit_file = f"{audit_dir}/{incident_id}.json"
    
    with open(audit_file, 'w') as f:
        json.dump(audit_entry, f, indent=2)
    
    print(f"\n[AUDIT] Decision chain logged to {audit_file}")
    
    return decision_chain

# ============================================================================
# MAIN LOOP
# ============================================================================

def main():
    """Main agent loop"""
    
    print(f"\n{'='*60}")
    print(f"Docker Container Remediation Agent (AutoGen)")
    print(f"{'='*60}")
    print(f"Agent ID: {AGENT_ID}")
    print(f"MCP Server: {MCP_SERVER_URL}")
    print(f"AutoGen Version: {autogen.__version__}")
    print(f"{'='*60}\n")
    
    # Create ready file
    with open('/tmp/agent_ready', 'w') as f:
        f.write('ready')
    print("[HEALTH] Agent ready file created\n")
    
    # Discover tools
    try:
        tools = mcp.discover_tools()
        print("Discovered MCP Tools:")
        for tool in tools:
            print(f"  - {tool['name']}: {tool['description']}")
        print()
    except Exception as e:
        print(f"[ERROR] Failed to discover tools: {e}\n")
    
    # Process test alert
    test_alert = os.getenv('TEST_ALERT')
    if test_alert:
        print("[TEST] Processing test alert...\n")
        alert_data = json.loads(test_alert)
        handle_alert(alert_data)
    else:
        print("No test alert provided. Agent is ready and waiting...")
        print("Set TEST_ALERT environment variable to trigger remediation.")
        
        import time
        while True:
            time.sleep(60)

if __name__ == '__main__':
    main()