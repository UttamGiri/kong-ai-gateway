variable "enabled" {
  type        = bool
  description = "true = create/keep the demo stack. false = next apply hard-deletes every resource in this module (volumes included). Flip this switch; do not comment out code."
  default     = true
}

variable "aws_region" {
  type        = string
  description = "AWS region for the workload stack."
  default     = "us-east-2"
}

variable "aws_profile" {
  type        = string
  description = "Named AWS CLI profile for local apply only. Leave empty on HCP (OIDC)."
  default     = ""
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
  default     = "kong-ai-dev"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.20.0.0/16"
}

variable "node_instance_type" {
  type        = string
  description = "Worker size. Demo default t3.medium (4 GB)."
  default     = "t3.medium"
}

variable "node_desired_size" {
  type        = number
  description = "One node = one public IPv4. Two nodes = two IPv4 charges."
  default     = 1
}

variable "budget_limit_usd" {
  type        = number
  description = "Monthly AWS account spend that triggers the budget alert."
  default     = 20
}

variable "budget_alert_email" {
  type        = string
  description = "Email for $20/month budget notices. Confirm the AWS subscription mail once. Empty = budget in console only, no email."
  default     = ""
}

variable "kubectl_admin_principal_arns" {
  type        = list(string)
  description = "IAM user or role ARNs that may kubectl/Helm (EKS access entries). Set in HCP workspace variables."
  default     = ["arn:aws:iam::593024667763:user/uttam-kubectl-demo"]
}
