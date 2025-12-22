# Removes ONLY scenario 1 containers
docker rm -f vulnerable-container
docker rm -f escape-container

# Cleans scenario 1 proof files
rm -f /tmp/PWNED_PROOF.txt

# Optional: Remove scenario 1 artifacts only