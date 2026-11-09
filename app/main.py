"""Task API - a small service used to demo a full GitOps platform.

Endpoints:
  GET  /health        liveness/readiness probe for Kubernetes
  GET  /metrics       Prometheus metrics
  GET  /tasks         list tasks
  POST /tasks         create a task
  GET  /tasks/{id}    get one task
  DELETE /tasks/{id}  delete a task
"""

import os
import time

from fastapi import FastAPI, HTTPException, Request, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pydantic import BaseModel

APP_VERSION = os.getenv("APP_VERSION", "dev")

app = FastAPI(title="Task API", version=APP_VERSION)

# --- Prometheus metrics -------------------------------------------------------
REQUESTS = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds",
    ["method", "path"],
)


@app.middleware("http")
async def record_metrics(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    # Use the route template (/tasks/{task_id}) so metrics don't explode per id
    route = request.scope.get("route")
    path = route.path if route else request.url.path
    if path != "/metrics":
        LATENCY.labels(request.method, path).observe(time.perf_counter() - start)
        REQUESTS.labels(request.method, path, response.status_code).inc()
    return response


# --- Data (in memory - enough for the demo) -------------------------------------
class TaskIn(BaseModel):
    title: str
    done: bool = False


class Task(TaskIn):
    id: int


_tasks: dict[int, Task] = {}
_next_id = 1


# --- Routes ---------------------------------------------------------------------
@app.get("/health")
def health():
    return {"status": "ok", "version": APP_VERSION}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/tasks", response_model=list[Task])
def list_tasks():
    return list(_tasks.values())


@app.post("/tasks", response_model=Task, status_code=201)
def create_task(task: TaskIn):
    global _next_id
    new = Task(id=_next_id, **task.model_dump())
    _tasks[new.id] = new
    _next_id += 1
    return new


@app.get("/tasks/{task_id}", response_model=Task)
def get_task(task_id: int):
    if task_id not in _tasks:
        raise HTTPException(status_code=404, detail="Task not found")
    return _tasks[task_id]


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(task_id: int):
    if _tasks.pop(task_id, None) is None:
        raise HTTPException(status_code=404, detail="Task not found")
    return Response(status_code=204)
