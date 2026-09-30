#!/usr/bin/env bash
# Genera carga para que el HPA escale. Ver en otra terminal: kubectl -n pipeline-devops get hpa -w
URL=${1:-http://app.localtest.me/work?n=2000000}
DURATION=${2:-120}
echo "Carga sobre $URL durante ${DURATION}s"
end=$((SECONDS+DURATION))
while [ $SECONDS -lt $end ]; do
  for _ in $(seq 20); do curl -s -o /dev/null "$URL" & done
  wait
done
