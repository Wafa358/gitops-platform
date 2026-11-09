# ---- Build stage: install dependencies into a virtualenv ----
FROM python:3.13-slim AS build
WORKDIR /app
RUN python -m venv /venv
ENV PATH="/venv/bin:$PATH"
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Runtime stage: small image, non-root user ----
FROM python:3.13-slim
WORKDIR /app
COPY --from=build /venv /venv
ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
COPY main.py .
RUN useradd --uid 10001 --no-create-home appuser
USER 10001
EXPOSE 8000
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
