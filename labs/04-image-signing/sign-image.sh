#!/bin/bash

echo "Building and signing image..."

# Check prerequisites
if [ ! -f cosign.key ]; then
    echo "✗ Run ./setup-signing.sh first"
    exit 1
fi

if ! docker ps | grep -q registry; then
    echo "✗ Registry not running. Run ./setup-signing.sh"
    exit 1
fi

# Build sample image
cat > Dockerfile << 'DF'
FROM alpine:3.20.3
CMD ["echo", "Signed Image"]
DF

docker build -t localhost:5001/signed-app:v1.0 . -q
docker push localhost:5001/signed-app:v1.0

echo ""
echo "Signing image (enter your key password)..."
cosign sign --key cosign.key localhost:5001/signed-app:v1.0

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Image signed!"
else
    echo "✗ Signing failed"
    exit 1
fi
