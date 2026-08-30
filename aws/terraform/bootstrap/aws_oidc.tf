data "tls_certificate" "tfc" {
  url = "https://${var.tfc_hostname}"
}

locals {
  tfc_run_workspace_names = [
    var.tfc_bootstrap_workspace_name,
    var.tfc_workspace_name,
  ]
}

resource "aws_iam_openid_connect_provider" "tfc" {
  url             = "https://${var.tfc_hostname}"
  client_id_list  = [var.tfc_aws_audience]
  thumbprint_list = [data.tls_certificate.tfc.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "tfc_run" {
  name = var.tfc_run_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      for workspace_name in local.tfc_run_workspace_names : {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.tfc.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${var.tfc_hostname}:aud" = var.tfc_aws_audience
          }
          StringLike = {
            "${var.tfc_hostname}:sub" = "organization:${var.tfc_organization_name}:project:${var.tfc_project_name}:workspace:${workspace_name}:run_phase:*"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tfc_run" {
  for_each = toset(var.tfc_run_role_policy_arns)

  role       = aws_iam_role.tfc_run.name
  policy_arn = each.value
}
