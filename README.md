# Pipeline DevOps · Proyecto final Coderhouse

Pipeline CI/CD completo para una API Node.js: imagen Docker multi-stage, infraestructura en GCP con Terraform, despliegue en Kubernetes con auto-escalado, monitoreo con Prometheus/Grafana, análisis SAST y DAST, y prácticas FinOps.

**Autor:** Zenón Deviagge · **Repo:** https://github.com/zendev2112/pipeline-devops

## Arquitectura

```
push → GitHub Actions
        ├─ test (node --test)
        ├─ SAST: CodeQL + Trivy (IaC, Dockerfile)
        ├─ build multi-stage → push ghcr.io + Trivy (imagen)
        ├─ terraform fmt/validate/plan (apply manual)
        └─ deploy en kind → smoke test → DAST (OWASP ZAP)

Kubernetes: Namespace → Deployment (2..6 réplicas, HPA por CPU) → Service → Ingress nginx
Monitoreo:  kube-prometheus-stack + ServiceMonitor → dashboard Grafana "pipeline-devops-app"
Infra GCP:  Terraform → módulo network (VPC + subnet) → módulo gke (cluster + node pool spot autoscalable)
```

## Estructura

| Ruta | Contenido |
|---|---|
| `app/` | API Express con `/health`, `/ready`, `/work` (carga CPU) y `/metrics` (prom-client). Tests con `node:test`. |
| `Dockerfile` | Multi-stage: deps → test → runtime (alpine, usuario no root, healthcheck). |
| `k8s/` | Namespace, ConfigMap, Deployment, Service, Ingress, HPA, ServiceMonitor (kustomize). |
| `terraform/` | Root + módulos `network` y `gke`. Variables en `variables.tf`, ejemplo en `terraform.tfvars.example`. |
| `monitoring/` | `lite/`: Prometheus + Grafana sin operador (manifiestos planos, para clusters locales chicos) y el dashboard `app.json`. `kube-prometheus-values.yaml`: values para el stack completo con Helm (GKE o máquinas con más RAM). Config para docker-compose. |
| `.github/workflows/ci-cd.yml` | Pipeline completo. |
| `scripts/` | `local-up.sh`, `local-down.sh`, `load-test.sh`, `tf-bootstrap.sh`, `finops-shutdown.sh`. |
| `docs/` | Informe y evidencias. |

## Ejecutar localmente

### Opción A: solo Docker (app + Prometheus + Grafana)
```bash
docker compose up --build
# App: http://localhost:3000  ·  Prometheus: http://localhost:9090  ·  Grafana: http://localhost:3001 (admin/admin)
```

### Opción B: Kubernetes local con kind (entorno de pruebas completo)
Requisitos: docker, kind, kubectl, helm.
```bash
./scripts/local-up.sh                 # MONITORING=full ./scripts/local-up.sh instala kube-prometheus-stack (necesita >= 4 GB en la VM de Docker)
curl http://app.localtest.me/health
kubectl -n monitoring port-forward svc/grafana 3001:80      # Grafana en http://localhost:3001 (admin/admin)
kubectl -n monitoring port-forward svc/prometheus 9090:9090 # Prometheus en http://localhost:9090
```
Probar el auto-escalado:
```bash
kubectl -n pipeline-devops get hpa -w      # en una terminal
./scripts/load-test.sh                     # en otra; en ~1 min las réplicas suben de 2 a 6
```
Bajar todo: `./scripts/local-down.sh`

## Infraestructura en GCP (Terraform)
```bash
./scripts/tf-bootstrap.sh MI_PROJECT_ID            # habilita APIs y crea bucket de estado (una vez)
cd terraform && cp terraform.tfvars.example terraform.tfvars   # editar project_id
terraform init && terraform plan
terraform apply                                     # ~8 min. Crea VPC, subnet, cluster GKE zonal, node pool spot 1..3 nodos
$(terraform output -raw get_credentials)            # configura kubectl contra GKE
kubectl apply -k ../k8s/
```
Apagar para no pagar: `./scripts/finops-shutdown.sh scale-zero` (fuera de horario) o `./scripts/finops-shutdown.sh destroy`.

## Pipeline CI/CD
Secretos necesarios en el repo (Settings → Secrets):

| Secreto | Uso |
|---|---|
| `GITHUB_TOKEN` | automático, push a ghcr.io |
| `GCP_PROJECT_ID` | Terraform |
| `GCP_SA_KEY` | JSON de service account con rol Kubernetes Engine Admin + Compute Network Admin. Si falta, el job solo hace `validate`. |

El `terraform apply` nunca corre en push: solo desde *Run workflow* con la opción `terraform_apply` marcada.

## Validar despliegue y monitoreo
- `kubectl -n pipeline-devops get pods,svc,ingress,hpa`
- `curl http://app.localtest.me/metrics` debe listar `http_requests_total`
- Prometheus → Status → Targets: los pods de la app en estado UP (vía anotaciones `prometheus.io/*` en el stack lite, o vía el ServiceMonitor `app` con kube-prometheus-stack)
- Grafana → Dashboards → *pipeline-devops-app*: requests/s, latencia p95, CPU, errores 5xx
- Seguridad: pestaña *Security* del repo (CodeQL, Trivy) y artefacto `zap-report` de cada run

## FinOps
- Node pool **spot/preemptible** (hasta 80 % más barato) con autoscaling 1..3 nodos y máquinas `e2-small`.
- HPA 2..6 réplicas: solo se paga cómputo bajo carga real. `requests/limits` acotados en cada pod.
- Cluster **zonal** (el plano de control entra en la cuota gratuita de GKE).
- `finops-shutdown.sh scale-zero` para apagar nodos fuera de horario; `destroy` al terminar las pruebas.
- Labels `env`, `owner`, `cost-center` en todos los recursos para desglosar la facturación.
- Dependabot mantiene imágenes y acciones actualizadas.

## Evidencias
En `docs/evidencias/`:

| Archivo | Qué muestra |
|---|---|
| `01-smoke-test-ingress.txt` | `curl` a la app a través del Ingress nginx en kind |
| `02-kubectl-estado-cluster-local.txt` | nodos, pods, service, ingress, HPA, ServiceMonitor y `kubectl top` |
| `03-hpa-escalado-bajo-carga.txt` | el HPA pasando de 2 a 6 réplicas durante `load-test.sh` y volviendo a 2 |
| `04-prometheus-targets.txt` | targets UP, dashboard provisionado en Grafana, consulta PromQL |
| `05-prometheus-targets.png` | pantalla Targets de Prometheus |
| `06-grafana-dashboard.png` | dashboard `pipeline-devops-app` con tráfico real |
| `07-github-actions-run.txt` | run completo del pipeline con los 6 jobs en verde |

Informe: `docs/informe.md`.
