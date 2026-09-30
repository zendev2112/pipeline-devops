#!/usr/bin/env bash
# FinOps: apaga el cluster fuera de horario (node pool a 0) o lo destruye entero.
#   finops-shutdown.sh scale-zero   -> deja el plano de control, saca los nodos (no paga cómputo)
#   finops-shutdown.sh destroy      -> terraform destroy
set -euo pipefail
cd "$(dirname "$0")/../terraform"
case "${1:-}" in
  scale-zero)
    CLUSTER=$(terraform output -raw cluster_name); ZONE=$(terraform output -raw cluster_location)
    gcloud container clusters resize "$CLUSTER" --node-pool pipeline-devops-pool --num-nodes 0 --zone "$ZONE" --quiet ;;
  destroy) terraform destroy -auto-approve ;;
  *) echo "uso: $0 scale-zero|destroy"; exit 1 ;;
esac
