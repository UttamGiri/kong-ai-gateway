variable "cluster_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "node_instance_type" {
  type = string
}

variable "node_desired_size" {
  type = number
}

variable "kubectl_admin_principal_arns" {
  type        = list(string)
  description = "IAM user or role ARNs granted cluster admin via EKS access entries."
  default     = []
}
