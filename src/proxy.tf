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
resource "aws_security_group" "proxy" {
  count = local.proxy_enabled ? 1 : 0

  name        = "${module.cluster.id}-proxy"
  description = "Security group for RDS Proxy"
  vpc_id      = local.vpc_id

  tags = module.cluster.tags
}

# Egress rule: Allow proxy to connect to Aurora cluster on database port
resource "aws_security_group_rule" "proxy_egress_to_cluster" {
  count = local.proxy_enabled ? 1 : 0

  type                     = "egress"
  from_port                = var.mysql_db_port
  to_port                  = var.mysql_db_port
  protocol                 = "tcp"
  source_security_group_id = module.aurora_mysql.security_group_id
  security_group_id        = aws_security_group.proxy[0].id
  description              = "Allow proxy to connect to Aurora cluster"
}

# Ingress rule on Aurora cluster: Allow connections from proxy security group
resource "aws_security_group_rule" "cluster_ingress_from_proxy" {
  count = local.proxy_enabled ? 1 : 0

  type                     = "ingress"
  from_port                = var.mysql_db_port
  to_port                  = var.mysql_db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.proxy[0].id
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
  vpc_security_group_ids       = [aws_security_group.proxy[0].id]
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

check "proxy_engine_supported" {
  assert {
    condition     = !var.proxy_enabled || contains(["aurora", "aurora-mysql"], var.aurora_mysql_engine)
    error_message = "RDS Proxy only supports the MYSQL engine family. The engine '${var.aurora_mysql_engine}' is not supported."
  }
}

check "proxy_auth_required" {
  assert {
    condition     = !var.proxy_enabled || var.proxy_auth != null || var.proxy_secret_arn != null
    error_message = "When proxy_enabled is true, either proxy_auth or proxy_secret_arn must be provided."
  }
}

check "proxy_read_replica_unsupported" {
  assert {
    condition     = !var.proxy_enabled || !var.is_read_replica
    error_message = "RDS Proxy cannot be enabled on a read replica cluster. Set proxy_enabled = false when is_read_replica = true."
  }
}
