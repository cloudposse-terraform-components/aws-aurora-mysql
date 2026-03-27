variable "region" {
  type        = string
  description = "AWS Region"
}

variable "ssm_path_prefix" {
  type        = string
  default     = "rds"
  description = "SSM path prefix"
}

variable "ssm_password_source" {
  type        = string
  default     = ""
  description = <<-EOT
    If `var.ssm_passwords_enabled` is `true`, DB user passwords will be retrieved from SSM using
    `var.ssm_password_source` and the database username. If this value is not set,
    a default path will be created using the SSM path prefix and ID of the associated Aurora Cluster.
    EOT
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = []
  description = "List of CIDR blocks to be allowed to connect to the RDS cluster"
}

variable "mysql_name" {
  type        = string
  description = "MySQL solution name (part of cluster identifier)"
  default     = ""
}

variable "mysql_db_name" {
  type        = string
  description = "Database name (default is not to create a database)"
  default     = ""
}

variable "mysql_db_port" {
  type        = number
  description = "Database port"
  default     = 3306

  validation {
    condition     = var.mysql_db_port >= 1 && var.mysql_db_port <= 65535
    error_message = "mysql_db_port must be between 1 and 65535."
  }
}

variable "mysql_admin_user" {
  type        = string
  description = "MySQL admin user name"
  default     = ""
}

variable "mysql_admin_password" {
  type        = string
  description = "MySQL password for the admin user"
  default     = ""
}

# https://aws.amazon.com/rds/RDS/pricing
variable "mysql_instance_type" {
  type        = string
  default     = "db.t3.medium"
  description = "EC2 instance type for RDS MySQL cluster"
}

variable "aurora_mysql_engine" {
  type        = string
  description = "Engine for Aurora database: `aurora` for MySQL 5.6, `aurora-mysql` for MySQL 5.7"
}

variable "aurora_mysql_engine_version" {
  type        = string
  description = "Engine Version for Aurora database."
  default     = ""
}

variable "aurora_mysql_cluster_family" {
  type        = string
  description = "DBParameterGroupFamily (e.g. `aurora5.6`, `aurora-mysql5.7` for Aurora MySQL databases). See https://stackoverflow.com/a/55819394 for help finding the right one to use."
}

variable "aurora_mysql_cluster_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB cluster parameters to apply"
}

variable "aurora_mysql_instance_parameters" {
  type = list(object({
    apply_method = string
    name         = string
    value        = string
  }))
  default     = []
  description = "List of DB instance parameters to apply"
}

variable "mysql_cluster_size" {
  type        = string
  default     = 2
  description = "MySQL cluster size"
}

variable "mysql_storage_encrypted" {
  type        = string
  default     = true
  description = "Set to `true` to keep the database contents encrypted"
}

variable "mysql_deletion_protection" {
  type        = string
  default     = true
  description = "Set to `true` to protect the database from deletion"
}

variable "mysql_skip_final_snapshot" {
  type        = string
  default     = false
  description = "Determines whether a final DB snapshot is created before the DB cluster is deleted"
}

variable "mysql_enabled_cloudwatch_logs_exports" {
  type        = list(string)
  description = "List of log types to export to cloudwatch. The following log types are supported: audit, error, general, slowquery"
  default     = ["audit", "error", "general", "slowquery"]
}

variable "performance_insights_enabled" {
  type        = bool
  description = "Set `true` to enable Performance Insights"
  default     = false
}

variable "mysql_backup_retention_period" {
  type        = number
  default     = 3
  description = "Number of days for which to retain backups"
}

variable "mysql_backup_window" {
  type        = string
  default     = "07:00-09:00"
  description = "Daily time range during which the backups happen"
}

variable "mysql_maintenance_window" {
  type        = string
  default     = "sat:10:00-sat:10:30"
  description = "Weekly time range during which system maintenance can occur, in UTC"
}

variable "auto_minor_version_upgrade" {
  type        = bool
  default     = false
  description = "Automatically update the cluster when a new minor version is released"
}

variable "publicly_accessible" {
  type        = bool
  default     = false
  description = "Set to true to create the cluster in a public subnet"
}

variable "eks_component_names" {
  type        = set(string)
  description = "The names of the eks components"
  default     = ["eks/cluster"]
}

variable "replication_source_identifier" {
  type        = string
  description = <<-EOT
    ARN of a source DB cluster or DB instance if this DB cluster is to be created as a Read Replica.
    If this value is empty and replication is enabled, remote state will attempt to find
    a matching cluster in the Primary DB Cluster's region
    EOT
  default     = ""
}

variable "is_read_replica" {
  type        = bool
  description = "If `true`, create this DB cluster as a Read Replica."
  default     = false
}

variable "is_promoted_read_replica" {
  type        = bool
  description = "If `true`, do not assign a Replication Source to the Cluster. Set to `true` after manually promoting the cluster from a replica to a standalone cluster."
  default     = false
}

variable "primary_cluster_region" {
  type        = string
  description = "If this cluster is a read replica and no replication source is explicitly given, the region to look for a matching cluster"
  default     = ""
}

variable "primary_cluster_component" {
  type        = string
  description = "If this cluster is a read replica and no replication source is explicitly given, the component name for the primary cluster"
  default     = "aurora-mysql"
}

variable "allow_ingress_from_vpc_accounts" {
  type = list(object({
    vpc         = optional(string, "vpc")
    environment = optional(string)
    stage       = optional(string)
    tenant      = optional(string)
  }))
  default     = []
  description = <<-EOF
    List of account contexts to pull VPC ingress CIDR and add to cluster security group.

    e.g.
    {
      environment = "ue2",
      stage       = "auto",
      tenant      = "core"
    }

    Defaults to the "vpc" component in the given account
  EOF
}

