FROM python:3.11-slim

WORKDIR /app
COPY pyproject.toml ./
COPY src ./src
RUN python -m pip install --no-cache-dir .

EXPOSE 8001
CMD ["python", "-m", "matchlab_worker", "serve-health", "--host", "0.0.0.0"]
