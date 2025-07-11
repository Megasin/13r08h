variable "alb_ingress_group" {
  description = "(Optional) The group name for the ALB ingress. Defaults to ``."
  type        = string
  default     = "drones-ingress-group"
}

variable "cluster_version" {
  description = "(Optional) Desired Kubernetes master version. Defaults to `1.28`."
  type        = string
  default     = "1.28"
}

variable "api_server_endpoint" {
  description = "(Optional) used for external accounts"
  type        = string
  default     = "private"
}

variable "api_server_allow_cidr" {
  description = "(Optional) used for external accounts"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "developer_readonly_access" {
  description = "(Optional) Enable Developer role read-only access to EKS cluster. Defaults to `false`."
  type        = bool
  default     = false
}

variable "echo_server_replica_count" {
  description = "(Optional) Number of echo server pod replicas to keep. Defaults to `1`."
  type        = number
  default     = 1
}

variable "private_subnet_ids" {
  description = "(Required) A list of subnet IDs where the nodes/node groups will be provisioned. The EKS cluster control plane (ENIs) will also be provisioned in these subnets."
  type        = list(string)
}

variable "tags" {
  description = "(Optional) Additional tags to assign to resources. Defaults to `{}`."
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "(Required) VPC ID for load balancer Fargate setup."
  type        = string
}

variable "encryption_key" {
  description = "(Required) KMS encryption key"
  type        = string

}

variable "account_id" {
  description = "(Required) account id for environment"
  type        = string

}

variable "dev-role-arn" {
  description = "(optional) used in rbac for reader role mapping"
  type        = string

}
variable "name" {
  description = "(Required) name of eks cluster"
  type        = string

}

variable "short-name" {
  description = "(Required) short name of eks cluster alphanumeric"
  type        = string

}

variable "region" {
  description = "(Optional) region for cluster"
  default     = "eu-west-2"
  type        = string

}

variable "service" {
  type = string
}

variable "dynatrace_api_token" {
  type = string
}

variable "dynatrace_environment_id" {
  type = string
}