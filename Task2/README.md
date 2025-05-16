# 🛡️ MinIO IAM-like Access Simulation in Kubernetes

This project simulates AWS IAM-style access control within a Kubernetes environment using MinIO. It ensures that only authorized services can interact with object storage, while others are explicitly denied—even if they are misconfigured with credentials.

---

## 📦 Components

- **MinIO** (`minio/minio`) deployed in a dedicated namespace: `storage-system`
- **Two Kubernetes services**:
  - ✅ `data-service`: Authorized to access the MinIO bucket
  - ❌ `auth-service`: Denied access (even with credentials)
- **MinIO IAM-like user and bucket policies**
- ✅ Optional: Integrate policy engines like OPA or Kyverno for extra enforcement

---

## 🚀 Setup Instructions

### 1. Create Namespaces & Secrets

```bash
kubectl apply -f 01-namespaces-and-secrets.yaml
```

Includes:
- storage-system namespace for MinIO
- app-system namespace for workloads
- Root credentials for MinIO
- Access credentials for data-service

### 2. Deploy MinIO
```bash
kubectl apply -f 02-minio-deployment.yaml
```

Includes:
- Deployment with persistent volume
- Exposes API (port 9000) and Console (port 9001)


### 3. Create ServiceAccounts

```bash
kubectl apply -f 03-service-accounts.yaml
```

Includes:
- data-service-sa
- auth-service-sa

### 4. Deploy Workloads

```bash
kubectl apply -f 04-services-deployment.yaml
```
Includes:
- data-service: Configured with valid MinIO credentials
- auth-service: Lacks access permissions

### 5. Configure MinIO Policies & Bucket

```bash
kubectl apply -f 05-minio-setup-job.yaml
```
This Job will:
- Create the app-data bucket
- Create a MinIO user: data-service-user
- Attach a scoped IAM-like policy to allow access to that user only

### 6. Run Access Tests
```bash
kubectl apply -f 06-access-test-jobs.yaml
```
Tests:
✅ test-data-service-access: Uploads and lists objects in the bucket

❌ test-auth-service-access: Fails with "Access Denied"