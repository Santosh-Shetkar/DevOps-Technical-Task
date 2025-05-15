Microservice Stack Deployment with Kustomize for Minikube

This repository contains a Kubernetes deployment of a simple three-service microservice architecture using Kustomize. It is designed to run on Minikube and demonstrates namespace separation, resource management, health checks, and ingress.

Directory Structure

microservice-stack/
├── base/
│   ├── namespaces/
│   │   ├── kustomization.yaml       # Kustomize setup for namespaces
│   │   ├── system-namespace.yaml    # "system" namespace definition
│   │   └── app-namespace.yaml       # "application" namespace definition
│   ├── gateway/
│   │   ├── kustomization.yaml       # Kustomize setup for gateway
│   │   ├── deployment.yaml          # Deployment for the gateway service
│   │   ├── service.yaml             # ClusterIP service for the gateway
│   │   └── ingress.yaml             # Ingress rule exposing gateway
│   ├── auth-service/
│   │   ├── kustomization.yaml       # Kustomize setup for auth-service
│   │   ├── deployment.yaml          # Deployment for the auth microservice
│   │   └── service.yaml             # ClusterIP service for auth-service
│   ├── data-service/
│   │   ├── kustomization.yaml       # Kustomize setup for data-service
│   │   ├── deployment.yaml          # Deployment for the data microservice
│   │   └── service.yaml             # ClusterIP service for data-service
│   └── kustomization.yaml           # Aggregates all base resources
└── kustomization.yaml               # Root Kustomization including base

Components

Namespaces

system for internal services (auth, data).

application for the public-facing gateway.

Gateway

Uses an NGINX demo image to serve incoming HTTP requests.

Exposed via a Kubernetes Ingress.

Configured with liveness and readiness probes, and resource requests/limits.

Auth Service

Uses the kennethreitz/httpbin image to simulate an authentication endpoint.

Internal-only (ClusterIP) in the system namespace.

Health checks ensure reliability.

Data Service

Uses hashicorp/http-echo to return a simple text response.

Internal-only (ClusterIP) in the system namespace.

Health checks and resource management similar to other services.

How to Deploy on Minikube

Start Minikube

minikube start

Enable Ingress Add-on

minikube addons enable ingress

Deploy the Stack

kubectl apply -k ./

Verify Resources

# Namespaces
kubectl get ns

# Deployments
kubectl get deployments -n application
kubectl get deployments -n system

# Services
kubectl get svc -n application
kubectl get svc -n system

# Ingress
kubectl get ingress -n application

Access the Gateway

minikube ip

Open your browser to http://<MINIKUBE_IP>/ to see the gateway response.