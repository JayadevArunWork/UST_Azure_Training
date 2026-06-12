#!/bin/sh
set -eu

namespace="sentinel-app"
domain="sentinel.vaultrix.in"
job="sentinel-tls-certificate"
script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

kubectl delete job "$job" -n "$namespace" --ignore-not-found
kubectl apply -f "$script_dir/06-tls-certificate-job.yaml"

pod=""
attempt=0
while [ "$attempt" -lt 60 ]; do
  pod="$(kubectl get pod -n "$namespace" -l app.kubernetes.io/name="$job" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  if [ -n "$pod" ]; then
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done

if [ -z "$pod" ]; then
  echo "Certificate job pod was not created." >&2
  exit 1
fi

attempt=0
while [ "$attempt" -lt 120 ]; do
  if kubectl exec -n "$namespace" "$pod" -- test -f /acme/certificate-ready 2>/dev/null; then
    break
  fi
  phase="$(kubectl get pod -n "$namespace" "$pod" -o jsonpath='{.status.phase}')"
  if [ "$phase" = "Failed" ]; then
    kubectl logs -n "$namespace" "$pod"
    exit 1
  fi
  attempt=$((attempt + 1))
  sleep 3
done

if ! kubectl exec -n "$namespace" "$pod" -- test -f /acme/certificate-ready; then
  kubectl logs -n "$namespace" "$pod"
  echo "Timed out waiting for the certificate." >&2
  exit 1
fi

kubectl exec -n "$namespace" "$pod" -- cat "/acme/letsencrypt/live/$domain/fullchain.pem" > /tmp/sentinel-fullchain.pem
kubectl exec -n "$namespace" "$pod" -- cat "/acme/letsencrypt/live/$domain/privkey.pem" > /tmp/sentinel-privkey.pem

kubectl create secret tls sentinel-gateway-tls \
  -n "$namespace" \
  --cert=/tmp/sentinel-fullchain.pem \
  --key=/tmp/sentinel-privkey.pem \
  --dry-run=client \
  -o yaml | kubectl apply -f -

kubectl rollout restart deployment/sentinel-gateway -n "$namespace"
kubectl rollout restart deployment/identity-service -n "$namespace"
kubectl rollout status deployment/sentinel-gateway -n "$namespace" --timeout=300s
kubectl rollout status deployment/identity-service -n "$namespace" --timeout=300s

kubectl delete job "$job" -n "$namespace" --ignore-not-found
rm -f /tmp/sentinel-fullchain.pem /tmp/sentinel-privkey.pem
