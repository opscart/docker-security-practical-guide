# mcp-server/server.py
"""
MCP Server - Model Context Protocol for Docker Container Management
Provides tools for AI agents to interact with Docker containers
"""

from flask import Flask, request, jsonify
import subprocess
import hmac
import hashlib
import json
import time
from datetime import datetime
import redis

app = Flask(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================

# Redis for rate limiting
r = redis.Redis(host='redis', port=6379, decode_responses=True)

# Load API key from Docker secret
with open('/run/secrets/mcp_api_key', 'r') as f:
    MCP_API_KEY = f.read().strip()

# ============================================================================
# SECURITY MIDDLEWARE
# ============================================================================

def verify_signature(agent_id, signature):
    """Verify HMAC signature from agent"""
    expected = hmac.new(
        MCP_API_KEY.encode(),
        agent_id.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected)

def check_rate_limit(agent_id):
    """Rate limiting: 100 requests per hour per agent"""
    key = f"rate_limit:{agent_id}"
    current = r.get(key)
    
    if current and int(current) >= 100:
        return False
    
    pipe = r.pipeline()
    pipe.incr(key)
    pipe.expire(key, 3600)  # 1 hour
    pipe.execute()
    
    return True

def validate_input(data):
    """Basic input validation"""
    if not isinstance(data, dict):
        return False
    
    # Check for common injection patterns
    str_data = json.dumps(data)
    dangerous = ['../', '&&', '||', ';', '|', '`', '$']
    
    for pattern in dangerous:
        if pattern in str_data:
            return False
    
    return True

# ============================================================================
# DOCKER API TOOLS
# ============================================================================

def check_container_logs(container_id, tail_lines=50):
    """
    Retrieve logs from a Docker container for diagnosis
    
    Args:
        container_id: Container ID or name
        tail_lines: Number of recent log lines to retrieve
    
    Returns:
        Container logs as string
    """
    try:
        cmd = [
            "docker", "logs",
            container_id,
            "--tail", str(tail_lines)
        ]
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        
        if result.returncode != 0:
            return f"Error retrieving logs: {result.stderr}"
        
        logs = result.stdout if result.stdout else result.stderr
        
        # Also get container status
        inspect_cmd = ["docker", "inspect", container_id, "--format", "{{.State.Status}}"]
        status_result = subprocess.run(inspect_cmd, capture_output=True, text=True, timeout=10)
        status = status_result.stdout.strip() if status_result.returncode == 0 else "unknown"
        
        return f"Container Status: {status}\n\nLogs:\n{logs}"
        
    except subprocess.TimeoutExpired:
        return "Error: Command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

def restart_container(container_id):
    """
    Restart a Docker container
    
    Args:
        container_id: Container ID or name
    
    Returns:
        Success/failure message
    """
    try:
        # Get container info before restart
        inspect_cmd = ["docker", "inspect", container_id, "--format", "{{.Name}} ({{.State.Status}})"]
        inspect_result = subprocess.run(inspect_cmd, capture_output=True, text=True, timeout=10)
        container_info = inspect_result.stdout.strip() if inspect_result.returncode == 0 else container_id
        
        # Restart container
        cmd = ["docker", "restart", container_id]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        
        if result.returncode != 0:
            raise Exception(f"Docker restart failed: {result.stderr}")
        
        # Wait for container to be running
        time.sleep(2)
        
        # Verify container is running
        status_cmd = ["docker", "inspect", container_id, "--format", "{{.State.Status}}"]
        status_result = subprocess.run(status_cmd, capture_output=True, text=True, timeout=10)
        new_status = status_result.stdout.strip()
        
        return f"Container {container_info} restarted successfully. New status: {new_status}"
        
    except subprocess.TimeoutExpired:
        return "Error: Restart command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

def update_container_resources(container_id, memory_limit=None, cpu_limit=None):
    """
    Update Docker container resource limits
    
    Args:
        container_id: Container ID or name
        memory_limit: Memory limit (e.g., "200m", "1g")
        cpu_limit: CPU limit (e.g., "0.5", "2")
    
    Returns:
        Success/failure message
    """
    try:
        results = []
        
        # Update memory if specified
        if memory_limit:
            cmd = ["docker", "update", "--memory", memory_limit, container_id]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                raise Exception(f"Memory update failed: {result.stderr}")
            
            results.append(f"Memory limit updated to {memory_limit}")
        
        # Update CPU if specified
        if cpu_limit:
            # Docker uses CPUs in decimal format (0.5 = 50%)
            cmd = ["docker", "update", "--cpus", str(cpu_limit), container_id]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                raise Exception(f"CPU update failed: {result.stderr}")
            
            results.append(f"CPU limit updated to {cpu_limit} CPUs")
        
        if not results:
            return "No updates specified (provide memory_limit or cpu_limit)"
        
        # Get updated container info
        inspect_cmd = ["docker", "inspect", container_id, 
                      "--format", "Memory: {{.HostConfig.Memory}}, CPU: {{.HostConfig.NanoCpus}}"]
        inspect_result = subprocess.run(inspect_cmd, capture_output=True, text=True, timeout=10)
        updated_info = inspect_result.stdout.strip() if inspect_result.returncode == 0 else ""
        
        return f"Container {container_id} updated successfully.\n" + "\n".join(results) + f"\n{updated_info}"
        
    except subprocess.TimeoutExpired:
        return "Error: Update command timed out"
    except Exception as e:
        return f"Error: {str(e)}"

# ============================================================================
# MCP PROTOCOL ENDPOINTS
# ============================================================================

@app.route('/mcp/v1/tools', methods=['GET'])
def list_tools():
    """
    MCP: List available tools
    """
    # Verify authentication
    agent_id = request.headers.get('X-Agent-ID')
    signature = request.headers.get('X-Signature')
    
    if not agent_id or not signature:
        return jsonify({"error": "Missing authentication headers"}), 401
    
    if not verify_signature(agent_id, signature):
        return jsonify({"error": "Invalid signature"}), 403
    
    # Return tool schemas
    tools = [
        {
            "name": "check_container_logs",
            "description": "Retrieve logs from a Docker container for diagnosis",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "container_id": {
                        "type": "string",
                        "description": "Container ID or name"
                    },
                    "tail_lines": {
                        "type": "integer",
                        "description": "Number of recent log lines (default: 50)",
                        "default": 50
                    }
                },
                "required": ["container_id"]
            }
        },
        {
            "name": "restart_container",
            "description": "Restart a Docker container to recover from failures",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "container_id": {
                        "type": "string",
                        "description": "Container ID or name"
                    }
                },
                "required": ["container_id"]
            }
        },
        {
            "name": "update_container_resources",
            "description": "Update container resource limits (memory, CPU)",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "container_id": {
                        "type": "string",
                        "description": "Container ID or name"
                    },
                    "memory_limit": {
                        "type": "string",
                        "description": "Memory limit (e.g., '200m', '1g')"
                    },
                    "cpu_limit": {
                        "type": "string",
                        "description": "CPU limit (e.g., '0.5', '2')"
                    }
                },
                "required": ["container_id"]
            }
        }
    ]
    
    return jsonify({
        "jsonrpc": "2.0",
        "result": {
            "tools": tools
        }
    }), 200

