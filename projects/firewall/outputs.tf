output "deployment_id" {
  description = "State-pinned deployment ID used to prevent global IAM name collisions"
  value       = local.deployment_id
}

output "firewall_arn" {
  description = "ARN of the centralized AWS Network Firewall"
  value       = aws_networkfirewall_firewall.main.arn
}

output "firewall_endpoints" {
  description = "Network Firewall endpoint IDs keyed by availability zone"
  value       = local.firewall_endpoints
}

output "inspection_vpc_id" {
  description = "ID of the centralized inspection VPC"
  value       = aws_vpc.inspection.id
}

output "session_manager_commands" {
  description = "Commands for opening SSM sessions on the two spoke test instances"
  value = {
    for spoke_name, instance in aws_instance.spoke_test :
    spoke_name => "aws ssm start-session --profile ${var.aws_profile} --region ${var.aws_region} --target ${instance.id}"
  }
}

output "spoke_instance_private_ips" {
  description = "Private IP addresses of the spoke test instances"
  value = {
    for spoke_name, instance in aws_instance.spoke_test :
    spoke_name => instance.private_ip
  }
}

output "spoke_vpc_ids" {
  description = "IDs of the two spoke VPCs"
  value = {
    for spoke_name, vpc in aws_vpc.spoke :
    spoke_name => vpc.id
  }
}

output "transit_gateway_id" {
  description = "ID of the Transit Gateway used for centralized inspection"
  value       = aws_ec2_transit_gateway.main.id
}
