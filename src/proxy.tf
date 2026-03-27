locals {
  proxy_enabled = local.enabled && var.proxy_enabled && !local.is_read_replica

  # Aurora MySQL always uses the MYSQL engine family for RDS Proxy
  proxy_engine_family = "MYSQL"

  # Build auth configuration
  proxy_auth = var.proxy_auth != null ? var.proxy_auth : (
    var.proxy_secret_arn != null ? [
      {
        auth_scheme               = "SECRETS"
        client_password_auth_type = var.proxy_client_password_auth_type
        description               = "Authenticate using Secrets Manager"
        iam_auth                  = var.proxy_iam_auth
        secret_arn                = var.proxy_secret_arn
        username                  = null
      }
    ] : []
  )

  # Proxy DNS name - follows the same pattern as cluster DNS names in aurora-mysql
  proxy_dns_name = format("%s.%s", var.proxy_dns_name_part, local.cluster_subdomain)
}

# Dedicated security group for RDS Proxy
# Uses cloudposse/security-group to enable create_before_destroy lifecycle safety
module "proxy_security_group" {
  source  = "cloudposse/security-group/aws"
  version = "2.2.0"

  count = local.proxy_enabled ? 1 : 0

  vpc_id                     = local.vpc_id
  security_group_description = var.proxy_security_group_description
  create_before_destroy      = var.proxy_security_group_create_before_destroy
  preserve_security_group_id = var.proxy_preserve_security_group_id

  # Only allow explicit egress to the Aurora cluster; no unrestricted egress
  allow_all_egress = false

  rules = concat(
    [
      {
        key                      = "egress_to_cluster"
        type                     = "egress"
        from_port                = var.mysql_db_port
        to_port                  = var.mysql_db_port
        protocol                 = "tcp"
        source_security_group_id = module.aurora_mysql.security_group_id
        description              = "Allow proxy to connect to Aurora cluster"
      }
    ],
    var.proxy_additional_security_group_rules
  )

  attributes = ["proxy"]
  context    = module.cluster.context
}

# Ingress rule on Aurora cluster: Allow connections from proxy security group
resource "aws_security_group_rule" "cluster_ingress_from_proxy" {
  count = local.proxy_enabled ? 1 : 0

  type                     = "ingress"
  from_port                = var.mysql_db_port
  to_port                  = var.mysql_db_port
  protocol                 = "tcp"
  source_security_group_id = module.proxy_security_group[0].id
  security_group_id        = module.aurora_mysql.security_group_id
  description              = "Allow connections from RDS Proxy"
}

module "rds_proxy" {
  source  = "cloudposse/rds-db-proxy/aws"
  version = "1.1.1"

  count = local.proxy_enabled ? 1 : 0

  db_cluster_identifier = module.aurora_mysql.cluster_identifier

  auth          = local.proxy_auth
  engine_family = local.proxy_engine_family
  # RDS Proxy must always be in private subnets for security
  vpc_subnet_ids               = local.private_subnet_ids
  vpc_security_group_ids       = [module.proxy_security_group[0].id]
  debug_logging                = var.proxy_debug_logging
  idle_client_timeout          = var.proxy_idle_client_timeout
  require_tls                  = var.proxy_require_tls
  connection_borrow_timeout    = var.proxy_connection_borrow_timeout
  init_query                   = var.proxy_init_query
  max_connections_percent      = var.proxy_max_connections_percent
  max_idle_connections_percent = var.proxy_max_idle_connections_percent
  session_pinning_filters      = var.proxy_session_pinning_filters
  iam_role_attributes          = var.proxy_iam_role_attributes
  existing_iam_role_arn        = var.proxy_existing_iam_role_arn
  kms_key_id                   = var.mysql_storage_encrypted ? module.kms_key_rds.key_arn : null
  proxy_create_timeout         = var.proxy_create_timeout
  proxy_update_timeout         = var.proxy_update_timeout
  proxy_delete_timeout         = var.proxy_delete_timeout

  context = module.cluster.context
}

resource "aws_route53_record" "proxy" {
  count = local.proxy_enabled && var.proxy_dns_enabled ? 1 : 0

  zone_id = local.zone_id
  name    = local.proxy_dns_name
  type    = "CNAME"
  ttl     = 60
  records = [module.rds_proxy[0].proxy_endpoint]
}
