#!/usr/bin/env bash
# Levanta todo en local: cluster kind + ingress-nginx + metrics-server + Prometheus/Grafana + la app
set -euo pipefail
cd "$(dirname "$0")/.."
CLUSTER=pipeline-devops
IMAGE=ghcr.io/zendev2112/pipeline-devops-app:local

if ! kind get clusters | grep -qx "$CLUSTER"; then
  kind create cluster --name "$CLUSTER" --config scripts/kind-config.yaml
fi

echo ">> Build de la imagen"
docker build -t "$IMAGE" .
kind load docker-image "$IMAGE" --name "$CLUSTER"

echo ">> ingress-nginx"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.12.1/deploy/static/provider/kind/deploy.yaml
kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=600s

echo ">> metrics-server (necesario para el HPA)"
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl -n kube-system patch deploy metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

echo ">> Prometheus + Grafana (MONITORING=lite por defecto; MONITORING=full instala kube-prometheus-stack, necesita >=4 GB en la VM de Docker)"
if [ "${MONITORING:-lite}" = "full" ]; then
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
  helm repo update >/dev/null
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace -f monitoring/kube-prometheus-values.yaml --wait --timeout 15m
  kubectl create configmap app-dashboard -n monitoring \
    --from-file=app.json=monitoring/lite/app.json --dry-run=client -o yaml \
    | kubectl label --local -f - grafana_dashboard=1 -o yaml | kubectl apply -f -
else
  kubectl apply -k monitoring/lite/
  kubectl -n monitoring rollout status deploy/prometheus deploy/grafana --timeout=300s
fi

echo ">> App"
kubectl apply -k k8s/
kubectl -n pipeline-devops set image deploy/app app="$IMAGE"
kubectl -n pipeline-devops rollout status deploy/app --timeout=300s

cat <<MSG

Listo.
  App:        http://app.localtest.me
  Grafana:    kubectl -n monitoring port-forward svc/grafana 3001:80       -> http://localhost:3001 (admin/admin)
  Prometheus: kubectl -n monitoring port-forward svc/prometheus 9090:9090  -> http://localhost:9090
  (con MONITORING=full los services son monitoring-grafana y monitoring-kube-prometheus-prometheus)
  HPA:        kubectl -n pipeline-devops get hpa -w
MSG
