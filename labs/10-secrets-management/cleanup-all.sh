#!/bin/bash
echo "Cleaning up all Lab 10 scenarios..."
for scenario in scenario-*; do
    if [ -d "$scenario" ]; then
        cd "$scenario" && ./cleanup.sh 2>/dev/null && cd ..
    fi
done
docker swarm leave --force 2>/dev/null || true
echo "Cleanup complete!"
