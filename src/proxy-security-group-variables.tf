# RDS Proxy - Security Group (cloudposse/security-group mixin)
# https://github.com/cloudposse/terraform-aws-security-group/blob/main/exports/security-group-variables.tf

variable "proxy_security_group_description" {
  type        = string
  default     = "Security group for RDS Proxy"
  description = "The description to assign to the security group created for the RDS Proxy."
}

variable "proxy_security_group_create_before_destroy" {
  type        = bool
  default     = true
  description = <<-EOT
    Set `true` to enable terraform `create_before_destroy` behavior on the proxy security group.
    Ensures the new security group is created before the old one is destroyed, preventing service interruption.
    EOT
}

variable "proxy_preserve_security_group_id" {
  type        = bool
  default     = false
  description = <<-EOT
    When `false` and `proxy_security_group_create_before_destroy` is `true`, changes to security group rules
    cause a new security group to be created with the new rules, and the existing security group is then
    replaced with the new one, eliminating any service interruption.
    When `true`, existing security group rules will be deleted before new ones are created, preserving the
    security group itself but resulting in a brief service interruption.
    EOT
}

variable "proxy_additional_security_group_rules" {
  type        = list(any)
  default     = []
  description = <<-EOT
    A list of Security Group rule objects to add to the proxy security group, in addition to the egress
    rule to the Aurora cluster that this module creates automatically.
    Keys and values are compatible with the `aws_security_group_rule` resource, except `security_group_id`
    which is ignored. An optional `key` attribute, if provided, must be unique and known at plan time.
    EOT
}
