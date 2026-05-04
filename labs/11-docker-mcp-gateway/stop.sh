#!/bin/bash
# stop.sh - Stop all MCP agentic platform services

echo "=========================================="
echo "Stopping MCP Agentic Platform"
echo "=========================================="
echo ""

docker-compose down

echo ""
echo "All services stopped."
echo ""
echo "To remove volumes and cleanup completely:"
echo "  ./cleanup.sh"
echo ""