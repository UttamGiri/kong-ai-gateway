locals {
  budget_emails = var.budget_alert_email != "" ? [var.budget_alert_email] : []
  budget_notifications = var.budget_alert_email == "" ? [] : [
    { threshold = 50, type = "ACTUAL" },
    { threshold = 80, type = "ACTUAL" },
    { threshold = 100, type = "ACTUAL" },
    { threshold = 100, type = "FORECASTED" },
  ]
}

# Account-wide $20/month tripwire. Not inside module.demo, so enabled=false
# does not remove the alert.
resource "aws_budgets_budget" "monthly" {
  name         = "${var.cluster_name}-usd-${var.budget_limit_usd}"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.budget_notifications
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = local.budget_emails
    }
  }
}
