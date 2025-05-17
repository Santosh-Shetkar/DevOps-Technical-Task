# Kubernetes Microservice Stack with Kustomize and MinIO IAM

This repository contains a Kubernetes deployment using Kustomize for a microservice architecture with:
- API Gateway (using nginxdemos/hello)
- Auth Service (using kennethreitz/httpbin)
- Data Service (using hashicorp/http-echo)
- MinIO S3-compatible storage

## Architecture Overview

The deployment is separated into two namespaces:
- `app-namespace`: Contains the microservice applications
- `system-namespace`: Contains the MinIO deployment

The gateway service is exposed via an Ingress, while auth and data services remain internal.

## IAM-like Access Control

This deployment implements IAM-like access control at two levels:

1. **Kubernetes RBAC level**: A Service Account is provided for the data-service which has access to MinIO credentials. The auth-service does not have access to these credentials.

2. **MinIO internal IAM**: Within MinIO, we've configured:
   - A specific user (`dataserviceuser`) for the data-service
   - An IAM policy that allows access to the `app-data` bucket
   - A policy binding that gives the data-service user access to the bucket

## Project structure

```test
main/
├── base/
│   ├── kustomization.yaml
│   └── namespaces/
│       ├── kustomization.yaml
│       ├── app-namespace.yaml
│       └── system-namespace.yaml
|       └── minio-secret-app-namespace.yaml
├── overlays/
│   └── dev/
│       ├── kustomization.yaml
│       ├── gateway/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml 
│       │   ├── service.yaml
│       │   └── ingress.yaml
│       ├── auth-service/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml
│       │   └── service.yaml
|       |   └── minio-secret-app-namespace.yaml
│       ├── data-service/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── minio/
│           ├── kustomization.yaml
│           ├── deployment.yaml
│           ├── service.yaml
│           └── minio-secret-system-namespace.yaml
└── README.md
```


## Testing Access Control

### Deploy the stack
```bash
kubectl apply -k overlays/dev/
```

### Wait for the MinIO setup job to complete
```bash
kubectl get jobs -n system-namespace
```

### Verify that data-service can access MinIO
```bash
# Use a temporary pod with data-service SA to test access
kubectl run minio-test-data --image=minio/mc -n app-namespace --rm -it -- bash


mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
mc ls myminio/app-data  # This should succeed
```

### Verify auth-service cannot access MinIO
```bash
# Use a temporary pod with default SA (same as auth-service) to test access
kubectl run minio-test-auth --image=minio/mc -n app-namespace --rm -it -- bash

# Inside the pod, try to access MinIO with data-service credentials
# Note: We're intentionally using the credentials here to demonstrate that
# even with the credentials, the auth-service's pod doesn't have permission
# to use them

export MINIO_ACCESS_KEY=$(kubectl get secret data-service-minio-creds -n system-namespace -o jsonpath='{.data.accesskey}' 2>/dev/null | base64 --decode || echo "no-access")
export MINIO_SECRET_KEY=$(kubectl get secret data-service-minio-creds -n system-namespace -o jsonpath='{.data.secretkey}' 2>/dev/null | base64 --decode || echo "no-access")

mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY
mc ls myminio/app-data  # This should fail with an access error
```