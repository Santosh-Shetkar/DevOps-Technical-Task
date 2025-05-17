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

A Service Account is provided for the data-service which has access to MinIO credentials. 
The auth-service does not have access to these credentials, simulating an IAM-like policy.

## Project structure

```test
main/
├── base/
│   ├── kustomization.yaml
│   ├── namespaces/
│   │   ├── kustomization.yaml
│   │   ├── app-namespace.yaml
│   │   └── system-namespace.yaml
│   └── rbac/
│       ├── kustomization.yaml
│       ├── data-service-sa.yaml
│       ├── data-service-role.yaml
│       └── data-service-role-binding.yaml
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
│       ├── data-service/
│       │   ├── kustomization.yaml
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── minio/
│           ├── kustomization.yaml
│           ├── deployment.yaml
│           ├── service.yaml
│           └── secret.yaml
└── README.md
```


## Testing Access Control

### Deploy the stack
```bash
kubectl apply -k overlays/dev/
```

### Verify that data-service can access MinIO
```bash
# Use a temporary pod with data-service SA to test access
kubectl run minio-test-data --image=minio/mc --overrides='{"spec":{"serviceAccountName":"data-service-sa"}}' -n app-namespace --rm -it -- bash

# Inside the pod, test access
mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 minioaccess miniosecret
mc ls myminio
```

### Verify auth-service cannot access MinIO
```bash
# Use a temporary pod with default SA (same as auth-service) to test access
kubectl run minio-test-auth --image=minio/mc -n app-namespace --rm -it -- bash

# Inside the pod, try to access MinIO
mc alias set myminio http://minio.system-namespace.svc.cluster.local:9000 minioaccess miniosecret
mc ls myminio
# This should fail with an access error
```

## Bonus: OPA/Kyverno Policy

For even stronger enforcement, you can add Kyverno policies to ensure only the data-service can access MinIO. Here's an example policy to be added to the repo:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-minio-access
spec:
  validationFailureAction: enforce
  rules:
  - name: restrict-minio-access-sa
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "Only data-service-sa can access MinIO"
      deny:
        conditions:
        - key: "{{request.object.spec.containers[].env[?(@.name=='MINIO_ACCESS_KEY')]}}"
          operator: NotEquals
          value: null
        - key: "{{request.object.spec.serviceAccountName}}"
          operator: NotEquals
          value: data-service-sa
```
