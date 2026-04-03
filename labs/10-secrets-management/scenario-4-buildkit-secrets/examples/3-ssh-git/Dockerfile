FROM alpine:3.20.3

RUN apk add --no-cache git openssh-client

# Using SSH key secret for git clone
# Secret mounts are read-only, so we copy to use it
RUN --mount=type=secret,id=ssh_key,target=/tmp/ssh_key \
  mkdir -p /root/.ssh && \
  cp /tmp/ssh_key /root/.ssh/id_rsa && \
  chmod 600 /root/.ssh/id_rsa && \
  echo "SSH key copied and secured" && \
  ls -la /root/.ssh/id_rsa && \
  echo "In real scenario: git clone git@github.com:org/private-repo.git" && \
  rm /root/.ssh/id_rsa && \
  echo "SSH key removed after use - NOT in final image"

CMD ["echo", "App with private dependencies - SSH key NOT included"]