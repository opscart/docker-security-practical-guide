#!/bin/bash

echo "Building ML inference container..."

# Create sample inference application
cat > inference.py << 'PYTHON'
from flask import Flask, request, jsonify
import json
import time
import os

app = Flask(__name__)

# Simulate model loading
MODEL_NAME = os.getenv('MODEL_NAME', 'sample-model')
print(f"Loading model: {MODEL_NAME}")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "model": MODEL_NAME})

@app.route('/predict', methods=['POST'])
def predict():
    try:
        data = request.get_json()
        text = data.get('text', '')
        
        # Simulate inference
        time.sleep(0.1)
        
        # Basic validation to prevent resource exhaustion
        if len(text) > 10000:
            return jsonify({"error": "Input too large"}), 400
        
        result = {
            "prediction": "positive" if len(text) % 2 == 0 else "negative",
            "confidence": 0.85,
            "length": len(text)
        }
        
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/metrics', methods=['GET'])
def metrics():
    # Return simple metrics
    return jsonify({
        "requests": 1000,
        "avg_latency": 0.1,
        "memory_mb": 256
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYTHON

# Create Dockerfile
cat > Dockerfile.ml << 'DOCKERFILE'
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
DOCKERFILE

# Create requirements file
cat > requirements.txt << 'REQS'
flask==2.3.0
REQS

# Build image
docker build -t ml-inference:secure -f Dockerfile.ml .

echo "ML inference container built successfully!"
