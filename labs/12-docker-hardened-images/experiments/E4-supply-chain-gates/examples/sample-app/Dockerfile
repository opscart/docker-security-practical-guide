# Multi-stage build on Docker Hardened Image.
#
# The base image (dhi.io/python:3.13) ships with:
#   - Non-root default user (nonroot, uid 65532)
#   - Read-only attestations: SLSA L3, CycloneDX SBOM, OpenVEX
#   - <7-day CVE remediation SLA (per Docker's published commitment)
#   - Minimal runtime — no shell, no package manager, no debug tools
#
# Our app adds: Python deps + the application code. Nothing else.
# The SBOM delta tool (tools/generate-sbom-delta.sh) shows exactly what
# we added on top — that's the "what you accept by deploying this" story.

# ----- Build stage -----
# We use the same DHI base for both stages so the SBOM delta is meaningful
# (we're comparing like-with-like). In real deployments you might use a
# heavier -dev variant here.

FROM dhi.io/python:3.13 AS builder

WORKDIR /build
COPY requirements.txt ./

# Install Python deps to a target directory we'll copy into the runtime stage.
# --no-cache-dir avoids leaving pip cache artifacts in the final image.
# --target/--prefix pattern lets us copy a self-contained site-packages tree.
RUN pip install --no-cache-dir --user -r requirements.txt

# ----- Runtime stage -----

FROM dhi.io/python:3.13

# Copy installed packages from the builder stage. The DHI Python image runs
# as user 'nonroot' (uid 65532) by default; their home is /home/nonroot.
COPY --from=builder /root/.local /home/nonroot/.local
ENV PATH=/home/nonroot/.local/bin:$PATH \
    PYTHONPATH=/home/nonroot/.local/lib/python3.13/site-packages

WORKDIR /app
COPY app.py ./

# DHI base sets USER nonroot already; we don't need to re-declare.
# Confirm by checking the base image's defaults if curious:
#   docker inspect dhi.io/python:3.13 --format '{{ .Config.User }}'

EXPOSE 8080

# CMD as JSON array so signals propagate correctly (no shell wrapping).
CMD ["python", "-u", "app.py"]