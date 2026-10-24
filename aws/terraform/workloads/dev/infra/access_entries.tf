# EKS access entries — who may call the Kubernetes API. Not Helm (AWS objects).
# After apply: aws eks update-kubeconfig locally, then helm upgrade platform-namespaces.

locals {
  cluster_admin_policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
}

resource "aws_eks_access_entry" "kubectl_admin" {
  for_each = toset(var.kubectl_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.this]
}

resource "aws_eks_access_policy_association" "kubectl_admin" {
  for_each = toset(var.kubectl_admin_principal_arns)

  cluster_name  = aws_eks_cluster.this.name
  principal_arn = each.value
  policy_arn    = local.cluster_admin_policy_arn

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.kubectl_admin]
}
