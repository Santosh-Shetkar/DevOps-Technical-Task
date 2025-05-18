#Step 1: Install Prometheus & Grafana using Helm

# Add the Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update Helm repositories
helm repo update

# Install the kube-prometheus-stack (includes Prometheus, Grafana, and Alertmanager)
helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus --namespace monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana --namespace monitoring --timeout=300s


#Verify Installation

kubectl get pods -n monitoring

#Step 2: Access Grafana Dashboard

kubectl get secret --namespace monitoring monitoring-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

kubectl port-forward --namespace monitoring svc/monitoring-grafana 3000:80 --address 0.0.0.0

# Access Grafana at: http://localhost:3000
# Username: admin
# Password:

#Step 3: Configure ServiceMonitor for Applications

kubectl apply -f data-service-servicemonitor.yaml
kubectl apply -f auth-service-servicemonitor.yaml
kubectl apply -f gateway-servicemonitor.yaml
kubectl apply -f minio-servicemonitor.yaml

#Step 5: Custom Grafana Dashboard Configuration
Create a custom dashboard with the following JSON configuration. Import this into Grafana:

📊 Dashboard Configuration
Import Pre-built Dashboard

Open Grafana (http://localhost:3000)
Login with admin credentials
Click "+" → "Import"
Paste the dashboard JSON from grafana-dashboard.json
Click "Load" → "Import"

#Test Queries in Prometheus

# CPU usage by pod
rate(container_cpu_usage_seconds_total{namespace="app-system"}[5m])

# Memory usage by pod  
container_memory_working_set_bytes{namespace="app-system"}

# Pod restart count
kube_pod_container_status_restarts_total{namespace="app-system"}

#Create a dashboard using these Prom QL queries separately.