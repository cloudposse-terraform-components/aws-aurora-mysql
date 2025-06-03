resource "aws_secretsmanager_secret" "default" {
  count = local.asm_enabled ? 1 : 0

  name        = local.mysql_admin_password_key
  description = format("%s admin creds", module.cluster.id)

  # policy                  = "{}"
  # kms_key_id              = null # "aws/secretsmanager"
  # recovery_window_in_days = null # 30

  tags = module.this.tags
}

resource "aws_secretsmanager_secret_version" "default" {
  count = local.asm_enabled ? 1 : 0

  secret_id = one(aws_secretsmanager_secret.default[*].id)
  secret_string = jsonencode({
    cluster_domain = local.cluster_domain
    db_host        = module.aurora_mysql.master_host
    db_port        = local.db_port
    cluster_name   = module.aurora_mysql.cluster_identifier
    username       = local.mysql_admin_user
    password       = local.mysql_admin_password
  })
}
