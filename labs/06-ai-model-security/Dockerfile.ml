FROM python:3.11.9-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir flask==2.3.0

# Create non-root user
RUN groupadd -r mluser && useradd -r -g mluser mluser

# Copy application
COPY inference.py /app/
RUN chown -R mluser:mluser /app

# Switch to non-root user
USER mluser

EXPOSE 5000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

CMD ["python", "inference.py"]
