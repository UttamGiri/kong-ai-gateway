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
