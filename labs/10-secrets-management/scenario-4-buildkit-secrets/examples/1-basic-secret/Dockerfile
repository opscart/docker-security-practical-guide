# File: examples/1-basic-secret/Dockerfile
FROM alpine:latest
 
# Using BuildKit secret mount
RUN --mount=type=secret,id=api_token \
  API_TOKEN=$(cat /run/secrets/api_token) && \
  echo "==================================" && \
  echo "Using API token (masked): ${API_TOKEN:0:8}***" && \
  echo "==================================" && \
  echo "Token would be used for API authentication" && \
  echo "Secret available ONLY during this RUN"
 
CMD ["echo", "App running - secret NOT in final image"]