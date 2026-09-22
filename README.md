# AWS EKS Multi-Environment Infrastructure (Terraform)

Production-grade, modular Terraform repository provisioning AWS EKS clusters across isolated environments (Dev/Prod) with remote state management, strict security defaults, and core Kubernetes add-ons.

## Architecture Overview

- **Remote Backend:** Dedicated S3 bucket for state storage with server-side encryption (AES256) and DynamoDB state locking.
- **Networking (VPC Module):** Multi-AZ VPC deployment (2 AZs for Dev, 3 AZs for Prod) with isolated public and private subnets, Internet Gateways, and NAT Gateways.
- **Kubernetes (EKS Module):** Amazon EKS Control Plane with managed node groups, custom IAM roles, and tight SG egress controls.
- **Cluster Add-ons (Helm Module):** Metrics Server for pod autoscaling (HPA) and Ingress NGINX Controller configured with Network Load Balancer (NLB).

## Directory Structure

```text
.
├── .github/
│   └── workflows/          # GitHub Actions CI pipeline for formatting & validation
├── bootstrap/              # Provisions S3 Bucket & DynamoDB for remote backend
├── modules/
│   ├── vpc/                # Reusable VPC module
│   ├── k8s-cluster/        # Reusable EKS & Worker Node Group module
│   └── k8s-addons/         # Helm-based cluster add-ons (Ingress NGINX, Metrics Server)
└── environments/
    ├── dev/                # Dev environment root module (2 AZs)
    └── prod/               # Prod environment root module (3 AZs)