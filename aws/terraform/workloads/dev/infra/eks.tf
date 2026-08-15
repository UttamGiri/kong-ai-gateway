resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.36"

  vpc_config {
    subnet_ids              = [aws_subnet.nodes.id, aws_subnet.control_plane.id]
    endpoint_public_access  = true
    endpoint_private_access = false
    public_access_cidrs     = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = []

  timeouts {
    create = "30m"
    delete = "30m"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

resource "aws_launch_template" "nodes" {
  name_prefix = "${var.cluster_name}-ng-"

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.cluster_name}-node"
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.cluster_name}-node"
    }
  }
}

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "demo"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = [aws_subnet.nodes.id]
  instance_types  = [var.node_instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"
  capacity_type   = "ON_DEMAND"

  launch_template {
    id      = aws_launch_template.nodes.id
    version = aws_launch_template.nodes.latest_version
  }

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = 1
    max_size     = max(var.node_desired_size, 1)
  }

  update_config {
    max_unavailable = 1
  }

  timeouts {
    create = "30m"
    delete = "30m"
    update = "30m"
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker,
    aws_iam_role_policy_attachment.nodes_cni,
    aws_iam_role_policy_attachment.nodes_ecr,
  ]
}

# Best-effort wipe of Kubernetes-created NLBs/ALBs so VPC delete is not blocked.
# Helm/Istio load balancers are not in Terraform state.
resource "null_resource" "purge_k8s_elbs_on_destroy" {
  triggers = {
    cluster = aws_eks_cluster.this.name
    region  = data.aws_region.current.name
  }

  depends_on = [aws_eks_node_group.this]

  provisioner "local-exec" {
    when        = destroy
    on_failure  = continue
    interpreter = ["/bin/bash", "-c"]
    environment = {
      CLUSTER = self.triggers.cluster
      AWS_DEFAULT_REGION = self.triggers.region
    }
    command = <<-EOT
      set +e
      TAG="kubernetes.io/cluster/$${CLUSTER}"
      lbs=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[].LoadBalancerArn' --output text 2>/dev/null)
      for arn in $lbs; do
        tagged=$(aws elbv2 describe-tags --resource-arns "$arn" --query "TagDescriptions[0].Tags[?Key=='$${TAG}'].Value" --output text 2>/dev/null)
        if [ -n "$tagged" ]; then
          aws elbv2 delete-load-balancer --load-balancer-arn "$arn" || true
        fi
      done
      classic=$(aws elb describe-load-balancers --query 'LoadBalancerDescriptions[].LoadBalancerName' --output text 2>/dev/null)
      for name in $classic; do
        tagged=$(aws elb describe-tags --load-balancer-names "$name" --query "TagDescriptions[0].Tags[?Key=='$${TAG}'].Value" --output text 2>/dev/null)
        if [ -n "$tagged" ]; then
          aws elb delete-load-balancer --load-balancer-name "$name" || true
        fi
      done
      exit 0
    EOT
  }
}
