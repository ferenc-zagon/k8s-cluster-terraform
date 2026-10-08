variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster control plane endpoint"
  type        = string
}

variable "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  type        = string
}

variable "gitops_repo_url" {
  type        = string
  description = "Git repository URL for ArgoCD App-of-Apps"
  default     = "https://github.com/your-org/terraform-aws-eks.git"
}

variable "gitops_repo_revision" {
  type        = string
  description = "Target branch/commit for ArgoCD"
  default     = "HEAD"
}

variable "karpenter_node_role_name" {
  type        = string
  description = "Karpenter node IAM role name"
}

variable "karpenter_controller_role_arn" {
  type        = string
  description = "IAM Role ARN for Karpenter Controller"
}