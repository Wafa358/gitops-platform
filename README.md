# GitOps Platform on AWS

End-to-end platform for a small Python API: **CI with GitHub Actions → container image on GHCR → Kubernetes deployment managed by ArgoCD → monitoring with Prometheus & Grafana → infrastructure on AWS provisioned with Terraform.**

> Status: 🚧 in progress. Built step by step, see the roadmap below.

## Architecture

```
 git push ──► GitHub Actions ──► tests ──► docker build ──► ghcr.io/<user>/task-api:<sha>
                                                                   │
                     k8s/ (Helm chart, image tag) ◄── ArgoCD watches the repo
                                                                   │
                                                     Kubernetes cluster (k3s on AWS EC2,
                                                     provisioned with Terraform)
                                                                   │
                                                     Prometheus scrapes /metrics ──► Grafana dashboards + alerts
```

## Roadmap

- [x] **Step 1:** Task API (FastAPI) with `/health` and `/metrics`, tests, multi-stage Dockerfile, CI pipeline pushing to GHCR
- [ ] **Step 2:** Helm chart + local Kubernetes (kind) + ArgoCD (GitOps)
- [ ] **Step 3:** Monitoring: kube-prometheus-stack, Grafana dashboard, alert rule
- [ ] **Step 4:** Terraform: VPC, EC2 running k3s, security groups, S3 remote state, budget alert
- [ ] **Step 5:** Screenshots, lessons learned

## The application

| Endpoint | Description |
|---|---|
| `GET /health` | Liveness/readiness probe (returns the running version) |
| `GET /metrics` | Prometheus metrics: request count and latency per route |
| `GET/POST /tasks` | List / create tasks |
| `GET/DELETE /tasks/{id}` | Get / delete a task |

### Run locally

```bash
cd app
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -v
uvicorn main:app --reload        # http://localhost:8000/docs
```

### Run with Docker

```bash
docker build -t task-api ./app
docker run -p 8000:8000 task-api
```

## CI pipeline

`.github/workflows/ci.yml`:
1. **test**: runs `pytest` on every push and pull request
2. **build-and-push**: on `main` only, builds the image and pushes it to GitHub Container Registry, tagged with the short commit SHA and `latest`

Design choices: non-root container user, multi-stage build for a small image, metrics labelled by route template (not raw URL) to keep cardinality low, Docker layer cache in GitHub Actions.
