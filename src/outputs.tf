output "aurora_mysql_cluster_arn" {
  value       = module.aurora_mysql.arn
  description = "The ARN of Aurora cluster"
}

output "aurora_mysql_cluster_id" {
  value       = module.cluster.id
  description = "The ID of Aurora cluster"
}

output "aurora_mysql_cluster_name" {
  value       = local.enabled ? module.aurora_mysql.cluster_identifier : null
  description = "Aurora MySQL cluster identifier"
}

output "aurora_mysql_endpoint" {
  value       = local.enabled ? module.aurora_mysql.endpoint : null
  description = "Aurora MySQL endpoint"
}

output "aurora_mysql_master_hostname" {
  value       = local.enabled ? module.aurora_mysql.master_host : null
  description = "Aurora MySQL DB master hostname"
}

output "aurora_mysql_master_password" {
  value       = local.mysql_db_enabled ? "Password for admin user ${module.aurora_mysql.master_username} is stored in ${var.secrets_store_type} at ${local.mysql_admin_password_key}" : null
  description = "Location of admin password"
  sensitive   = true
}

output "aurora_mysql_master_password_ssm_key" {
  value       = local.ssm_enabled && local.mysql_db_enabled ? local.mysql_admin_password_key : null
  description = "SSM key for admin password"
}

output "aurora_mysql_master_password_asm_key" {
  value       = local.asm_enabled && local.mysql_db_enabled ? local.mysql_admin_password_key : null
  description = "ASM key for admin password"
}

output "aurora_mysql_master_username" {
  value       = local.enabled ? module.aurora_mysql.master_username : null
  description = "Aurora MySQL username for the master DB user"
  sensitive   = true
}

output "aurora_mysql_reader_endpoint" {
  value       = local.enabled ? module.aurora_mysql.reader_endpoint : null
  description = "Aurora MySQL reader endpoint"
}

output "aurora_mysql_replicas_hostname" {
  value       = local.enabled ? module.aurora_mysql.replicas_host : null
  description = "Aurora MySQL replicas hostname"
}

output "cluster_domain" {
  value       = local.cluster_domain
  description = "Cluster DNS name"
}

output "kms_key_arn" {
  value       = module.kms_key_rds.key_arn
  description = "KMS key ARN for Aurora MySQL"
}

output "ssm_key_paths" {
  value       = module.parameter_store_write.names
  description = "Names (key paths) of all SSM parameters stored for this cluster"
}

output "config_map" {
  value = local.enabled ? {
    cluster          = module.aurora_mysql.cluster_identifier
    database         = local.mysql_db_name
    hostname         = module.aurora_mysql.master_host
    port             = var.mysql_db_port
    endpoint         = module.aurora_mysql.endpoint
    username         = module.aurora_mysql.master_username
    password_ssm_key = local.ssm_enabled && local.mysql_db_enabled ? local.mysql_admin_password_key : null
  } : null
  description = "Map containing information pertinent to a MySQL client configuration."
  sensitive   = true
}

output "security_group_id" {
  value       = module.aurora_mysql.security_group_id
  description = "The security group ID of the Aurora MySQL cluster"
}

# RDS Proxy Outputs
output "proxy_id" {
  value       = one(module.rds_proxy[*].proxy_id)
  description = "The ID of the RDS Proxy"
}

output "proxy_arn" {
  value       = one(module.rds_proxy[*].proxy_arn)
  description = "The ARN of the RDS Proxy"
}

output "proxy_endpoint" {
  value       = one(module.rds_proxy[*].proxy_endpoint)
  description = "The endpoint of the RDS Proxy"
}

output "proxy_dns_name" {
  value       = one(aws_route53_record.proxy[*].fqdn)
  description = "The DNS name of the RDS Proxy (Route53 record)"
}

output "proxy_target_endpoint" {
  value       = one(module.rds_proxy[*].proxy_target_endpoint)
  description = "Hostname for the target RDS DB Instance"
}

output "proxy_target_id" {
  value       = one(module.rds_proxy[*].proxy_target_id)
  description = "Identifier of db_proxy_name, target_group_name, target type, and resource identifier separated by forward slashes"
}

output "proxy_target_port" {
  value       = one(module.rds_proxy[*].proxy_target_port)
  description = "Port for the target Aurora DB cluster"
}

output "proxy_target_rds_resource_id" {
  value       = one(module.rds_proxy[*].proxy_target_rds_resource_id)
  description = "Identifier representing the DB cluster target"
}

output "proxy_target_type" {
  value       = one(module.rds_proxy[*].proxy_target_type)
  description = "Type of target (e.g. RDS_INSTANCE or TRACKED_CLUSTER)"
}

output "proxy_default_target_group_arn" {
  value       = one(module.rds_proxy[*].proxy_default_target_group_arn)
  description = "The Amazon Resource Name (ARN) representing the default target group"
}

output "proxy_default_target_group_name" {
  value       = one(module.rds_proxy[*].proxy_default_target_group_name)
  description = "The name of the default target group"
}

output "proxy_iam_role_arn" {
  value       = one(module.rds_proxy[*].proxy_iam_role_arn)
  description = "The ARN of the IAM role that the proxy uses to access secrets in AWS Secrets Manager"
}

output "proxy_security_group_id" {
  value       = one(aws_security_group.proxy[*].id)
  description = "The security group ID of the RDS Proxy"
}
