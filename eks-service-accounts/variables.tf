data "aws_iam_policy" "permissions_boundary" {
  name = "DcpPermissionsBoundary"
}

variable "app" {
  description = "(Required) Name of the resource target application."
  type        = string
}

variable "cluster_name" {
  description = "(Required) The EKS cluster name."
  type        = string
}

variable "environment" {
  description = "(Required) Environment name: dev, test, uat, prod or sandbox."
  type        = string
  validation {
    condition     = contains(["dev", "test", "uat", "prod", "development"], var.environment)
    error_message = "Value must be one of the following: dev, test, stage, prod or sandbox."
  }
}

variable "namespace" {
  description = "(Optional) Kubernetes namespace to create the service account. Defaults to `default`."
  type        = string
  default     = "default"
}

variable "oidc_provider" {
  description = "(Required) IAM OpenID Connect provider properties."
  type = object({
    arn = string
    url = string
  })
}

variable "policy_arns" {
  description = "(Required) ARNs of any policies to attach to the IAM role."
  type        = map(string)
}

variable "tags" {
  description = "(Optional) Additional tags to assign to resources. Defaults to `{}`."
  type        = map(string)
  default     = {}
}
