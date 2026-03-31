FROM alpine:latest

# This Dockerfile is fine, but demonstrates git history leak
RUN echo "Check git history for leaked_secret.txt"

CMD ["echo", "Secrets should never be committed to git!"]