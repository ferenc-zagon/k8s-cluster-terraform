# Enterprise Kubernetes Platform on AWS (EKS & GitOps)

[![Terraform](https://img.shields.io/badge/Terraform-1.16+-844FBA?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS EKS](https://img.shields.io/badge/AWS%20EKS-1.30-FF9900?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/eks/)
[![Karpenter](https://img.shields.io/badge/Karpenter-v1.0+-00ADD8?logo=kubernetes&logoColor=white)](https://karpenter.sh/)
[![ArgoCD](https://img.shields.io/badge/GitOps-ArgoCD-EF7B42?logo=argo&logoColor=white)](https://argo-cd.readthedocs.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Production-grade, multi-environment Kubernetes platform provisioned via **Terraform** and managed through **GitOps (ArgoCD)** on AWS. Built according to enterprise cloud architecture standards (strict network segmentation, IRSA least-privilege, native EKS Access Entries, sub-minute Karpenter autoscaling, and zero-touch lifecycle teardown).

---

## 🏛️ Architecture Overview

```mermaid
flowchart TD
    subgraph AWS Cloud ["AWS Cloud (eu-central-1)"]
        subgraph VPC ["VPC (Multi-AZ Network Segmentation)"]
            subgraph PublicSubnets ["Public Subnets"]
                IGW["Internet Gateway"]
                NAT["NAT Gateway"]
                NLB["AWS Network Load Balancer (NLB)"]
            end

            subgraph PrivateSubnets ["Private Subnets (EKS & Workloads)"]
                subgraph ControlPlane ["EKS Control Plane v1.30"]
                    APIServer["Kubernetes API Server (Native Access Entries)"]
                end

                subgraph SystemNodes ["Bootstrap Managed Node Group (AL2023)"]
                    ArgoCD["ArgoCD Server & Repo Controller"]
                    KarpenterCtrl["Karpenter Controller (IRSA)"]
                    IngressNGINX["Ingress NGINX Controller"]
                    MetricsServer["Metrics Server"]
                end

                subgraph DynamicNodes ["Karpenter Provisioned Nodes (AL2023 Spot/On-Demand)"]
                    Workloads["Containerized Business Workloads (e.g. Sample App)"]
                end
            end
        end
    end

    subgraph GitHub ["GitHub Version Control"]
        Repo["GitOps Repository (Terraform-lab.git)"]
    end

    Repo -->|"Declarative Sync (1-way drift correction)"| ArgoCD
    ArgoCD -->|"Reconciles CRDs & Apps"| APIServer
    KarpenterCtrl -->|"Direct EC2 Fleet API calls (< 45s provision)"| DynamicNodes
    NLB --> IngressNGINX
    IngressNGINX --> Workloads
```

---

## 🌟 Key Architectural Pillars

### 1. High-Performance Autoscaling & FinOps (Karpenter v1)
- **Sub-Minute Scaling:** Replaces legacy Kubernetes Cluster Autoscaler with Karpenter v1, provisioning right-sized EC2 instances directly via `ec2:CreateFleet` in under 45 seconds.
- **Aggressive Cost Optimization:** Dynamically leverages **Spot** and **On-Demand** compute across modern instance families (`c`, `m`, `r`) on **Amazon Linux 2023 (AL2023)**.
- **Automated Consolidation:** Configured with `WhenEmpty` consolidation policy (30s timeout) to automatically drain and terminate underutilized nodes without manual intervention.

### 2. Pure GitOps Workflow (ArgoCD & App-of-Apps)
- **Zero Configuration Drift:** In-cluster state continuously reconciles against the Git repository (`master` branch) with `selfHeal` and automated sync enabled.
- **GitOps-Managed Karpenter CRDs:** Karpenter `NodePool` and `EC2NodeClass` resources are treated as declarative platform manifests within `gitops/platform/karpenter/` and orchestrated via an ArgoCD Application.
- **Accidental Deletion Shield:** Critical cluster infrastructure manifests use `prune: false` within GitOps to prevent catastrophic node teardown from accidental Git commits.

### 3. Enterprise Security & Identity
- **Native EKS Access Entries (EKS 1.30):** Fully deprecates the legacy, race-condition-prone `aws-auth` ConfigMap. Authenticates both managed nodes and Karpenter dynamic instances using AWS-native `aws_eks_access_entry` resources (`type = "EC2_LINUX"`).
- **IAM Roles for Service Accounts (IRSA):** OIDC-federated role bindings ensure the Karpenter controller only possesses least-privilege IAM permissions without hardcoded secrets or static node-level rights.
- **Security Group Isolation:** Karpenter nodes inherit the EKS Primary Cluster Security Group, guaranteeing secure intra-cluster (kubelet port 10250) and control-plane communication without exposing ports to the public internet.

### 4. Deterministic Lifecycle & Clean Teardown
- **Zero-Orphan Terraform Teardown:** Solves standard Terraform DAG limitations through explicit dependency binding:
  - Reverse dependency chaining (`modules/vpc/outputs.tf`) prevents NAT Gateway and Route Table associations from destroying before in-cluster pods and controllers finish API-level deregistration.
  - Cascade finalizer management (`resources-finalizer.argocd.argoproj.io`) ensures all Kubernetes resources cleanly delete before Helm releases uninstall.
  - Embedded `terraform_data` pre-destroy provisioner coordinates Karpenter CR termination, instance profile cleanup, and finalizer release within a single `terraform destroy -auto-approve` execution.

---

## 📂 Repository Structure

```text
.
├── environments/
│   ├── dev/                        # Development Environment
│   │   ├── backend.tf              # S3 Remote Backend with S3 Native State Locking
│   │   ├── main.tf                 # Dev Root Composition (2 AZs, dev-k8s-cluster)
│   │   └── outputs.tf              # Cluster endpoint & identifiers
│   └── prod/                       # Production Environment
│       ├── backend.tf              # S3 Remote Backend with S3 Native State Locking
│       ├── main.tf                 # Prod Root Composition (3 AZs, prod-k8s-cluster)
│       └── outputs.tf              # Cluster endpoint & identifiers
│
├── modules/
│   ├── vpc/                        # Multi-AZ VPC module with public/private subnets
│   │   ├── main.tf                 # IGW, NAT Gateways, Route Tables, Karpenter discovery tags
│   │   ├── variables.tf
│   │   └── outputs.tf              # Protected subnet outputs with explicit destroy-order depends_on
│   │
│   ├── k8s-cluster/                # Core EKS & IAM Platform
│   │   ├── main.tf                 # EKS Control Plane (1.30), Access Entries, Managed Node Group
│   │   ├── iam.tf                  # OIDC Provider, IRSA roles, Karpenter Controller & Node policies
│   │   ├── variables.tf
│   │   └── outputs.tf              # IAM Role ARNs & Cluster Connection Details
│   │
│   └── k8s-addons/                 # Platform Add-ons & GitOps Bootstrapping
│       ├── main.tf                 # Helm releases (Metrics Server, Ingress NGINX, ArgoCD, Karpenter)
│       ├── argocd_apps.tf          # Root Application-of-Apps manifest
│       ├── karpenter_resources.tf  # Karpenter ArgoCD App + Graceful Destroy Provisioner
│       └── variables.tf
│
└── gitops/                         # Declarative GitOps Manifests (ArgoCD target)
    ├── apps/
    │   └── sample-app/             # Business workload (Deployment & Service)
    └── platform/
        └── karpenter/              # Karpenter custom resources (Kustomization)
            ├── ec2nodeclass.yaml   # AWS AL2023 AMI terms, Subnet & SG discovery tags
            ├── nodepool.yaml       # Spot/On-Demand instance categories & consolidation rules
            └── kustomization.yaml  # Kustomize manifest bundle
```

---

## ⚙️ Environment Specifications

| Component | Dev (`environments/dev`) | Prod (`environments/prod`) |
| :--- | :--- | :--- |
| **AWS Region** | `eu-central-1` (Frankfurt) | `eu-central-1` (Frankfurt) |
| **VPC CIDR** | `10.100.0.0/16` | `10.200.0.0/16` |
| **Availability Zones** | 2 AZs (`eu-central-1a`, `eu-central-1b`) | 3 AZs (`eu-central-1a`, `eu-central-1b`, `eu-central-1c`) |
| **EKS Version** | `1.30` | `1.30` |
| **Authentication Mode** | `API_AND_CONFIG_MAP` (Native Access Entries) | `API_AND_CONFIG_MAP` (Native Access Entries) |
| **Bootstrap Node Group**| 2x `t3.medium` (On-Demand, AL2023) | Multi-AZ Managed Nodes (AL2023) |
| **Dynamic Autoscaling** | Karpenter v1 (AL2023 Spot & On-Demand) | Karpenter v1 (AL2023 Spot & On-Demand) |
| **State Management** | S3 Remote State + S3 Native State Locking | S3 Remote State + S3 Native State Locking |

---

## 🚀 Deployment & Operations

### Prerequisites
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configured with administrative privileges
- [Terraform >= 1.5.0](https://www.terraform.io/downloads.html)
- [kubectl >= 1.30](https://kubernetes.io/docs/tasks/tools/)

### 1. Provision Infrastructure
```bash
# Navigate to desired environment
cd environments/dev

# Initialize providers and remote backend
terraform init

# Validate configuration
terraform validate

# Provision full platform (EKS, VPC, Karpenter, ArgoCD)
terraform apply -auto-approve
```

### 2. Configure Local Kubernetes Access
```bash
aws eks update-kubeconfig --region eu-central-1 --name dev-k8s-cluster

# Verify system components
kubectl get nodes -o wide
kubectl get applications -n argocd
kubectl get nodepool,ec2nodeclass
```

### 3. Verify Autoscaling in Action
Simulate workload demand to observe Karpenter spinning up a dynamic Spot instance in ~35 seconds:
```bash
# Deploy a test workload requiring 1 CPU
kubectl create deployment karpenter-test --image=registry.k8s.io/pause:3.2 --replicas=3
kubectl set resources deployment karpenter-test --requests=cpu=1,memory=512Mi

# Watch Karpenter create a NodeClaim and join an EC2 Spot node
kubectl get nodeclaims -w

# Delete workload and observe automated consolidation (scale-down after 30s)
kubectl delete deployment karpenter-test
kubectl get nodes -w
```

### 4. Clean Platform Teardown
A single automated command cleanly dismantles the entire infrastructure without orphaned AWS load balancers, dangling ENIs, or stuck finalizers:
```bash
terraform destroy -auto-approve
```

---

## 🛡️ Enterprise Engineering Best Practices Implemented

- ✅ **Immutable Infrastructure as Code:** Strict version constraints across Terraform core and providers (`aws = 6.64.0`, `helm = 2.12.1`, `kubernetes = 3.3.0`, `kubectl = 1.19.0`).
- ✅ **State Locking:** Utilizes S3 native state locking (`use_lockfile = true`) for concurrent execution safety without requiring additional DynamoDB overhead.
- ✅ **Self-Healing Platform:** ArgoCD continuously monitors for configuration drift and automatically reverts unauthorized manual cluster edits.
- ✅ **Graceful Node Decommissioning:** Karpenter node disruption leverages automated drain and cordoning protocols to guarantee zero workload interruption during node consolidation.

---

## 👤 Author
**Ferenc Zágon**  
DevOps / Cloud Platform Engineer  
GitHub: [@ferenc-zagon](https://github.com/ferenc-zagon)