@app.route('/mcp/v1/call_tool', methods=['POST'])
def call_tool():
    """
    MCP: Execute a tool
    """
    # Authentication
    agent_id = request.headers.get('X-Agent-ID')
    signature = request.headers.get('X-Signature')
    
    if not agent_id or not signature:
        return jsonify({"error": "Missing authentication headers"}), 401
    
    if not verify_signature(agent_id, signature):
        return jsonify({"error": "Invalid signature"}), 403
    
    # Rate limiting
    if not check_rate_limit(agent_id):
        return jsonify({"error": "Rate limit exceeded"}), 429
    
    # Parse request
    try:
        data = request.get_json()
    except:
        return jsonify({"error": "Invalid JSON"}), 400
    
    # Input validation
    if not validate_input(data):
        return jsonify({"error": "Invalid input detected"}), 400
    
    tool_name = data.get('params', {}).get('name')
    arguments = data.get('params', {}).get('arguments', {})
    
    if not tool_name:
        return jsonify({"error": "Missing tool name"}), 400
    
    # Execute tool
    try:
        if tool_name == "check_container_logs":
            result = check_container_logs(**arguments)
        elif tool_name == "restart_container":
            result = restart_container(**arguments)
        elif tool_name == "update_container_resources":
            result = update_container_resources(**arguments)
        else:
            return jsonify({
                "jsonrpc": "2.0",
                "error": {
                    "code": -32601,
                    "message": f"Tool not found: {tool_name}"
                },
                "id": data.get('id')
            }), 404
        
        # Log action
        log_action(agent_id, tool_name, arguments, result)
        
        # Return MCP response
        return jsonify({
            "jsonrpc": "2.0",
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": result
                    }
                ]
            },
            "id": data.get('id')
        }), 200
        
    except Exception as e:
        return jsonify({
            "jsonrpc": "2.0",
            "error": {
                "code": -32603,
                "message": str(e)
            },
            "id": data.get('id')
        }), 500

# ============================================================================
# AUDIT LOGGING
# ============================================================================

def log_action(agent_id, tool_name, arguments, result):
    """Log tool execution for audit trail"""
    log_entry = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "agent_id": agent_id,
        "tool": tool_name,
        "arguments": arguments,
        "result_preview": result[:200] if isinstance(result, str) else str(result)[:200]
    }
    
    # Log to file
    try:
        with open('/var/log/mcp/audit/actions.log', 'a') as f:
            f.write(json.dumps(log_entry) + '\n')
    except:
        pass  # Don't fail if logging fails

# ============================================================================
# HEALTH CHECK
# ============================================================================

@app.route('/health', methods=['GET'])
def health():
    """
    Health check endpoint for Docker
    """
    # Check Redis connection
    try:
        r.ping()
        redis_status = "healthy"
    except:
        redis_status = "unhealthy"
    
    # Check Docker connectivity
    try:
        subprocess.run(["docker", "ps"], capture_output=True, timeout=5)
        docker_status = "healthy"
    except:
        docker_status = "unhealthy"
    
    overall_status = "healthy" if (redis_status == "healthy" and docker_status == "healthy") else "unhealthy"
    
    return jsonify({
        "status": overall_status,
        "components": {
            "redis": redis_status,
            "docker": docker_status
        }
    }), 200 if overall_status == "healthy" else 503

if __name__ == '__main__':
    # Production-grade Flask config
    app.run(
        host='0.0.0.0',
        port=3000,
        debug=False,  # Never debug=True in production
        threaded=True
    )