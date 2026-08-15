output "enabled" {
  value = var.enabled
}

output "vpc_id" {
  value = try(module.demo[0].vpc_id, null)
}

output "cluster_name" {
  value = try(module.demo[0].cluster_name, null)
}

output "cluster_endpoint" {
  value     = try(module.demo[0].cluster_endpoint, null)
  sensitive = true
}

output "budget_name" {
  value = aws_budgets_budget.monthly.name
}

output "budget_limit_usd" {
  value = var.budget_limit_usd
}
