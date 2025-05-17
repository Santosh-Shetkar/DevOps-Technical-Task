#!/bin/bash
# Test script to verify MinIO IAM policies

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "===== Testing MinIO IAM Policies ====="

# Check if MinIO setup job completed
echo -n "Checking MinIO setup job status... "
if kubectl get job minio-setup -n system-namespace -o jsonpath='{.status.succeeded}' | grep -q 1; then
    echo -e "${GREEN}Success${NC}"
else
    echo -e "${RED}Failed or still running${NC}"
    echo "Waiting for MinIO setup job to complete..."
    kubectl wait --for=condition=complete job/minio-setup -n system-namespace --timeout=60s || true
fi

# Test 1: Data Service Access (Should succeed)
echo -e "\n===== Test 1: Data Service Access ====="
echo "Creating test pod with data-service-sa..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-test-data
  namespace: app-namespace
spec:
  serviceAccountName: data-service-sa
  containers:
  - name: mc
    image: minio/mc
    command: ["/bin/sh", "-c", "sleep 3600"]
  restartPolicy: Never
EOF

echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod/minio-test-data -n app-namespace --timeout=60s

echo "Testing access from data-service-sa..."
kubectl exec -it minio-test-data -n app-namespace -- /bin/sh -c "
export MINIO_ACCESS_KEY=\$(cat /var/run/secrets/kubernetes.io/serviceaccount/token | tr -d '\n' | head -c 20)
export MINIO_ACCESS_KEY=dataserviceuser
export MINIO_SECRET_KEY=dataservicepassword

echo 'Configuring MinIO client...'
mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 \$MINIO_ACCESS_KEY \$MINIO_SECRET_KEY

echo 'Testing access to app-data bucket...'
mc ls myminio/app-data && echo -e '${GREEN}✓ Data service can access MinIO bucket${NC}' || echo -e '${RED}✗ Data service cannot access MinIO bucket${NC}'
"

# Test 2: Auth Service Access (Should fail)
echo -e "\n===== Test 2: Auth Service Access ====="
echo "Creating test pod with default SA..."

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: minio-test-auth
  namespace: app-namespace
spec:
  containers:
  - name: mc
    image: minio/mc
    command: ["/bin/sh", "-c", "sleep 3600"]
  restartPolicy: Never
EOF

echo "Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod/minio-test-auth -n app-namespace --timeout=60s

echo "Testing access from default SA (auth-service)..."
kubectl exec -it minio-test-auth -n app-namespace -- /bin/sh -c "
export MINIO_ACCESS_KEY=dataserviceuser
export MINIO_SECRET_KEY=dataservicepassword

echo 'Configuring MinIO client...'
mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 \$MINIO_ACCESS_KEY \$MINIO_SECRET_KEY

echo 'Testing access to app-data bucket...'
if mc ls myminio/app-data 2>/dev/null; then
  echo -e '${RED}✗ Auth service CAN access MinIO bucket (THIS IS A PROBLEM!)${NC}'
else
  echo -e '${GREEN}✓ Auth service correctly denied access to MinIO bucket${NC}'
fi
"

# Clean up
echo -e "\n===== Cleaning up test pods ====="
kubectl delete pod minio-test-data -n app-namespace
kubectl delete pod minio-test-auth -n app-namespace

echo -e "\n===== Testing completed ====="