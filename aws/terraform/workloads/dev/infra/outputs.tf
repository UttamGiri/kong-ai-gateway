output "vpc_id" {
  value = aws_vpc.this.id
}

output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "node_subnet_id" {
  value = aws_subnet.nodes.id
}

output "vertex_irsa" {
  description = "Confirm account ID + role ARN to GCP. Do not send OIDC issuer, JWKS, or keys."
  value = {
    aws_account_id = data.aws_caller_identity.current.account_id
    role_name      = aws_iam_role.kong_ai_vertex.name
    role_arn       = aws_iam_role.kong_ai_vertex.arn
  }
}
