locals {
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  name_prefix        = "${var.project_name}-${var.environment}"

  azs = {
    for index, availability_zone in local.availability_zones :
    "az${index + 1}" => {
      index = index
      name  = availability_zone
    }
  }

  spokes = {
    for spoke_name, cidr_block in var.spoke_vpc_cidrs :
    spoke_name => {
      cidr_block = cidr_block
      display    = replace(spoke_name, "_", "-")
    }
  }

  spoke_subnets = merge([
    for spoke_name, spoke in local.spokes : {
      for az_key, az in local.azs :
      "${spoke_name}-${az_key}" => {
        az_key            = az_key
        availability_zone = az.name
        cidr_block        = cidrsubnet(spoke.cidr_block, 8, az.index + 10)
        spoke_name        = spoke_name
      }
    }
  ]...)

  firewall_routes_to_spokes = merge([
    for az_key, az in local.azs : {
      for spoke_name, spoke in local.spokes :
      "${az_key}-${spoke_name}" => {
        az_key     = az_key
        cidr_block = spoke.cidr_block
        spoke_name = spoke_name
      }
    }
  ]...)

  firewall_endpoints = {
    for sync_state in aws_networkfirewall_firewall.main.firewall_status[0].sync_states :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Purpose     = "AuthorizedSecurityTraining"
  }
}
