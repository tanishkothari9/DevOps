# Session 17 - hardened image for the DevSecOps Dashboard
#  * small, pinned Alpine base  -> far fewer OS packages = fewer CVEs
#  * multi-stage: dependencies are installed into a venv in a builder stage
#  * runtime stage has no pip/build tooling and runs as a non-root user
# BASE_IMAGE is overridable only so the pipeline can PROVE the image gate blocks
# an outdated base (workflow_dispatch inject_issue=image). Default = patched base.
ARG BASE_IMAGE=python:3.12.15-alpine3.24

FROM ${BASE_IMAGE} AS builder

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip


FROM ${BASE_IMAGE}

ARG APP_VERSION=dev

LABEL org.opencontainers.image.source="https://github.com/tanishkothari9/DevOps" \
      org.opencontainers.image.description="Session 17 - DevSecOps Dashboard"

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    APP_VERSION=${APP_VERSION}

# patch OS packages to the latest fixed versions, remove pip (nothing is installed
# at runtime) and create an unprivileged user
RUN apk upgrade --no-cache \
    && python -m pip uninstall -y pip \
    && addgroup -g 10001 -S app \
    && adduser -u 10001 -S -G app -H app

WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app ./app

USER 10001:10001

EXPOSE 5001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:5001/health', timeout=2)"]

CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--workers", "2", "--worker-tmp-dir", "/tmp", "--access-logfile", "-", "app.app:app"]
