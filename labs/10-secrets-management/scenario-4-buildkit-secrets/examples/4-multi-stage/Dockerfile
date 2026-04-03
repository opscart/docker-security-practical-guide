# File: examples/4-multi-stage/Dockerfile
# Build stage - uses secrets
FROM alpine:3.20.3 AS builder
 
RUN apk add --no-cache curl
 
# Download artifact using secret token
RUN --mount=type=secret,id=build_secret \
  TOKEN=$(cat /run/secrets/build_secret) && \
  echo "Build stage: Using secret token ${TOKEN:0:10}***" && \
  echo "Downloaded artifact securely" > /artifact.txt
 
# Final stage - NO secrets
FROM alpine:3.20.3
 
# Copy artifact from builder (not the secret!)
COPY --from=builder /artifact.txt /app/artifact.txt
 
# Verify secret is NOT in final image
RUN echo "Final stage: Secret is NOT here" && \
  test ! -f /run/secrets/build_secret && \
  echo "✓ Verified: No secrets in final image"
 
CMD ["cat", "/app/artifact.txt"]
 