variable "vpc_component_name" {
  type        = string
  default     = "vpc"
  description = "The name of the VPC component"
}

variable "secrets_store_type" {
  type        = string
  description = "Secret Store type to save database credentials. Valid values: `SSM`, `ASM`"
  default     = "SSM"

  validation {
    condition     = contains(["SSM", "ASM"], var.secrets_store_type)
    error_message = "secrets_store_type must be one of: SSM, ASM."
  }
}

variable "iam_database_authentication_enabled" {
  description = "Enable IAM database authentication"
  type        = bool
  default     = false
}

# RDS Proxy Configuration
variable "proxy_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable RDS Proxy for the Aurora cluster"
}

variable "proxy_debug_logging" {
  type        = bool
  default     = false
  description = "Whether the proxy includes detailed information about SQL statements in its logs"
}

variable "proxy_idle_client_timeout" {
  type        = number
  default     = 1800
  description = "The number of seconds that a connection to the proxy can be inactive before the proxy disconnects it"
}

variable "proxy_require_tls" {
  type        = bool
  default     = true
  description = "A Boolean parameter that specifies whether Transport Layer Security (TLS) encryption is required for connections to the proxy"
}

variable "proxy_connection_borrow_timeout" {
  type        = number
  default     = 120
  description = "The number of seconds for a proxy to wait for a connection to become available in the connection pool"
}

variable "proxy_init_query" {
  type        = string
  default     = null
  description = "One or more SQL statements for the proxy to run when opening each new database connection"
}

variable "proxy_max_connections_percent" {
  type        = number
  default     = 100
  description = "The maximum size of the connection pool for each target in a target group. Must be between 1 and 100."

  validation {
    condition     = var.proxy_max_connections_percent >= 1 && var.proxy_max_connections_percent <= 100
    error_message = "proxy_max_connections_percent must be between 1 and 100 (inclusive)."
  }
}

variable "proxy_max_idle_connections_percent" {
  type        = number
  default     = 50
  description = "Controls how actively the proxy closes idle database connections in the connection pool. Must be between 0 and 100."

  validation {
    condition     = var.proxy_max_idle_connections_percent >= 0 && var.proxy_max_idle_connections_percent <= 100
    error_message = "proxy_max_idle_connections_percent must be between 0 and 100 (inclusive)."
  }
}

variable "proxy_session_pinning_filters" {
  type        = list(string)
  default     = null
  description = "Each item in the list represents a class of SQL operations that normally cause all later statements in a session using a proxy to be pinned to the same underlying database connection"
}

variable "proxy_iam_role_attributes" {
  type        = list(string)
  default     = null
  description = "Additional attributes to add to the ID of the IAM role that the proxy uses to access secrets in AWS Secrets Manager"
}

variable "proxy_existing_iam_role_arn" {
  type        = string
  default     = null
  description = "The ARN of an existing IAM role that the proxy can use to access secrets in AWS Secrets Manager. If not provided, the module will create a role to access secrets in Secrets Manager"
}

variable "proxy_secret_arn" {
  type        = string
  default     = null
  description = "The ARN of the secret in AWS Secrets Manager that contains the database credentials. Required if proxy_auth is not provided"
}

variable "proxy_auth" {
  type = list(object({
    auth_scheme               = optional(string, "SECRETS")
    client_password_auth_type = optional(string)
    description               = optional(string)
    iam_auth                  = optional(string, "DISABLED")
    secret_arn                = optional(string)
    username                  = optional(string)
  }))
  default     = null
  description = <<-EOT
    Configuration blocks with authorization mechanisms to connect to the associated database instances or clusters.
    Each block supports:
    - auth_scheme: The type of authentication that the proxy uses for connections. Valid values: SECRETS
    - client_password_auth_type: The type of authentication the proxy uses for connections from clients. Valid values: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION
    - description: A user-specified description about the authentication used by a proxy
    - iam_auth: Whether to require or disallow AWS IAM authentication. Valid values: DISABLED, REQUIRED, OPTIONAL
    - secret_arn: The ARN of the Secrets Manager secret containing the database credentials
    - username: The name of the database user to which the proxy connects
  EOT
}

variable "proxy_iam_auth" {
  type        = string
  default     = "DISABLED"
  description = "Whether to require or disallow AWS IAM authentication for connections to the proxy. Valid values: DISABLED, REQUIRED, OPTIONAL"

  validation {
    condition     = contains(["DISABLED", "REQUIRED", "OPTIONAL"], var.proxy_iam_auth)
    error_message = "Valid values for proxy_iam_auth are: DISABLED, REQUIRED, OPTIONAL."
  }
}

variable "proxy_client_password_auth_type" {
  type        = string
  default     = null
  description = "The type of authentication the proxy uses for connections from clients. Valid values: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION"

  validation {
    condition     = var.proxy_client_password_auth_type == null || contains(["MYSQL_NATIVE_PASSWORD", "POSTGRES_SCRAM_SHA_256", "POSTGRES_MD5", "SQL_SERVER_AUTHENTICATION"], var.proxy_client_password_auth_type)
    error_message = "Valid values for proxy_client_password_auth_type are: MYSQL_NATIVE_PASSWORD, POSTGRES_SCRAM_SHA_256, POSTGRES_MD5, SQL_SERVER_AUTHENTICATION."
  }
}

variable "proxy_dns_enabled" {
  type        = bool
  default     = true
  description = "Whether to create a Route53 DNS record for the proxy endpoint"
}

variable "proxy_dns_name_part" {
  type        = string
  default     = "proxy"
  description = "Part of DNS name added to module and cluster name for DNS for the proxy endpoint"
}
