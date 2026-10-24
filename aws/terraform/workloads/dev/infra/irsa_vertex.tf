# IRSA for Kong → GCP Vertex WIF. Not HCP OIDC (that is bootstrap/aws_oidc.tf).
# Role name must stay ${cluster_name}-vertex (kong-ai-dev-vertex) so GCP WIF matches.
# No Vertex/GCP permissions on this role. Confirm account ID + role ARN to GCP only.

locals {
  vertex_role_name = "${var.cluster_name}-vertex"
  vertex_sa_ns     = "kong-ai-gateway"
  vertex_sa_name   = "kong-ai-gateway"
  eks_oidc_issuer  = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

data "aws_iam_policy_document" "vertex_irsa_assume" {
  statement {
    sid     = "KongAiGatewayIRSA"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_issuer}:sub"
      values   = ["system:serviceaccount:${local.vertex_sa_ns}:${local.vertex_sa_name}"]
    }
  }
}

resource "aws_iam_role" "kong_ai_vertex" {
  name               = local.vertex_role_name
  assume_role_policy = data.aws_iam_policy_document.vertex_irsa_assume.json
}

data "aws_caller_identity" "current" {}
