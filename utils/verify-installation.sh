#!/bin/bash
# Snowflake Prometheus Exporter Troubleshooting Script

echo "===== Checking ServiceMonitor Configuration ====="
kubectl get servicemonitor -n kafka prometheus-snowflake-exporter -o yaml

echo -e "\n===== Checking Pod Status ====="
kubectl get pods -n kafka -l app=prometheus-snowflake-exporter

echo -e "\n===== Checking Pod Logs ====="
kubectl logs -n kafka -l app=prometheus-snowflake-exporter --tail=50

echo -e "\n===== Checking Service Configuration ====="
kubectl get svc -n kafka prometheus-snowflake-exporter -o yaml

echo -e "\n===== Checking Prometheus Target Status ====="
# Port-forward to Prometheus (run this in background)
kubectl port-forward -n kafka svc/kube-prometheus-stack-prometheus 9090:9090 &
PF_PID=$!
sleep 3

# Use curl to check targets
echo "Fetching targets from Prometheus API..."
curl -s http://localhost:9090/api/v1/targets | grep -i snowflake

# Kill port-forward
kill $PF_PID

echo -e "\n===== Testing Metrics Endpoint Directly ====="
# Port-forward to the exporter service
kubectl port-forward -n kafka svc/prometheus-snowflake-exporter 9000:9000 &
PF_PID=$!
sleep 3

# Use curl to check if metrics endpoint is responding
echo "Trying to reach metrics endpoint directly..."
curl -s http://localhost:9000 | head -n 20

# Kill port-forward
kill $PF_PID

echo -e "\n===== Checking ServiceMonitor-to-Service Label Matching ====="
echo "ServiceMonitor selector:"
kubectl get servicemonitor -n kafka prometheus-snowflake-exporter -o jsonpath='{.spec.selector.matchLabels}' | jq .

echo "Service labels:"
kubectl get svc -n kafka prometheus-snowflake-exporter -o jsonpath='{.metadata.labels}' | jq .

echo -e "\n===== Checking Prometheus Config ====="
# Check if Prometheus is configured to discover this ServiceMonitor
kubectl get configmap -n kafka kube-prometheus-stack-prometheus -o yaml | grep -A 10 "job_name: serviceMonitor/kafka/prometheus-snowflake-exporter"
