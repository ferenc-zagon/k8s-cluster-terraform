variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

variable "state_bucket_name" {
  type    = string
  default = "platform-terraform-state-lock"
}

variable "lock_table_name" {
  type    = string
  default = "terraform-state-locks"
}