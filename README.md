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
- [x] **Step 2:** Helm chart + local Kubernetes (kind) + ArgoCD (GitOps)
- [x] **Step 3:** Monitoring: kube-prometheus-stack, Grafana dashboard, alert rule
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

3. **update-manifest**: writes the new image tag into `k8s/task-api/values.yaml` and commits it. ArgoCD picks up the commit and deploys it: the pipeline never needs cluster credentials.

Design choices: non-root container user, multi-stage build for a small image, metrics labelled by route template (not raw URL) to keep cardinality low, Docker layer cache in GitHub Actions.

## Kubernetes & GitOps

```
k8s/
├── task-api/              Helm chart (Deployment with readiness/liveness probes, resource limits, Service)
└── argocd/
    └── task-api-app.yaml  ArgoCD Application: auto-sync, prune, self-heal
```

Run it locally on a [kind](https://kind.sigs.k8s.io/) cluster:

```bash
kind create cluster --name gitops
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f k8s/argocd/task-api-app.yaml
kubectl port-forward svc/task-api -n task-api 8000:80   # http://localhost:8000/health
```

## Infrastructure on AWS (Terraform)

```
infra/
├── bootstrap/   S3 bucket for remote state (versioned, encrypted, private) + monthly budget alert
└── main/        VPC, public subnet, internet gateway, security group, EC2 instance running k3s
```

- **Remote state** in S3 with native locking (`use_lockfile`, Terraform ≥ 1.10). `bootstrap` writes `main/backend.hcl` itself.
- **Security group**: SSH and the Kubernetes API are open to *my current IP only* (resolved at plan time), HTTP 80 is public for the demo.
- **Cost-aware**: no NAT gateway, single small instance, encrypted 20 GB gp3 volume, budget alert at 5 USD. `terraform destroy` after each demo.
- **Zero manual steps on the server**: cloud-init installs k3s and ArgoCD and registers the same `task-api` Application with cloud values (`ingress.enabled=true`, `monitoring.enabled=false`). From there, the cluster is driven by Git like the local one.

```bash
cd infra/bootstrap && terraform init && terraform apply -var="budget_email=you@example.com"
cd ../main && terraform init -backend-config=backend.hcl && terraform apply
curl $(terraform output -raw app_url)
terraform destroy
```

## Monitoring

The monitoring stack (`kube-prometheus-stack`: Prometheus Operator, Prometheus, Alertmanager, Grafana) is itself deployed by ArgoCD from `k8s/argocd/monitoring-app.yaml`. The Task API chart ships its own observability as code:

| File | What it does |
|---|---|
| `templates/servicemonitor.yaml` | Prometheus scrapes `/metrics` on every pod every 15 s |
| `templates/prometheusrule.yaml` | Alerts: `TaskApiDown` (critical), `TaskApiHighErrorRate` (> 5 % 5xx), `TaskApiHighLatency` (p95 > 500 ms) |
| `templates/dashboard.yaml` + `dashboards/task-api.json` | Grafana dashboard: pods up, request rate, error rate, p50/p95/p99 latency, CPU per pod |

```bash
kubectl apply -f k8s/argocd/monitoring-app.yaml
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80                      # Grafana
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090  # Prometheus
```
