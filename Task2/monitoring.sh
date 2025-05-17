#!/bin/bash
# Install Prometheus and Grafana using Helm

# Add the Prometheus community Helm repository
echo "Adding Prometheus community Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create values file for customization
cat <<EOF > prometheus-values.yaml
# Custom values for kube-prometheus-stack
grafana:
  adminPassword: admin123  # Change this in production
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
      - name: 'default'
        orgId: 1
        folder: ''
        type: file
        disableDeletion: false
        editable: true
        options:
          path: /var/lib/grafana/dashboards/default
  dashboards:
    default:
      k8s-cluster-monitoring:
        gnetId: 11074
        revision: 1
        datasource: Prometheus
  # Define resource limits for Grafana
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 100m
      memory: 128Mi

prometheus:
  prometheusSpec:
    # Define resource limits for Prometheus
    resources:
      limits:
        cpu: 500m
        memory: 1Gi
      requests:
        cpu: 200m
        memory: 512Mi
    serviceMonitorSelector: {}
    serviceMonitorNamespaceSelector: {}
    serviceMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false
    # Add retention configuration
    retention: 7d
    retentionSize: "10GB"

alertmanager:
  config:
    global:
      resolve_timeout: 5m
    route:
      group_by: ['job', 'alertname', 'severity']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'null'
      routes:
      - match:
          alertname: Watchdog
        receiver: 'null'
      - match:
          severity: critical
        receiver: 'email-notifications'
    receivers:
    - name: 'null'
    - name: 'email-notifications'
      email_configs:
      - to: 'alerts@example.com'  # Replace with your email
        from: 'prometheus@example.com'  # Replace with sender email
        smarthost: 'smtp.example.com:587'  # Replace with your SMTP server
        auth_username: 'user'  # Replace with SMTP username
        auth_password: 'password'  # Replace with SMTP password
    templates:
    - '/etc/alertmanager/config/*.tmpl'
EOF

# Install kube-prometheus-stack with custom values
echo "Installing kube-prometheus-stack with custom values..."
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml

echo "Waiting for deployment to complete..."
kubectl -n monitoring wait --for=condition=available --timeout=300s deployment/monitoring-grafana

echo "Prometheus & Grafana installation complete!"
echo "Access Grafana at: http://localhost:3000 (after port-forwarding)"
echo "To port forward: kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80"