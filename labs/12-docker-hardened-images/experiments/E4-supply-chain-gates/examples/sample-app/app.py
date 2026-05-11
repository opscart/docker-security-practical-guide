"""DHI Sample App — minimal Flask service for E4 supply chain demo.

This exists to be:
  1. A real (not synthetic) container image that gets built, signed,
     attested, and verified by the supply chain gate workflow.
  2. Small enough that the SBOM delta vs. the DHI base shows only the
     packages OUR app adds (Flask + transitive deps).

If you're reading this as part of the lab, the interesting code is in
.github/workflows/supply-chain-gate.yml — not this app.
"""

import os
import sys

from flask import Flask, jsonify

app = Flask(__name__)

# Read these at startup so they appear in /healthz output, proving the
# container runtime environment is what we built.
BUILD_INFO = {
    "base_image": "dhi.io/python:3.13",
    "python_version": sys.version.split()[0],
    "running_as_uid": os.getuid(),
    "service": "dhi-sample-app",
}


@app.route("/")
def root():
    return jsonify({
        "message": "Hello from a DHI-based service",
        "build": BUILD_INFO,
    })


@app.route("/healthz")
def healthz():
    return jsonify({"status": "ok", "build": BUILD_INFO})


if __name__ == "__main__":
    # Bind to 0.0.0.0 so the container is reachable on its mapped port.
    # Flask's dev server is fine for this lab demo; production would use
    # gunicorn/uvicorn behind a proper ingress — but that's E5 territory.
    app.run(host="0.0.0.0", port=8080)