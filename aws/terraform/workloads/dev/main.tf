# When enabled=false, this module is removed from state and AWS resources are
# destroyed (hard delete). Do not comment out resources to tear the demo down.
module "demo" {
  count  = var.enabled ? 1 : 0
  source = "./infra"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
}
