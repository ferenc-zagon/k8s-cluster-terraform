variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "cluster_version" {
  type    = string
  default = "1.30"
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}