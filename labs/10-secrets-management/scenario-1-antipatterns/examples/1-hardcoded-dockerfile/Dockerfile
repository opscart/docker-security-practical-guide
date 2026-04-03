FROM python:3.9.20-slim

WORKDIR /app

# ANTI-PATTERN: Hardcoded secret in Dockerfile
# This will be visible in docker history FOREVER
RUN echo "DB_PASSWORD=SuperSecret123" >> /app/config && \
    echo "API_KEY=sk-hardcoded-key-12345" >> /app/config

COPY app.py .

CMD ["python", "app.py"]