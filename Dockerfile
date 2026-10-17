FROM public.ecr.aws/awsguru/aws-lambda-adapter:1.1.0 AS lambda-adapter

FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    AWS_LWA_PORT=8000 \
    AWS_LWA_READINESS_CHECK_PATH=/health

WORKDIR /app

# Apply Debian security updates that are newer than the base image
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --system --gid 10001 app \
    && useradd --system --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

# Lambda Web Adapter: lets this same HTTP container run on AWS Lambda.
# It only activates inside Lambda; under plain Docker the app runs as usual.
COPY --from=lambda-adapter /lambda-adapter /opt/extensions/lambda-adapter

COPY requirements.txt .

# Install app dependencies, then remove pip: it isn't needed at runtime
RUN pip install --no-cache-dir -r requirements.txt \
    && pip uninstall -y pip

COPY app/ ./app/

USER 10001:10001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--no-server-header"]