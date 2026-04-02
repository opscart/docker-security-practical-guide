FROM python:3.9.20-slim

# ANTI-PATTERN: Secret passed as build argument
# Visible in docker history and build cache
ARG SECRET_TOKEN
RUN echo "Token: ${SECRET_TOKEN}" > /tmp/token.txt

WORKDIR /app
COPY config.json .

CMD ["cat", "/tmp/token.txt"]