resource "aws_cloudwatch_log_group" "firewall_alert" {
  name              = "/aws/network-firewall/${local.name_prefix}/alert"
  retention_in_days = var.retention_days
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  name              = "/aws/network-firewall/${local.name_prefix}/flow"
  retention_in_days = var.retention_days
}

resource "aws_networkfirewall_rule_group" "blocked_domains" {
  capacity = 100
  name     = "${local.name_prefix}-blocked-domains"
  type     = "STATEFUL"

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"

        ip_set {
          definition = toset(concat(
            [var.inspection_vpc_cidr],
            values(var.spoke_vpc_cidrs),
          ))
        }
      }
    }

    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }
  }

  tags = {
    Name = "${local.name_prefix}-blocked-domains"
  }
}

resource "aws_networkfirewall_firewall_policy" "main" {
  name = "${local.name_prefix}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_rule_group_reference {
      resource_arn = aws_networkfirewall_rule_group.blocked_domains.arn
    }
  }

  tags = {
    Name = "${local.name_prefix}-policy"
  }
}

resource "aws_networkfirewall_firewall" "main" {
  delete_protection                 = false
  firewall_policy_arn               = aws_networkfirewall_firewall_policy.main.arn
  firewall_policy_change_protection = false
  name                              = "${local.name_prefix}-firewall"
  subnet_change_protection          = false
  vpc_id                            = aws_vpc.inspection.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.inspection_firewall

    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = {
    Name = "${local.name_prefix}-firewall"
  }
}

resource "aws_networkfirewall_logging_configuration" "main" {
  firewall_arn = aws_networkfirewall_firewall.main.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alert.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flow.name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}
