variable "aws_region" {
  type        = string
  description = "Target AWS region for infrastructure deployment."
  default     = "eu-central-1"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, prod)."
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC."
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets across availability zones."
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets across availability zones."
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster name for Karpenter and Kubernetes discovery tags"
  default     = ""
}